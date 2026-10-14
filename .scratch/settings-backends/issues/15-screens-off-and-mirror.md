# Screens: turn off and mirror

Status: ready-for-human

Rows: Display › Screens › Use this screen `scr:on`, Mirror `scr:mirror`. Kept
per screen in the panel's planned state.

## What to build

- `services/Monitors.qml` and `HyprConfig`: write `disabled` and `mirror` into
  the shell's monitor entry (behind `sourceEdits`), the way mode, scale and
  position are written today.
- Refuse turning off the last screen that is on (the row already says so).
- The arrangement in the pane hatches screens that are off.

Needs a person at a desk with more than one screen to verify.
