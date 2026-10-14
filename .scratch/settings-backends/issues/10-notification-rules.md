# Notification rules per app

Status: done

Row: Sound › Notifications › By app `rules` (pop, sound, lock screen per app).
The list is kept in the panel's planned state.

## What to build

- `services/Notifications.qml`: look up the sending app's rule; no popup when
  `pop` is off; no sound when `snd` is off; hide the body on the lock screen when
  `lock` is off.
- Key `notifications.rules`: an object keyed by app id, opaque to the schema
  merge (add it to `Config.opaque`).

## Built

`notifications.rules` is an object keyed by app id, `{pop, snd, lock}`, in
`Config.opaque`. Lookup is `services/notification-rules.js` (tested in
`tests/notification-rules.test.js`) behind `Notifications.ruleFor(entry)`. The
key is the desktop entry the sender resolves to, else its desktop-entry hint,
else its lowercased app name (so `notify-send -a banditshell` is `banditshell`).
An app with no rule pops, sounds and keeps its body off the lock screen.

- Popup: `pop` off means the notification goes to history only.
- Sound: `snd` off means no alert sound.
- Lock screen: the lock screen showed no notifications at all, so there was
  nothing to hide. I added `modules/lock/LockNotifications.qml`: the newest
  three, and "n more" beneath. It is under the password field in `LockFace`.
  By default each shows only the app's name; the summary and body show only
  when that app's `lock` rule is on.
- `RulesWidget` reads and writes the config key. "Add" offers the apps that have
  sent a notification (from history), skipping those with a rule; a new rule
  starts as the defaults above so adding changes nothing until a switch is
  flipped. Names come from the desktop entries.
- An old planned list is converted to the keyed object once (transform on
  `rules` in `SettingsState`).

To check by a person: that the lock screen list looks right on the real lock
(only photographed offscreen here).

The lock screen list holds only notifications from apps whose `lock` rule is
on, with their summary and body; with no such rule the lock screen looks as it
did before.
