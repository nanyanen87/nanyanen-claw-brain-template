# TOOLS.md - Local Notes

Environment-specific tool notes. The source of truth for how a skill works is its `SKILL.md`; for a script's spec, its header comment — this file is only an index and environment-specific caveats.

## Brain core

- Shared/private boundary and promotion policy: `README.md`
- Drift check: `scripts/brain_core_sync.py --upstream <template-path>`

## Automation governance (skill: `automation-governance`)

Use this skill for cron, heartbeat, and hook changes or audits. Prefer the least machinery and one small source of current intent when one is actually needed.

## Memory maintenance (skill: `memory-maintenance` 🧹)

Read-only-first memory audit. The procedure lives in `skills/memory-maintenance/SKILL.md`; its `check.sh` reports retrieval and context-pressure signals without making changes. Schedule it only if the deployment demonstrates a need.

## News digest (skill: `news-digest` 📰)

A personal morning news digest. A cron job (e.g. daily 07:30 → a chat channel) runs it. The source of truth for the procedure is `skills/news-digest/SKILL.md`. Collection is `bin/fetch_feeds.py` (deterministic); the selection criteria live in `preferences.md` (updated continuously from feedback). When a human says "news," follow the same SKILL.md.

## Scripts (`scripts/`) 🔧

Index of automation scripts. The source of truth for each spec is its own header comment (one line here).

- `cron_registry_check.py` — detects drift between the cron registry and `openclaw cron list --json` (both agentTurn=true LLM jobs and agentTurn=false command-payload jobs), plus agentTurn/payload-kind mismatches, reviewBy-overdue, and execution errors (report-only).

## Local device / connection notes

_(Keep camera names, SSH details, voice preferences, and other environment-specific facts here. Empty in the template.)_
