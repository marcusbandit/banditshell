# Terminal colours that follow the theme

Status: done

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

## Built

`files.terminal.palette` can hold the string `"theme"` as well as a list. The
config merge and `Config.set` only allow a string where a list is expected for
keys named in the new `Config.literals`; the default stays the one dark list.
`Appearance.colour.themePalette` builds the sixteen colours from the live theme
(the formula that lived in `SettingsState.themePalette()`), and
`Appearance.colour.terminalPalette` returns it for `"theme"`. `Files.qml` was the
only consumer and already read through Appearance; it now also repaints an open
terminal when the palette changes. The `termColours` transform writes `"theme"`
and reads it back; a hand-edited list that is not one dark shows as a third
"custom" segment.

A palette picked as "theme" before this change was stored as a list, so it now
shows as "custom" until "theme" is picked again. To check by hand: switch theme
with Files' terminal open and see the colours follow.
