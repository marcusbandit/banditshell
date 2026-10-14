# Alert sounds

Status: done

Rows: Sound › Alerts and media › Alert sounds `alerts`, Sound set `alertSet`
(soft, clear, wood), Alert volume `alertVol`.

## What to build

- A small player (pw-play or QtMultimedia) in a new service, with three sound
  sets shipped in the repo.
- Hooks: a notification arriving (respecting do not disturb and per-app rules),
  low battery, and errors the shell reports.
- Keys: `sound.alerts`, `sound.alertSet`, `sound.alertVolume`.

## To decide

The sounds themselves.

## Built

`services/AlertSounds.qml` plays `assets/sounds/<set>/<kind>.wav` with
`pw-play --volume`. Kinds: notification, battery, error. Sets: soft (sine
pairs), clear (bell partials), wood (marimba-like knocks). They are made by
`scripts/alert-sounds.py` (stdlib only, deterministic): mono 16-bit 44.1 kHz,
0.4 to 0.55 s, equal loudness, faded at both ends. `tests/alert-sounds.test.js`
reads the files back (format, length under 0.6 s, level, silent edges).

- Keys: `sound.alerts`, `sound.alertSet`, `sound.alertVolume` (rows `alerts`,
  `alertSet`, `alertVol`).
- Hooks: every notification that is allowed a sound (quiet and the app's `snd`
  rule respected) plays by its category, so the low-battery warning
  (`services/Battery.qml`, category battery) and failed alarm commands
  (`services/Clock.qml`, category error) play their own sound instead of the
  plain one. Launch giving up (`services/Launching.qml`) and error toasts in the
  panel (`SettingsView.drop` with the error icon) go through
  `Notifications.alert("error")`, which stays silent while quiet holds.
- Picking a set or moving the volume plays the notification sound once,
  debounced 300 ms, from `SettingsState.set`.
- Plays within 250 ms of each other are dropped.

Not verified by ear, and nothing was played on this machine: the sounds were
checked by reading the files back (lengths, levels, dominant pitch). `pw-play`
was replaced by a logging stub when running the service. A person should listen
to the three sets and judge them.
