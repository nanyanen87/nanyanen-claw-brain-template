# Inbound hooks

This directory holds durable workflow hooks for incoming messages.

`AGENTS.md` should only route to this directory. It should not contain detailed user-specific automations.

## How to use

Before replying to an inbound message:

1. Check whether any hook file here matches the sender/channel/message context.
2. If a hook matches, execute its action first.
3. Then reply normally, or return `NO_REPLY` if the hook handled the message and no chat response is needed.

## Scope

These are workspace-level assistant hooks, not compiled gateway plugins. They are still picked up because `AGENTS.md` is loaded into the agent context and instructs the assistant to consult this registry.

If a workflow needs to run without relying on the assistant turn, promote it later into a real gateway/plugin hook.
