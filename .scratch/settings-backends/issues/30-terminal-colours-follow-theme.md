# Terminal colours that follow the theme

Status: ready-for-agent

Row: Apps › Terminal › Colours `termColours` (one dark, theme). Picking "theme"
writes a palette made from the current theme into `files.terminal.palette`
once. Change the theme afterwards and the terminal keeps the old colours while
the row still says "theme".

## What to build

- Let `files.terminal.palette` hold the string `"theme"` as well as a list of
  sixteen colours, and have `Appearance.colour.terminalPalette` build the list
  from the live theme when it is `"theme"`.
- `SettingsState.transforms.termColours` then writes `"theme"` and reads it
  back directly.
