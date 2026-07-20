# Classification

Classify the smallest meaningful change, usually a hunk or rule rather than an entire commit.

## OpenClaw core

Use when the reusable fix belongs to runtime behavior: tool execution contracts, exit-code interpretation, scheduler semantics, transport behavior, error rendering, memory/plugin substrate, or configuration schema.

Example: a successful agent answer incorrectly displays a stale nonfatal shell failure. Propose changing core error-state or rendering semantics; do not export a private shell command.

## Public brain template

Use when the reusable improvement is agent behavior or an operator-owned capability: generic instructions, a skill, a deterministic script, memory organization, feedback procedure, or environment-independent safety rule.

Example: check an optional file before reading it and treat an expected search miss as nonfatal. Export the general rule without private paths or incidents.

## Private only

Keep private when the change contains identity, conversation memory, company process, customer or employee data, credentials, private endpoints, channel IDs, deployment topology, repository inventory, or a script useful only to one environment.

Example: the name and schedule of a company analytics timer remain private even if its generic retry pattern can be rewritten for the public template.

## Mixed changes

Split mixed commits. Describe the general mechanism from scratch and use the private diff only as evidence. Do not copy a hunk and then redact names if its structure still reveals private operations.

Before approval, verify that public drafts contain none of:

- Secret values or credential-shaped strings
- Names, account IDs, channel IDs, internal URLs, or private repository names
- Absolute paths tied to a person or host
- Raw memory, conversations, incident details, or proprietary business rules
- Commit hashes that expose a private repository unless explicitly approved
