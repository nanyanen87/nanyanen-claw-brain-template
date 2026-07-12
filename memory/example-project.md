# Example project — overview (L1, DUMMY)

<!-- This is a dummy L1 topic file to show the shape. One topic per file, one heading per subtopic (~400-token chunks index best). Replace with your own. -->

## What it is

`<PROJECT_NAME>` is a fictional SaaS used here only to demonstrate the memory layout. It has a web client, an API, and a background worker.

## Who it serves

Small teams who want `<VALUE_PROP>`. Not relevant to the template mechanics — this is placeholder content.

## Architecture at a glance

- **web** — the client app (`repos/<project>-web`)
- **api** — the backend (`repos/<project>-api`)
- **worker** — scheduled/background jobs (`repos/<project>-worker`)

Deeper design notes that would make this file exceed ~200 lines belong in an L2 file, e.g. `memory/knowledge/example-project-architecture.md`, linked from here by path (one hop only).

## Decisions worth remembering

- 2026-01-10 — chose a monorepo layout for the three services. (Example durable decision; this is the kind of line that graduates from a daily log up to a topic file.)
