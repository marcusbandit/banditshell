# Hotkey sheet board shapes

Status: done

Row: Input › Keyboard › Board `sheetKeyboard` (ansi, iso, split, from file).
"From file" works today (it is `Keyboards.use`, stored in
`cheatsheet.keyboard`). The three built-in shapes are planned: the sheet always
draws iso. The panel keeps the choice as `sheetShape`.

## What to build

- Key `cheatsheet.shape`: `ansi` | `iso` | `split` (default `iso`).
- `services/Keyboards.qml`: `template` from
  `KeyboardsJs.templateSections(shape)`; `keyboards.js` already has ansi and
  iso. Split needs a variant with the gap down the middle, matching
  `modules/settings/boards.js` `BOARDS.split`.
- Picking a shape clears an imported file; importing a file wins over the shape.

## Done when

The sheet (Super + /) draws the shape picked in the panel.

## Built

- `cheatsheet.shape` (`ansi` | `iso` | `split`, default `iso`) in
  `config/Config.qml`. `Keyboards.shape` reads it (an unknown value reads as
  iso) and `Keyboards.template` is `KeyboardsJs.templateSections(shape)`.
- `keyboards.js` draws `split` as the ansi rows with a one-unit gap after the
  sixth key of each row (the seventh on the number row) and the space bar in
  two halves, as `BOARDS.split` does. The arrow cluster is kept, so the keys
  the shell binds still have somewhere to light.
- `SettingsState`: `sheetShape` left `planDefaults` for `configBacked`
  (`cheatsheet.shape`); the `sheetKeyboard` read and write use it. Picking a
  shape clears an imported file; importing a file still wins over the shape.
  The panel preview and the "nothing imported" line follow `Keyboards.shape`.
- The row never carried `isNew`, so catalogue.js only gained a line in the
  Board row's why about shape and file.
- To check by eye: Super + / on the live shell with each shape picked. The
  split sheet was only rendered headless (shaders off, nothing lit).
