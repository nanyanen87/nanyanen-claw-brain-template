# Inbound hook: activity log (DUMMY example)

Purpose: Convert casual inbound reports into a structured local log before any chat reply. This is a generic example of the hook pattern — replace with your own.

## Trigger

Apply this hook when all of the following match:

- Channel/surface: inbound chat message
- Sender: `<USER_ID>` (`<USER_NAME>`)
- Message reports a completed or current real event of the kind you want logged (e.g. an activity, a status update, a measurement).

Do not trigger for purely hypothetical planning unless the user says they actually did it.

## Action

Before replying:

1. Read the log schema doc (e.g. `memory/users/<USER_ID>.activity-log.README.md`) if the schema is not already clear.
2. Append one JSON object per actual event to the log file (e.g. `memory/users/<USER_ID>.activity-log.jsonl`).
3. Do **not** write report/summary rows. Reports are generated views, not log entries.
4. If the user gives a bundled summary, split it into multiple rows with the same `date`.
5. Preserve meaningful wording in the fields.
6. Verify the append (e.g. `tail` the file) before claiming it was recorded.

If no conversational reply is needed in a group chat, still perform the log write, then final-answer `NO_REPLY`.

## Related state (examples)

- User notes: `memory/users/<USER_ID>.md`
- Log schema: `memory/users/<USER_ID>.activity-log.README.md`
- Log file: `memory/users/<USER_ID>.activity-log.jsonl`
