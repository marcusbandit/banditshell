# VIA boards: light the bound keys

Status: needs-triage

Rows: Input › Keyboard › Board (from file), and the keyboard preview. An
imported VIA definition labels keys by matrix position, so the preview cannot
light the keys the shell binds.

## What to build

- Read the board's keymap (VIA's saved keymap .json, or over raw HID) to map
  matrix positions to keycodes, then light keys the way the built-in boards do.
