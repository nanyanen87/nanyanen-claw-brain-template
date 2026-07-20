---
name: brain-feedback
description: Review commits from one private OpenClaw Living Brain, classify changes for OpenClaw core, a public brain template, or private-only retention, and prepare sanitized upstream proposals with human approval and a reviewed checkpoint. Use for periodic brain feedback, upstream review, commit-range promotion, or deciding whether private agent growth should become reusable OSS guidance.
---

# Brain Feedback

Review one source Living Brain and one commit range per run. Treat every commit in the range as input; do not require candidate notes or special commit prefixes.

## Inputs

Obtain these without copying them into the public skill:

- Private source repository path
- Source identifier such as `company` or `personal`
- OpenClaw core and public brain-template destinations
- The latest `feedback-reviewed/<source>` tag, if present

Keep repository URLs, credentials, notification targets, and raw diffs in the private environment.

## Workflow

1. Confirm the source repository is the intended Living Brain. Do not combine company and personal sources in one run.
2. Run `scripts/collect-commits.sh --repo <path> --source <id> --output <private-dir>`. The script resolves `feedback-reviewed/<source>` and writes the commit list plus raw series patch only inside the chosen private directory.
3. If the range is empty, report a no-op and leave the checkpoint unchanged.
4. Read `references/classification.md`, then classify changes line by line. Split a commit when its lines have different destinations.
5. Produce a private review summary containing each commit, its selected destination, excluded private portions, and the generalized mechanism. This summary is a review artifact, not a candidate ledger.
6. Draft destination-specific artifacts from the generalized mechanism only:
   - OpenClaw core: issue or patch when runtime, tool, scheduler, transport, or error semantics must change.
   - Public brain template: patch or draft PR for reusable instructions, skills, or deterministic scripts.
   - Private-only: no upstream artifact.
7. Scan every draft for credentials, personal or company identifiers, private URLs, channel IDs, absolute private paths, and private source text. Rebuild the draft from the generalized description if sanitization is uncertain; do not edit leaked raw text in place.
8. Present the classification and proposed public artifacts for human approval. Do not publish, message third parties, or update the checkpoint before approval.
9. Publish only approved issue/PR artifacts. A human-approved all-private or no-op decision also completes the review.
10. Advance the private source checkpoint only after all commits in the range have an approved disposition:

   ```bash
   git -C <source-repo> tag -f feedback-reviewed/<source> <reviewed-head>
   git -C <source-repo> push --force origin refs/tags/feedback-reviewed/<source>
   ```

11. Record the reviewed head and resulting issue/PR URLs in the private run summary. Do not add a second persistent candidate list.

## Guardrails

- Never send a raw private patch to a public repository, external model, issue, or PR.
- Never infer that a whole commit is public because one line is reusable.
- Never publish automatically from a scheduled run. Scheduling may collect and classify, but human approval gates external writes.
- Never advance the checkpoint for a partially reviewed range.
- Preserve source ordering and evidence until the review completes.
