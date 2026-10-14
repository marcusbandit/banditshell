# Clipboard: import from clipse now

Status: ready-for-agent

Row: Desktop › Clipboard › From clipse (`clipboard.importClipse`). The import
only runs when the clipboard service loads, so the button can only promise the
next start.

## What to build

- `services/Clipboard.qml`: `importFromClipse()` sets the key and reloads the
  clipse FileView; the existing `adopt` path does the rest and clears the key.
- Count the entries waiting in clipse's history so the row can say "412 entries
  waiting" and the Apps hub can suggest it (`clipseWaiting` in
  `SettingsState`).
- `SettingsActions.qml` `importClipse`: call it.

## Done when

Pressing Import brings the history over immediately and the button turns to
Done.
