# User note — example-user (DUMMY)

<!-- Per-user structured note. Real deployments key these files by the chat platform's user ID, e.g. memory/users/<USER_ID>.md, plus sibling files like <USER_ID>.weekly_schedule.json. This sample uses the name "example-user" for portability. Files under memory/users/ are treated as a data contract: hooks and scripts read/write them, so memory-maintenance must NOT rewrite them. -->

## Who

- **Name:** `<USER_NAME>`
- **Calls the agent:** by name
- **Timezone:** `<TZ>`

## Preferences

- Wants concise answers, no filler.
- Prefers concrete steps over vague advice.

## Constraints / habits

- Usually free for a sync 09:00–10:00 on weekdays. (Recurring habit layer — merge explicitly with one-off calendar events, don't rely on the calendar alone.)

## Related structured files (examples)

- `memory/users/example-user.weekly_schedule.json` — weekly plan / weekday reminders (separate layer from the calendar).
