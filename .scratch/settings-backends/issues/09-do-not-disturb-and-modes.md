# Do not disturb, and what modes do with it

Status: needs-triage

Rows: Focus › Modes (`mode`), Do not disturb `dnd`, Ends `dndUntil`, Let
alarms through `dndAlarms`, Every night `dndNightly`. Modes already set and
restore real settings (notification popups, streamer mode, warmth, level), but
their `dnd` and `profile` parts are planned.

## What to build

- `services/Notifications.qml`: a quiet state that still collects every
  notification into history but shows no popup and plays no sound. Alarms from
  `services/Clock.qml` get through when `dndAlarms` is on.
- Ends: a deadline (in an hour, at 18:00, tomorrow, off by hand) after which
  quiet turns itself off.
- Every night: quiet from 22:00 to 07:30 (make the times keys).
- The sidebar shows the active mode's glyph (ticket 01).
- Keys: `notifications.quiet` (bool), `notifications.quietUntil`,
  `notifications.letAlarms`, `notifications.nightly`, `notifications.nightFrom`,
  `notifications.nightTo`. Modes stay in the settings state file.
- Move `mode` and the restore record out of the settings panel's state into a
  small service, so the sidebar and IPC can read and set it.
