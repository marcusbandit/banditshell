# Screens: turn off and mirror

Status: done

Rows: Display › Screens › Use this screen `scr:on`, Mirror `scr:mirror`. Kept
per screen in the panel's planned state.

## What to build

- `services/Monitors.qml` and `HyprConfig`: write `disabled` and `mirror` into
  the shell's monitor entry (behind `sourceEdits`), the way mode, scale and
  position are written today.
- Refuse turning off the last screen that is on (the row already says so).
- The arrangement in the pane hatches screens that are off.

Needs a person at a desk with more than one screen to verify.

## Built

- `disabled` and `mirror` are written into the shell's own monitor entry the way
  mode, scale and position are, behind `sourceEdits`. Turning a screen on again
  drops the key, and so does ending a mirror; nothing is written as `false` or
  an empty string. A screen that is off never carries a mirror. The pure parts
  (entry fields, the last-screen guard, mirror rules) are in
  `services/monitor-rules.js`, tested in `tests/monitor-rules.test.js`.
- `Monitors` now reads `hyprctl -j monitors all`, so a screen Hyprland reports
  as disabled shows as off, and a mirror shows its source (`mirrorOf`, by name or
  id). `Monitors.applySpecs` refuses a batch that would leave no screen on or
  point a mirror at itself, an off screen, or a screen that itself mirrors.
- The panel stages both rows with the other screen changes: nothing goes out until
  Apply, and turning a screen off or mirroring counts as a change to the picture,
  so Apply asks to keep it and goes back by itself after 15 seconds. Turning off
  a screen others mirror frees them in the same stage. Off screens are hatched,
  a mirror is joined to its source by a line and says "follows" it, and neither
  takes room in the arrangement checks.
- `planned.screens` is gone. If a saved record differs from the real state it is
  staged once (not applied) when the panel state loads, then dropped.

Check at a desk with two or more screens, `sourceEdits` on:

- Turn one screen off, press Apply: it goes dark, the others stay, and the
  15 second prompt appears; press Keep, and the entry in `lua/monitors.lua` reads
  `disabled = true`. Wait out the countdown on another try: it comes back.
- The last screen's switch is disabled. Turn the others off first to see it.
- Mirror one screen to another, Apply: it shows the source. A screen that is off
  or that mirrors something else is not offered as a source.
- Unplug and replug a screen that is off, and reopen the panel: it still shows
  as off with a sensible size in the arrangement.
- Hyprland reports a disabled screen's size in some way that was not available
  to test here; the shell falls back to the config entry's mode and position.

To undo: turn the screen on (or set Mirror to nothing) and Apply, or press
Go back during the 15 seconds. By hand, delete `disabled = true` or
`mirror = "..."` from the screen's line in the shell's monitor block in
`~/.config/hypr/lua/monitors.lua` and run `hyprctl reload`. A write that fails
`Hyprland --verify-config` is put back automatically.

