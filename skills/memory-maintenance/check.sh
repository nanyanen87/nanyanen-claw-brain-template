#!/usr/bin/env bash
# ============================================================================
# check.sh — memory-maintenance の機械チェック（LLM 不要 / 読み取り専用）
# ----------------------------------------------------------------------------
# WHAT:  検索索引 (~/.openclaw/memory/main.sqlite) と脳ファイル (MEMORY.md /
#        memory/**) の健全性を機械的に検査し、構造化テキストで出力する。検査:
#          (a) 索引カバレッジ（disk にあるが files テーブルに無い / 内容更新済み）
#          (b) 死にポインタ（MEMORY.md + memory/*.md の参照先の実在）
#          (c) 肥大レポート（MEMORY.md 行数/サイズ、トピックファイル、日次ログ滞留）
#          (d) git 状態（未コミット差分、最終コミットからの経過日数）
# WHY:   AGENTS.md Memory 節の蓄積規約（L0 薄く・索引と実体の一致・蒸留）を
#        週次で定着させるハーネスの検査部。判断と整理の実行は LLM 側
#        （SKILL.md の手順に従う）。
# HOW:   cron の memory-maintenance ジョブが SKILL.md 経由で実行する。
#        手動実行も可: bash skills/memory-maintenance/check.sh
# SAFETY: 検知して報告するのみ。書き込み・削除・reindex は一切しない。
#         sqlite は read-only (mode=ro) 接続。
# ============================================================================
set -euo pipefail

WORKSPACE="$HOME/openclaw-workspace"
DB="$HOME/.openclaw/memory/main.sqlite"

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

# ---- load index (read-only) ----
idx = {}   # relpath -> (mtime_ms, size)
db_ok = os.path.exists(DB)
chunk_count = 0
if db_ok:
    con = sqlite3.connect("file:%s?mode=ro" % DB, uri=True)
    for path, mtime, size in con.execute("SELECT path, mtime, size FROM files WHERE source='memory'"):
        idx[path] = (float(mtime) / 1000.0, size)
    chunk_count = con.execute("SELECT count(*) FROM chunks").fetchone()[0]
    con.close()

# ---- disk set: 索引対象は MEMORY.md + memory/**/*.md（再帰）----
disk = {}  # relpath -> (mtime, size)
mm = os.path.join(WS, "MEMORY.md")
if os.path.exists(mm):
    disk["MEMORY.md"] = (os.path.getmtime(mm), os.path.getsize(mm))
for f in sorted(glob.glob(os.path.join(WS, "memory", "**", "*.md"), recursive=True)):
    disk[os.path.relpath(f, WS)] = (os.path.getmtime(f), os.path.getsize(f))

# ============ (a) INDEX COVERAGE ============
p("## (a) index coverage (disk vs files table)")
if not db_ok:
    p("  CRITICAL: index db not found — check your memory index status")
else:
    missing = sorted(set(disk) - set(idx))
    changed = []
    for path, (mt, size) in disk.items():
        if path in idx:
            i_mt, i_size = idx[path]
            if mt - i_mt > 2.0 or size != i_size:
                changed.append(path)
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
        p("  => 差分再同期を（FTS-only・非破壊）")
p("")

# ============ (b) DEAD POINTERS ============
p("## (b) dead pointers (MEMORY.md + memory/*.md の参照先実在チェック)")
LINK_RE = re.compile(r"\]\(([^)#][^)]*)\)")          # [x](path)
CODE_RE = re.compile(r"`((?:~/openclaw-workspace/|memory/|scripts/|skills/)[^`\s]+)`")  # `memory/foo.md` 等
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
p("## (c) bloat & daily-log backlog")
if os.path.exists(mm):
    lines = sum(1 for _ in open(mm, encoding="utf-8", errors="replace"))
    size = os.path.getsize(mm)
    flag = "  <== 100行/3KB 超、切り出し検討" if (lines > 100 or size > 3072) else ""
    p("  MEMORY.md: %d lines / %d bytes%s" % (lines, size, flag))
total = sum(s for _, s in disk.values())
p("  memory/**/*.md: %d files / %d bytes total" % (len(disk) - 1, total))
for path, (mt, size) in sorted(disk.items()):
    base = os.path.basename(path)
    if path == "MEMORY.md" or DAILY_RE.match(base): continue
    lines = sum(1 for _ in open(os.path.join(WS, path), encoding="utf-8", errors="replace"))
    if lines > 200:
        p("  LARGE topic: %s (%d lines) — 分割/剪定候補" % (path, lines))
# 日次ログ滞留: 14 日超の daily で durable 内容が蒸留されていない候補
stale_daily = []
for path in disk:
    base = os.path.basename(path)
    m = DAILY_RE.match(base)
    if not m: continue
    try:
        ts = time.mktime(time.strptime(base[:-3], "%Y-%m-%d"))
    except ValueError:
        continue
    if (now - ts) / DAY > 14 and disk[path][1] > 0:
        stale_daily.append((path, disk[path][1]))
if stale_daily:
    p("  daily-log backlog (>14日・蒸留候補): %d 件" % len(stale_daily))
    for path, size in sorted(stale_daily): p("    - %s (%d bytes)" % (path, size))
else:
    p("  daily-log backlog: なし")
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
        p("  => 保守実行時に pre/post スナップショットコミットを（SKILL.md 手順 2）")
else:
    p("  not a git repo")
p("")
p("=== end of check ===")
PYEOF
