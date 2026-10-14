# Launcher: forget what it learned

Status: ready-for-agent

Row: Desktop › Launcher › Habit fades over, its "forget what it learned" tool.
It shows a not-built toast today.

## What to build

- `services/Apps.qml`: `forgetHabits()` empties `usage` and writes it to
  `frecency.json`.
- `SettingsActions.qml` `forgetHabit`: call it, then drop "launcher forgot what
  you use · a to z again".

## Done when

After the button, the launcher's ranking is alphabetical until apps are used
again.
