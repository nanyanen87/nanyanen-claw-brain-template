#!/usr/bin/env bash
# ============================================================================
# check.sh — memory-maintenance の機械チェック（LLM 不要 / 読み取り専用）
# ----------------------------------------------------------------------------
# WHAT:  OpenClaw の検索索引と脳ファイル (MEMORY.md /
#        memory/**) の健全性を機械的に検査し、構造化テキストで出力する。検査:
#          (a) 索引カバレッジ（disk にあるが索引ソースに無い / 内容更新済み）
#          (b) 死にポインタ（MEMORY.md + memory/*.md の参照先の実在）
#          (c) コンテキスト圧の観測（サイズ。自動整理の指示ではない）
#          (d) git 状態（未コミット差分、最終コミットからの経過日数）
# WHY:   retrieval と current-state view の故障を、データを変更せず観測する。
#        整理が必要か・どう直すかは現在の文脈から agent が判断する
#        （SKILL.md の手順に従う）。
# HOW:   cron の memory-maintenance ジョブが SKILL.md 経由で実行する。
#        手動実行も可: bash skills/memory-maintenance/check.sh
# SAFETY: 検知して報告するのみ。書き込み・削除・reindex は一切しない。
#         sqlite は read-only (mode=ro) 接続。
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="${OPENCLAW_WORKSPACE_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
STATE_DIR="${OPENCLAW_STATE_DIR:-$HOME/.openclaw}"
AGENT_ID="${OPENCLAW_AGENT_ID:-main}"
NEW_DB="$STATE_DIR/agents/$AGENT_ID/agent/openclaw-agent.sqlite"
LEGACY_DB="$STATE_DIR/memory/main.sqlite"
if [ -f "$NEW_DB" ]; then DB="$NEW_DB"; else DB="$LEGACY_DB"; fi

python3 - "$WORKSPACE" "$DB" <<'PYEOF'
import os, re, sys, sqlite3, time, glob, subprocess

WS, DB = sys.argv[1], sys.argv[2]
now = time.time()
DAY = 86400.0
DAILY_RE = re.compile(r"^\d{4}-\d{2}-\d{2}\.md$")

def p(*a): print(*a)

p("=== memory-maintenance check @ %s ===" % time.strftime("%F %T"))
p("workspace: %s" % WS)
p("db:        %s" % DB)
p("")

# ---- load index (read-only; current unified DB + legacy DB) ----
idx = {}   # relpath -> (mtime_ms, size)
db_ok = os.path.exists(DB)
chunk_count = 0
source_table = "none"
if db_ok:
    con = sqlite3.connect("file:%s?mode=ro" % DB, uri=True)
    tables = {r[0] for r in con.execute("SELECT name FROM sqlite_master WHERE type='table'")}
    if "memory_index_sources" in tables:
        source_table = "memory_index_sources"
        rows = con.execute("SELECT path, mtime, size FROM memory_index_sources WHERE source='memory'")
        chunk_count = con.execute("SELECT count(*) FROM memory_index_chunks").fetchone()[0]
    elif "files" in tables:
        source_table = "files"
        rows = con.execute("SELECT path, mtime, size FROM files WHERE source='memory'")
        chunk_count = con.execute("SELECT count(*) FROM chunks").fetchone()[0]
    else:
        rows = []
        db_ok = False
    for path, mtime, size in rows:
        idx[path] = (float(mtime) / 1000.0, size)
    con.close()

# ---- disk set: 索引対象は MEMORY.md + memory/**/*.md（再帰）----
disk = {}  # relpath -> (mtime, size)
mm = os.path.join(WS, "MEMORY.md")
if os.path.exists(mm):
    disk["MEMORY.md"] = (os.path.getmtime(mm), os.path.getsize(mm))
for f in sorted(glob.glob(os.path.join(WS, "memory", "**", "*.md"), recursive=True)):
    disk[os.path.relpath(f, WS)] = (os.path.getmtime(f), os.path.getsize(f))

# ============ (a) INDEX COVERAGE ============
p("## (a) index coverage (disk vs OpenClaw index)")
if not db_ok:
    p("  CRITICAL: index db not found — `openclaw memory status` で確認を")
