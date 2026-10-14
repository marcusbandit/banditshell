# Hotkey sheet board shapes

Status: ready-for-agent

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
