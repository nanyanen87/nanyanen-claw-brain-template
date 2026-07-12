# TOOLS.md - Local Notes

Environment-specific tool notes. The source of truth for how a skill works is its `SKILL.md`; for a script's spec, its header comment — this file is only an index and environment-specific caveats.

## Memory maintenance (skill: `memory-maintenance` 🧹)

Weekly memory-tidying harness. A cron job (e.g. Monday 08:30) runs it. The source of truth for the procedure is `skills/memory-maintenance/SKILL.md`; the mechanical check is its `check.sh` (read-only). When a human says "tidy up memory," follow the same SKILL.md.

## News digest (skill: `news-digest` 📰)

A personal morning news digest. A cron job (e.g. daily 07:30 → a chat channel) runs it. The source of truth for the procedure is `skills/news-digest/SKILL.md`. Collection is `bin/fetch_feeds.py` (deterministic); the selection criteria live in `preferences.md` (updated continuously from feedback). When a human says "news," follow the same SKILL.md.

## Scripts (`scripts/`) 🔧

Index of automation scripts. The source of truth for each spec is its own header comment (one line here).

- `cron_registry_check.py` — detects drift between the cron registry and the live scheduler (LLM cron + OS-scheduler relays), plus reviewBy-overdue and execution errors (report-only).
- `relay_run.py` — runs a relay job (agentTurn=false) by id and posts its stdout to the delivery target. Referenced by the registry; not shipped in this template — see the registry `runner: launchd` example. _(Bring your own relay runner + chat poster.)_

## Local device / connection notes

_(Keep camera names, SSH details, voice preferences, and other environment-specific facts here. Empty in the template.)_