else:
    missing = sorted(set(disk) - set(idx))
    changed = []
    for path, (mt, size) in disk.items():
        if path in idx:
            i_mt, i_size = idx[path]
            if mt - i_mt > 2.0 or size != i_size:
                changed.append(path)
    p("  source table: %s" % source_table)
    p("  indexed files: %d / disk files: %d / chunks: %d" % (len(idx), len(disk), chunk_count))
    if missing:
        p("  MISSING from index (%d):" % len(missing))
        for m in missing: p("    - %s" % m)
    if changed:
        p("  CHANGED since indexed (%d):" % len(changed))
        for c in sorted(changed): p("    - %s" % c)
    if not missing and not changed:
        p("  => ok（全ファイル索引済み・最新）")
    else:
        p("  => `openclaw memory index` で差分再同期を（FTS-only・非破壊）")
p("")

# ============ (b) DEAD POINTERS ============
p("## (b) dead pointers (MEMORY.md + memory/*.md の参照先実在チェック)")
LINK_RE = re.compile(r"\]\(([^)#][^)]*)\)")          # [x](path)
CODE_RE = re.compile(r"`((?:memory/|scripts/|skills/)[^`\s]+)`")  # `memory/foo.md` 等
dead = []
targets = [mm] + sorted(glob.glob(os.path.join(WS, "memory", "*.md")))
for f in targets:
    if not os.path.exists(f): continue
    rel_src = os.path.relpath(f, WS)
    text = open(f, encoding="utf-8", errors="replace").read()
    refs = set(LINK_RE.findall(text)) | set(CODE_RE.findall(text))
    for r in refs:
        r = r.strip()
        if re.match(r"^[a-z]+://", r) or r.startswith("mailto:"):
            continue
        cand = os.path.expanduser(r) if r.startswith("~") else os.path.join(os.path.dirname(f) if not r.startswith(("memory/","scripts/","skills/")) else WS, r)
        # glob 的な表記 (YYYY-MM-DD 等) はスキップ
        if any(ch in r for ch in "*<>{}") or "YYYY" in r:
            continue
        if not os.path.exists(cand):
            dead.append((rel_src, r))
if dead:
    for src, r in dead: p("  DEAD: %s -> %s" % (src, r))
    p("  => %d 件。索引行の修正 or 参照先の復元を" % len(dead))
else:
    p("  => ok（死にポインタなし）")
p("")

# ============ (c) BLOAT / BACKLOG ============
p("## (c) context pressure signals")
if os.path.exists(mm):
    lines = sum(1 for _ in open(mm, encoding="utf-8", errors="replace"))
    size = os.path.getsize(mm)
    flag = "  <== 100行/3KB 超、切り出し検討" if (lines > 100 or size > 3072) else ""
    p("  MEMORY.md: %d lines / %d bytes%s" % (lines, size, flag))
total = sum(s for _, s in disk.values())
p("  memory/**/*.md: %d files / %d bytes total" % (len(disk) - 1, total))
for path, (mt, size) in sorted(disk.items()):
    base = os.path.basename(path)
    if path == "MEMORY.md" or DAILY_RE.match(base) or path.startswith(("memory/users/", "memory/hooks/")): continue
    lines = sum(1 for _ in open(os.path.join(WS, path), encoding="utf-8", errors="replace"))
    if lines > 200:
        p("  LARGE topic observed: %s (%d lines)" % (path, lines))
p("")

# ============ (d) GIT ============
p("## (d) git state")
def git(*args):
    return subprocess.run(["git", "-C", WS] + list(args), capture_output=True, text=True).stdout.strip()
if os.path.isdir(os.path.join(WS, ".git")):
    dirty = git("status", "--porcelain")
    n_dirty = len([l for l in dirty.splitlines() if l.strip()])
    last = git("log", "-1", "--format=%ct %h %s")
    if last:
        ct, rest = last.split(" ", 1)
        p("  last commit: %s (%s, %.1f days ago)" % (rest, time.strftime("%F", time.localtime(int(ct))), (now - int(ct)) / DAY))
    p("  uncommitted changes: %d files" % n_dirty)
    if n_dirty > 0:
        p("  => dirty のため原則 audit-only。編集対象との overlap を確認（SKILL.md）")
else:
    p("  not a git repo")
p("")
p("=== end of check ===")
PYEOF
