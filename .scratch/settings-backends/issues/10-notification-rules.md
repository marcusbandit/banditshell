# Notification rules per app

Status: needs-triage

Row: Sound › Notifications › By app `rules` (pop, sound, lock screen per app).
The list is kept in the panel's planned state.

## What to build

- `services/Notifications.qml`: look up the sending app's rule; no popup when
  `pop` is off; no sound when `snd` is off; hide the body on the lock screen when
  `lock` is off.
- Key `notifications.rules`: an object keyed by app id, opaque to the schema
  merge (add it to `Config.opaque`).
