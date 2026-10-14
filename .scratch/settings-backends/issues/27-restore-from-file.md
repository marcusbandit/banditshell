# Restore settings from a file

Status: done

Row: System › Shell › Restore from a file. Export already writes
`~/Documents/banditshell-settings-<date>.json` with config and planned values.

## What to build

- Read a chosen file, diff it against the current config and planned state, and
  show what would change as a list in the pane before applying, with Apply and
  Cancel.
- Apply with `Config.setMany` and the planned store; log each change in recent
  changes so it can be put back.

## Built

The mockup draws no restore diff (its Restore button only toasts), so this one
is new. Restore opens a pin in the pane (`pins/RestorePin.qml`): a path field
using `SettingsPathEdit`, defaulting to the newest
`~/Documents/banditshell-settings-*.json`; the list of what would change; what
was skipped; Apply and Cancel. Nothing is written before Apply.

The logic is pure and tested: `modules/settings/restore.js` (`read`, `diff`,
`exportable`, `newest`, `phrase`) with `tests/restore.test.js`.
`SettingsRestore.qml` is the singleton that feeds it the live maps and applies
the result.

- Config keys are walked through the defaults, so a free-form map such as
  `launcher.hidden` and the opaque key maps compare as one value. Unknown keys,
  keys of the wrong kind and values the machine cannot take are skipped and
  listed with a reason.
- Planned keys route through the maps, not a list: a key in
  `SettingsState.configBacked` and not in `planDefaults` goes to config through
  its transform (unless the copy's own config already carries that key, which
  wins); a key in `planDefaults` goes to the planned store; a key that only has
  a row (a service owns it) is applied with `SettingsState.set`; anything else is
  skipped. `modeWas` is the panel's own bookkeeping and is ignored quietly.
- `theme` is applied through the theme switcher, not written raw, and only if
  the theme exists here.
- Config changes go in one `Config.setMany`. Each change that has a row and a
  plain value is logged with `SettingsState.log`, so it shows by name in recent
  changes and can be put back one by one. Changes with no row (raw config paths,
  lists) share one "Restored settings" entry whose undo puts them all back.
- Passwords stay out of copies both ways: export drops `hotspotPass` and
  `obs.password`; restore skips them if a hand-edited file carries them.
- A malformed file says so plainly: not JSON, not a settings copy, no config or
  planned section, a section that is not a table, no file at that path.

To check by hand: values that services read once at start (screen warmth and
level, for example) are written to config but only take effect the next time the
shell starts. Run against a throwaway root, a copy was read, applied, and its
grouped entry undone; the path field's folder button now says "type a path".
