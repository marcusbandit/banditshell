# Restore settings from a file

Status: ready-for-agent

Row: System › Shell › Restore from a file. Export already writes
`~/Documents/banditshell-settings-<date>.json` with config and planned values.

## What to build

- Read a chosen file, diff it against the current config and planned state, and
  show what would change as a list in the pane before applying, with Apply and
  Cancel.
- Apply with `Config.setMany` and the planned store; log each change in recent
  changes so it can be put back.
