# Do not disturb, and what modes do with it

Status: done

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

## Built

Quiet lives in `services/Notifications.qml`. A notification always lands in
history; when quiet holds it gets no popup and no sound. Alarms from the clock
(sent with the category `x-banditshell.alarm`) pass when `notifications.letAlarms`
is on. The date maths is in `services/quiet-hours.js`, tested in
`tests/quiet-hours.test.js`.

- Keys: `notifications.quiet`, `quietUntil` (timestamp, 0 is off by hand),
  `letAlarms`, `nightly`, `nightFrom`, `nightTo`. The panel rows are `dnd`,
  `dndUntil`, `dndAlarms`, `dndNightly`, all config backed. `dndUntil` shows the
  choice that made the deadline by reading the time of day back (18:00, the
  wake time, or else an hour); the row detail shows the real time.
- Ends computes its deadline when chosen. A timer checks once a second while a
  deadline is set and turns quiet off and the deadline to 0 when it passes.
  Turning quiet off clears the deadline. Choosing Ends while quiet is off keeps
  the deadline for when it is switched on; a deadline already past is dropped
  at that moment.
- "tomorrow" means tomorrow at `nightTo` (07:30). That was my call.
- Every night holds quiet from `nightFrom` to `nightTo`, across midnight. It is
  separate from the switch: the switch stays off, the row detail says
  "quiet until 07:30 · every night". The two times have keys but no panel row
  (the mockup has none); the detail and the Focus suggestion read them live.
- Modes: `services/Modes.qml` holds the current mode, its glyph and the restore
  record in `$XDG_STATE_HOME/banditshell/modes.json`. Choosing a mode restores
  the last one's record, then applies every key in `set` through
  `SettingsState.set`, recording only keys that actually changed, so leaving a
  mode puts back exactly that. `SettingsState.v("mode")`, `setMode()` and
  `modeIcon` still work (forwards). An old `planned.mode`/`modeWas` is adopted
  once and dropped from the panel's file.
- IPC and CLI: `mode` (list, choose, status) and `quiet` (on, off, toggle,
  status) in `modules/Cli.qml`, reached as `banditshell focus`, `focus mode
  [none|work|play|stream|sleep|list]`, `focus quiet [on|off|toggle]
  [hour|evening|tomorrow|never]`.
- `profile` goes through `SettingsState.set("profile", ...)`; it is still the
  planned value until its own ticket lands.

To check by a person: the `sleep` and `stream` modes drive warmth, brightness
and the streamer band for real now, and were not run here (they touch the
display). The sidebar glyph still reads `SettingsState.modeIcon`, which now
forwards to `Modes.icon`. Low-battery warnings are notifications too, so quiet
silences them; say if they should always get through.
