# Clipboard: import from clipse now

Status: done

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

## Built

`Clipboard.importFromClipse()` sets `clipboard.importClipse` and reloads the
clipse FileView; the existing `adopt` path brings the history over and clears the
key, so the button turns to Done. The clipse FileView now also counts the entries
in clipse's history whether or not the key is set (`Clipboard.clipseWaiting`,
zeroed once adopted); `SettingsState.clipseWaiting` and the Apps hub suggestion
read it. The row's detail says "412 entries waiting", or "nothing waiting in
clipse" when the file is missing or empty. The count is read when the shell
starts and again on import; it does not watch clipse's file.

To check by hand: with a real clipse history, press Import and see the entries
and pictures arrive. The toast number is the file's total, not what is left after
duplicates are dropped.
