#!/usr/bin/env python3
"""Drift check between memory/cron-registry.json and live `openclaw cron list --json`.

Usage:
  python3 scripts/cron_registry_check.py

Report-only (never mutates registry or cron; always exits 0 unless the inputs
themselves are broken). Checks:
  runner=openclaw-cron (agentTurn=true):
    1. unregistered cron jobs (live cron not in registry)
    2. dead pointers (registry entry whose cronJobId no longer exists)
    3. field mismatches (schedule expr/tz, delivery target, enabled)
    4. unhealthy jobs (lastRunStatus == error / consecutiveErrors > 0)
  runner=launchd (agentTurn=false, relay jobs):
    5. plist missing / not loaded / non-zero last exit status
  common:
    6. reviewBy overdue entries

Output is deterministic, Discord-ready Japanese. Index: TOOLS.md "Scripts".
"""
from __future__ import annotations

import datetime
import json
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REGISTRY = ROOT / "memory" / "cron-registry.json"
JST = datetime.timezone(datetime.timedelta(hours=9))


def load_registry() -> dict:
    try:
        data = json.loads(REGISTRY.read_text(encoding="utf-8"))
    except FileNotFoundError:
        raise SystemExit(f"cron registry not found: {REGISTRY}")
    except json.JSONDecodeError as exc:
        raise SystemExit(f"invalid cron registry JSON: {exc}")
    if data.get("schemaVersion") != 2:
        raise SystemExit(f"unsupported schemaVersion: {data.get('schemaVersion')!r}")
    return data


def load_live_jobs() -> list[dict]:
    proc = subprocess.run(
        ["openclaw", "cron", "list", "--json"],
        capture_output=True, text=True, timeout=60,
    )
    if proc.returncode != 0:
        raise SystemExit(f"openclaw cron list failed: {proc.stderr.strip()[:200]}")
    data = json.loads(proc.stdout)
    return data if isinstance(data, list) else data.get("jobs", [])


def delivery_target(job: dict) -> str:
    d = job.get("delivery") or {}
    to = str(d.get("to", ""))
    ch = d.get("channel", "")
    if not ch or not to:
        return ""
    if ":" not in to:  # 実機側は "channel:" プレフィックスを省くことがある
        to = f"channel:{to}"
    return f"{ch}:{to}"


def check_launchd(entry: dict) -> list[str]:
    label = entry.get("launchdLabel", "")
    out: list[str] = []
    if not label:
        return [f"launchd ジョブに launchdLabel がない: {entry['id']}"]
    plist = Path.home() / "Library" / "LaunchAgents" / f"{label}.plist"
    if not plist.exists():
        return [f"plist が存在しない: {entry['id']} → {plist}"]
    proc = subprocess.run(
        ["launchctl", "print", f"gui/{os.getuid()}/{label}"],
        capture_output=True, text=True, timeout=30,
    )
    if proc.returncode != 0:
        out.append(f"launchd にロードされていない: {entry['id']} ({label})")
        return out
    m = re.search(r"last exit code = (\S+)", proc.stdout)
    if m and m.group(1) not in ("0", "(never", "never"):
        out.append(f"relay 最終実行が異常終了: {entry['id']} (exit {m.group(1)})")
    return out


def main() -> int:
    registry = load_registry()
    live = load_live_jobs()
    live_by_id = {j["id"]: j for j in live}
    entries = registry.get("jobs", [])
    cron_entries = [e for e in entries if e.get("runner") == "openclaw-cron"]
    launchd_entries = [e for e in entries if e.get("runner") == "launchd"]
    reg_by_cron = {e["cronJobId"]: e for e in cron_entries}
    today = datetime.datetime.now(JST).date()

    problems: list[str] = []

    for job in live:
        if job["id"] not in reg_by_cron:
            problems.append(f"台帳未登録の cron: 「{job.get('name')}」({job['id'][:8]})")

    for e in cron_entries:
        job = live_by_id.get(e["cronJobId"])
        if job is None:
            problems.append(f"死にポインタ: {e['id']} → cron {e['cronJobId'][:8]} が存在しない")
            continue
        rs, ls = e.get("schedule", {}), job.get("schedule", {})
        if rs.get("expr") != ls.get("expr") or rs.get("tz") != ls.get("tz"):
            problems.append(
                f"schedule 不一致: {e['id']} 台帳={rs.get('expr')}@{rs.get('tz')} "
                f"実機={ls.get('expr')}@{ls.get('tz')}"
            )
        lt = delivery_target(job)
        if lt and e.get("deliveryTarget") != lt:
            problems.append(f"投稿先不一致: {e['id']} 台帳={e.get('deliveryTarget')} 実機={lt}")
        if bool(e.get("enabled")) != bool(job.get("enabled")):
            problems.append(
                f"enabled 不一致: {e['id']} 台帳={e.get('enabled')} 実機={job.get('enabled')}"
            )

    for e in launchd_entries:
        if e.get("enabled"):
            problems.extend(check_launchd(e))

    overdue = []
    for e in entries:
        rb = e.get("reviewBy")
        if rb and datetime.date.fromisoformat(rb) < today:
            overdue.append(f"見直し期限超過: {e['id']} (reviewBy {rb}) — 継続/変更/廃止を判断して reviewBy を更新")

    unhealthy = []
    for e in cron_entries:
        job = live_by_id.get(e["cronJobId"])
        state = (job or {}).get("state", {})
        if state.get("lastRunStatus") == "error" or state.get("consecutiveErrors", 0) > 0:
            reason = state.get("lastError") or state.get("lastErrorReason") or "unknown"
            unhealthy.append(
                f"実行エラー: {e['id']} (連続{state.get('consecutiveErrors', 0)}回, {reason})"
            )

    lines = [f"【cron 台帳ドリフトチェック｜{today.isoformat()}】"]
    if not problems and not overdue and not unhealthy:
        lines.append(
            f"問題なし。台帳 {len(entries)} 件"
            f"（agent turn {len(cron_entries)} / relay {len(launchd_entries)}）"
            f" / 実 cron {len(live)} 件、全項目一致。"
        )
    else:
        if problems:
            lines.append(f"■ ドリフト {len(problems)} 件（台帳か cron のどちらか正しい側に手動で合わせる）")
            lines += [f"- {p}" for p in problems]
        if overdue:
            lines.append(f"■ 見直し期限超過 {len(overdue)} 件")
            lines += [f"- {p}" for p in overdue]
        if unhealthy:
            lines.append(f"■ 実行エラー {len(unhealthy)} 件")
            lines += [f"- {p}" for p in unhealthy]
    lines.append("※台帳: memory/cron-registry.json（新規 cron 作成時は登録必須）")
    print("\n".join(lines))
    return 0


if __name__ == "__main__":
    sys.exit(main())
