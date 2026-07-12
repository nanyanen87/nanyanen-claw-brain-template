# openclaw-brain-template

A starter "brain" for an [OpenClaw](https://openclaw.ai)-style personal AI manager: the always-on identity, memory, and operations layer that lives in the agent's home workspace. It ships an anonymized `AGENTS.md` / `SOUL.md` / `IDENTITY.md`, a three-tier progressive-disclosure memory convention, two example skills that split deterministic work from LLM judgment, and a self-auditing cron ledger. It is a **template plus a written explanation of the conventions** — not a running product. Fill in the placeholders, delete what you don't want, and make it yours.

---

## これは何か / なぜ作ったか / 何が独自か

**これは何か。** OpenClaw のような「常駐 AI マネージャー」の頭脳（ホームワークスペース）を組むための雛形です。人格（`SOUL.md` / `IDENTITY.md`）、行動規約（`AGENTS.md`）、階層化メモリ（`MEMORY.md` + `memory/`）、スキル（`skills/`）、定期ジョブ台帳（`memory/cron-registry.json`）と自己監査スクリプト（`scripts/`）が一式入っています。個人情報はすべてダミー／`<PLACEHOLDER>` に置換済みで、**規約・構造・設計思想の文章はそのまま**残してあります。

**なぜ作ったか。** OpenClaw 本体はランタイム（ゲートウェイ・スキル仕様・cron 実行）を与えますが、「エージェントが長期に破綻しないための運用規約」までは規定しません。実運用で効いた規約 — メモリを薄い索引から辿らせる、手順はメモリに書かずツール化する、定期ジョブは台帳で正を持ち実機との差分を自己監査する — を、他の人が流用できる形に切り出したものです。

**何が独自か。** 下の「上流との境界表」に集約しています。要は、OpenClaw 本体が持つ「スキル標準」「cron のジョブ型分離」「実行ログの照合」の上に、本テンプレが **メモリの階層規約＋週次自己蒸留**、**purpose/reviewBy 付き cron 台帳＋台帳↔実機のドリフト監査**、**TOOLS.md 索引規約** を足しています。

---

## Upstream boundary — what OpenClaw already gives you vs. what this template adds

> **As of OpenClaw 2026-07.** OpenClaw moves fast; re-check upstream before assuming a row still holds. This table is a snapshot of the division of labor, not a spec.

| Concern | In OpenClaw core (upstream) | Added by this template |
| --- | --- | --- |
| **Skills** | `SKILL.md` standard (AgentSkills spec) + Skill Workshop for authoring | Two worked examples that document their *design intent* in the skill itself, and split deterministic collection from LLM judgment (`news-digest`, `memory-maintenance`) |
| **Scheduled jobs** | Cron with a `command` payload that separates LLM vs. non-LLM job types | A **purpose/reviewBy-annotated cron ledger** (`memory/cron-registry.json`) as the source of truth, plus **ledger↔live drift self-audit** (`scripts/cron_registry_check.py`) |
| **Execution accounting** | Reconciliation between the runtime and its execution logs | — (relies on upstream) |
| **Memory** | — (no prescribed memory hierarchy) | **L0/L1/L2 progressive-disclosure memory convention** + **weekly self-distillation** via `memory-maintenance` |
| **Tool index** | — | **`TOOLS.md` index convention** — a thin index that points at each skill's `SKILL.md` and each script's header, never duplicating them |

The middle column is deliberately honest about what you get for free. The value here is the right column: a set of conventions that keep a long-lived agent's context small and its automation honest.

---

## Design philosophy

### 1. Memory as a hierarchy (progressive disclosure)

The failure mode of agent memory is a single ever-growing file that burns context on every load. This template splits it into layers, and only the thin top layer is always loaded:

- **L0 — `MEMORY.md` (index):** one line per topic, and crucially *when to read it*. Kept under ~100 lines / 3 KB. No details — only pointers. Retrieval quality is decided by the quality of these index lines.
- **L1 — `memory/<topic>.md`:** one topic per file, kept flat. ~400-token chunks index best. 80% of lookups should be satisfiable here.
- **L2 — `memory/knowledge/<topic>.md`:** long detail, *not* auto-loaded, reachable only by an explicit path from L1/L0. One deep-link hop max — no L2→L2 chains.
- **Daily logs — `memory/YYYY-MM-DD.md`:** raw notes. Today + yesterday auto-load; older ones via search.

The rule that holds it together: **the index and the filesystem must always agree.** A file the index doesn't mention is invisible; a pointer to a file that doesn't exist is a dead pointer. `skills/memory-maintenance/check.sh` verifies both mechanically.

### 2. Cron ledger + self-audit

Every periodic job is registered in `memory/cron-registry.json` with a `purpose`, a `category` (reminder/report/automation), and a `reviewBy` date. Two things make this more than documentation:

- **`agentTurn` decides the payload.** Pure relays (a deterministic script's stdout posted verbatim, no LLM judgment) are created with `openclaw cron add --command <shell>` and run on the Gateway — no agent turn spent. Jobs needing generation/judgment use `--message` and run through the LLM cron. Both are the same underlying mechanism, so both show up identically in `openclaw cron list --json`. Deciding `agentTurn` first keeps token spend off mechanical jobs, and keeps this portable: the ledger doesn't care whether the Gateway is on a dev Mac or a VPS.
- **The ledger is audited against reality.** `scripts/cron_registry_check.py` diffs the registry against `openclaw cron list --json` — unregistered jobs, dead pointers, schedule/target mismatches, `agentTurn` vs. live payload-kind mismatches, `reviewBy`-overdue entries, and jobs erroring in production — and reports (never mutates). Drift is fixed by hand on whichever side is wrong.

`reviewBy` is the quiet part: it forces a periodic "keep / change / retire" decision so dead automations don't accumulate.

**What a weekly audit report looks like** — both outputs below were produced by the shipped `scripts/cron_registry_check.py` against the shipped dummy registry (with `openclaw cron list --json` stubbed to a fixture, so you can reproduce them without a live Gateway):

```
【cron 台帳ドリフトチェック｜2026-07-13】
問題なし。台帳 3 件（agentTurn 2 / command 1） / 実 cron 3 件、全項目一致。
※台帳: memory/cron-registry.json（新規 cron 作成時は登録必須）
```

And when the live scheduler has drifted from the ledger:

```
【cron 台帳ドリフトチェック｜2026-07-13】
■ ドリフト 3 件（台帳か cron のどちらか正しい側に手動で合わせる）
- 台帳未登録の cron: 「ad-hoc-experiment」(11111111)
- schedule 不一致: daily-standup-reminder 台帳=0 9 * * 1-5@Asia/Tokyo 実機=30 9 * * 1-5@Asia/Tokyo
- payload 種別不一致: daily-calendar-relay 台帳 agentTurn=False（command 想定）実機=agentTurn
※台帳: memory/cron-registry.json（新規 cron 作成時は登録必須）
```

### 3. Procedures are tools, not memory

Repeatable workflows do **not** get written into memory as prose. They become a skill (`skills/<name>/SKILL.md`) or a script (`scripts/*` with a self-documenting header), and memory points at them by path — nothing more. `TOOLS.md` is the thin index over those, deferring to each `SKILL.md` / script header for the actual spec. This keeps the "how" versioned next to the code that runs it, and keeps memory about facts and decisions.

---

## Layout

```
.
├── AGENTS.md          # behavior/routing conventions (generic layer)
├── SOUL.md            # personality + default language
├── IDENTITY.md        # who the agent is (placeholders)
├── USER.md            # who the human is (blank template)
├── MEMORY.md          # L0 index (thin)
├── TOOLS.md           # index over skills + scripts
├── HEARTBEAT.md       # periodic-check checklist (empty by default)
├── skills/
│   ├── memory-maintenance/   # weekly memory tidy-up (check.sh + SKILL.md)
│   └── news-digest/          # deterministic fetch + LLM selection
├── scripts/
│   └── cron_registry_check.py  # ledger↔live drift audit (report-only)
└── memory/
    ├── cron-registry.json   # dummy job ledger (schema v2)
    ├── example-project.md   # L1 topic (dummy)
    ├── 2026-01-15.md        # daily log (dummy)
    ├── hooks/               # inbound-message workflow hooks
    └── users/               # per-user structured notes (dummy)
```

## Using it

1. Copy this into your agent's home workspace (OpenClaw's default is a `~/openclaw-workspace`-style directory).
2. Fill in the `<PLACEHOLDER>` tokens in `IDENTITY.md`, `SOUL.md`, `USER.md`.
3. Replace the dummy `memory/` contents and the `cron-registry.json` sample with your own.
4. Keep or drop the example skills. `memory-maintenance` is the one most worth keeping.

---

## What this is NOT

- **Not a running product.** There is no gateway, no installer, no daemon here. It is scaffold files plus the conventions that make them cohere. OpenClaw (or an equivalent host) provides the runtime.
- **Not a maintained OSS package.** No release cadence, no support, no compatibility promise. Upstream OpenClaw will change; the boundary table will drift. Treat this as a snapshot to learn from and fork, not a dependency to pin.
- **Not a config you can run unedited.** The cron ledger, user notes, and identity are dummies. Nothing here is wired to a real chat platform or scheduler until you wire it.
- **Not security-hardened for your environment.** The skills assume a trusted, single-user workspace. Review before pointing them at anything real.
- **Not bilingual throughout.** The README is English/Japanese, but skill documentation and script output are currently Japanese-only.

## License

MIT — see [LICENSE](./LICENSE).
