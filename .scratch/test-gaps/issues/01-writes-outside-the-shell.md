# Tests for everything that writes the user's files and config

Status: ready-for-agent
Tier: 1

A bad write here survives a restart: a broken Hyprland config, a moved or
deleted file, an autostart entry that launches twice. Each item below names the
decisions to move into a `.js` sibling and what the tests pin down.

## services/HyprConfig.qml

- Extract the write sequence (`write`, `verified`, `rechecked`) as a reducer:
  state and the text read back in, next step out. Test that a changed file
  between read and write aborts, that a half-applied edit is rolled back, and
  that a trial reload that fails restores the previous text.
- `shortName` and `pathOf` move to `services/hyprland-lua.js` with the
  Hyprland folder as an argument. Test files inside it, under `lua/`, and
  sourced from outside it (#110).
- `addMonitor` and `trialScript` build strings; test quoting with spaces and
  quotes in names.

## services/Files.qml

- Typed paths already go through the tested `quoting.js`. What is not tested
  is the choice between typing into the live shell and spawning
  (`run`, `typed`, `refusal`), and the move, delete, rename and new-file
  commands. Extract the command builders and test that a path that cannot be
  typed falls back to a spawn, never to a half-quoted line.
- `humanSize` moves as it is; test the unit edges (1023, 1024, 1048575).

## services/StartupApps.qml

`change`, `switchApp`, `addApp` and `queueWrite` decide which autostart file
is written, overwritten or removed. Test that turning an app off removes only
the file the shell wrote, and that `launchSession` starts each app once.

## services/WorkshopLayouts.qml

`save`, `remove` and `settle`: test the file name a layout gets, that removing
one never touches another, and that a Lua load error is not marked ready.

## services/Monitors.qml

`specFor` and `write`: test that the mode, position and scale written are the
ones picked, including fractional scales and a disabled monitor.

## services/Wallpaper.qml

`expand`, `kindOf`, `fits` and `reconcile`: test that a moved or deleted
wallpaper folder falls back to the shipped picture instead of a blank path,
and that `reconcile` never rewrites a key it did not change.
