# openclaw-brain-template

A small shared brain core and anonymized personal-workspace template for [OpenClaw](https://openclaw.ai). It keeps durable evidence and instance data private, current state small, capabilities discoverable, and irreversible boundaries explicit. It is a **brain distribution**, not the OpenClaw runtime or a prescribed reasoning pipeline.

## これは何か / なぜ作ったか / 何が独自か

**これは何か。** OpenClawを個人AIとして長期運用するための薄い共有coreとworkspace例です。人格、memory、skill、automationの置き場所は示しますが、agentの思考手順を一つに固定しません。個人情報はダミーまたはplaceholderです。

**なぜ作ったか。** OpenClaw本体はGateway、channel、workspace context、memory検索、skills、cron、heartbeat、実行履歴を提供します。deployment側に必要なのは、それらを再実装することではなく、常時ロードを小さくし、個人データを共有policyから分離し、必要な能力をjust-in-timeで使える状態に保つことです。

**何が独自か。** このtemplateは、rawな会話・操作履歴を証拠、memoryや要約を交換可能なview、現在状態を小さなprojectionとして扱います。共有するのは安全境界と再利用可能なmechanismだけです。個別の判断や経験を、初回からglobal ruleへ変換しません。

## Boundary with OpenClaw

> As of OpenClaw 2026-07. OpenClaw moves quickly; treat this table as a current boundary, not an upstream specification.

| Concern | OpenClaw runtime | This repository |
| --- | --- | --- |
| Context | Injects workspace context and recent memory | Keeps the always-loaded contract small |
| History and memory | Stores session/runtime history and provides memory retrieval | Treats history as evidence and workspace memory as private derived state |
| Skills | Discovers workspace skills | Provides a few optional governance capabilities and examples |
| Automation | Runs cron commands, agent turns, heartbeat, and hooks | Shows simple reminder-first operation and optional drift auditing |
| Safety | Provides runtime and channel boundaries | States stable authority and privacy constraints |
| Distribution | Supports a configurable workspace per agent | Defines an exact shared core and a private overlay |

The runtime should remain the runtime. The brain should remain mostly data, small state, and a few durable boundaries.

## Design

### Evidence first

Conversation and tool history are the best evidence of what happened and what the human decided. Preserve source history when practical. Summaries, topic files, indexes, and extracted decisions may be rebuilt as models improve.

Do not automatically turn one remark, workaround, or failure into policy. For periodic upstream feedback, review the Git commit range directly rather than maintaining a parallel candidate ledger; retain source, scope, uncertainty, and later corrections during the private review.

### Small state, just-in-time context

Keep only the state needed to resume work, honor a commitment, or avoid a known mistake. Store larger history as flat Markdown, JSONL, or runtime records and retrieve it when relevant. Do not inject the full archive into every session.

This template includes an L0/L1-style memory example because it is practical today, not because every deployment must preserve that hierarchy forever.

### Sparse harness

Skills and scripts are capabilities, not compulsory stages in every task. Add a skill when repeated use reveals non-obvious domain knowledge or a fragile procedure. Add a deterministic check when it cheaply catches a demonstrated failure. Otherwise, allow the current model to reason from the user's request, state, and available evidence.

Keep hard constraints for irreversible effects: secrets, privacy, external communication, destructive operations, and authenticated authority.

### Reminder-first work

When work benefits from conversation, schedule a reminder that starts a human-agent session rather than embedding the future session in cron. Let the session use current context and current model capability.

Deterministic jobs may still run directly. The included `memory/cron-registry.json` and `scripts/cron_registry_check.py` are optional examples for deployments that need declared intent and drift checks; they are not a mandatory universal schema.

## Shared core and private overlay

`brain-core.json` declares the few paths that may be synchronized exactly between this OSS checkout and a private workspace.

- **Shared core:** generic `AGENTS.md`, guarded sync, and small memory/automation audit capabilities.
- **Private overlay:** `SOUL.md`, `IDENTITY.md`, `USER.md`, `MEMORY.md`, `TOOLS.md`, heartbeat state, actual jobs, hooks, scripts, channel ids, credentials, conversation-derived state, and all personal memory.
- **Promotion rule:** promote a mechanism only after repeated evidence shows it is still needed beyond ordinary agent judgment. Never promote raw identities, decisions, targets, or private history.
- **Feedback rule:** treat every private Living Brain commit since its reviewed checkpoint as input. Classify at hunk level with `brain-feedback`; a whole commit is not automatically public. OpenClaw core issues are considered only in a separate human-supervised audit that reviews current upstream conversations.

Check a private workspace without modifying it:

```bash
python3 scripts/brain_core_sync.py \
  --upstream /path/to/nanyanen-claw-brain-template \
  --target /path/to/private-workspace
```

Use `--apply` only after review. It refuses to overwrite dirty shared paths and never copies private overlay paths.

## Layout

```text
.
├── AGENTS.md          # small shared authority/context contract
├── SOUL.md            # private persona template
├── IDENTITY.md        # private identity template
├── USER.md            # private user template
├── MEMORY.md          # optional small memory/index view
├── TOOLS.md           # local capability index
├── HEARTBEAT.md       # empty by default
├── brain-core.json    # shared/private boundary
├── skills/
│   ├── automation-governance/ # least-machinery runner selection
│   ├── brain-feedback/        # private commit review and safe promotion
│   ├── memory-maintenance/    # read-only-first memory audit
│   └── news-digest/           # worked personal workflow example
├── scripts/
│   ├── brain_core_sync.py
│   └── cron_registry_check.py # optional drift example
└── memory/
    ├── cron-registry.json     # optional dummy state example
    ├── hooks/
    └── users/
```

## Using it

1. Copy the template into an OpenClaw workspace, or adopt only the paths in `brain-core.json`.
2. Fill the private persona and user placeholders.
3. Replace dummy memory and automation data with your own, or remove examples you do not need.
4. Start simple. Keep a capability only when real use demonstrates its value.

## What this is not

- **Not a runtime or installer.** OpenClaw provides execution.
- **Not a mandatory memory schema.** The included hierarchy is an example view over private evidence.
- **Not a workflow engine.** Skills do not replace general agent judgment.
- **Not automatic self-modification.** Learned rules require evidence and deliberate promotion.
- **Not a config to run unedited.** Jobs, identities, and channels are placeholders.

## License

MIT — see [LICENSE](./LICENSE).
