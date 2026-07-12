# MEMORY.md — long-term memory index (L0)

<!-- Structure: this index (keep it thin, ~100 lines / 3KB) → memory/<topic>.md (L1 detail, kept flat) → memory/knowledge/<topic>.md (L2 deep dive, pointer-only). Procedures live in skills/ and scripts/, never here. Convention: AGENTS.md "Memory" section. -->

## Durable notes

<!-- Durable facts / decisions go here, one line each. When a line needs detail, split it into a topic file and add an index line below. -->

- Default reply language and tone are configured in `SOUL.md`.

## Index

- [example project overview](memory/example-project.md) — what the project is, who it serves, architecture at a glance. Read for any project-related topic. _(dummy — replace with your own.)_
- cron registry: `memory/cron-registry.json` — the source of truth for ALL cron jobs (category: reminder/report/automation, with purpose + reviewBy). Do not infer jobs from cron names/prompts; read this explicit metadata. **Always update it in the same turn you add/change/remove a job.** Two runners: agentTurn=true → LLM cron / agentTurn=false (pure relay) → OS scheduler + `scripts/relay_run.py`. Drift detection: `scripts/cron_registry_check.py`.
- [inbound hooks](memory/hooks/) — durable inbound workflows (see `hooks/README.md`). Check the relevant hook before replying to an inbound message.
- user structured notes: `memory/users/<user-id>.md` (+ `.weekly_schedule.json` etc.) — per-user habits, constraints, schedules. Sample: `memory/users/example-user.md`.
- daily raw logs: `memory/YYYY-MM-DD.md` — today + yesterday auto-load; older ones via memory search.
