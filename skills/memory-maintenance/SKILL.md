---
name: memory-maintenance
description: Audit an OpenClaw workspace's memory retrieval, index coverage, pointers, contradictions, and context pressure. Use when memory search is stale, current state is unclear, always-loaded context is noisy, or the user asks to inspect or simplify memory without losing raw history.
---

# Memory maintenance

Preserve evidence, keep current state small, and change only what has a demonstrated retrieval or context cost.

Run the read-only checker from the workspace root:

```bash
bash skills/memory-maintenance/check.sh
```

Treat size findings as signals, not automatic rewrite thresholds. Prefer search and just-in-time retrieval over reorganizing data for its own sake.

When an edit is useful:

- repair a broken pointer or stale current fact without rewriting unrelated history
- keep raw conversations and daily logs unless deletion is explicitly requested
- treat summaries, topic files, and indexes as replaceable views over source evidence
- preserve the source and scope of extracted human decisions when meaningful; do not promote tentative remarks into global policy
- leave structured or script-owned data to its owner
- rerun `openclaw memory index` only when the audit shows indexing drift

If relevant files already have uncommitted changes, remain audit-only unless ownership is unambiguous. Never use blanket staging, delete memory files, edit state databases directly, or expose private memory in shared contexts.
