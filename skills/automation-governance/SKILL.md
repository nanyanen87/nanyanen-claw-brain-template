---
name: automation-governance
description: Inspect or change recurring jobs, reminders, cron, heartbeat, hooks, and automation drift in an OpenClaw workspace. Use when scheduled work needs the least-complex suitable runner, current state must be reconciled, or an automation may be stale, duplicated, or unsafe.
---

# Automation governance

Use the least machinery that preserves the user's intent.

## Choose a mechanism

- Prefer a reminder that starts a human-agent session when the work needs judgment or conversation. Do not encode the whole future session in the reminder.
- Use OpenClaw cron commands for deterministic work and agent messages only when model judgment is part of the job.
- Use heartbeat for small context-aware checks that tolerate timing drift, and hooks for event-driven work.
- Use an OS scheduler only for a requirement the OpenClaw runtime cannot meet.

## Change or audit

1. Inspect live state and any existing registry or local notes. Treat runtime history and conversation as evidence; do not reconstruct intent from a job name alone.
2. Preserve one small source of current intent when needed to resume or audit the job. Follow its existing schema instead of inventing parallel ledgers or mandatory fields.
3. Make the narrowest change through the supported runtime interface. Do not edit OpenClaw state databases directly.
4. Verify the resulting live state and, when useful, one run. Report remaining ambiguity or drift.

Keep secrets out of schedules, commands, registries, and reports. Do not require a feedback questionnaire or new state machine for ordinary jobs; infer decisions from the session and ask only when ambiguity changes the outcome.

Keep or add deterministic drift checks when they catch a demonstrated failure cheaply. Retire duplicated machinery instead of layering another reconciler on top.
