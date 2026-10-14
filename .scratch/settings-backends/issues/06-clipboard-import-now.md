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
key. `Clipboard.clipseWaiting` counts the entries in clipse's history that are
not already in ours (the same duplicate test `adopt` uses, split out as
`fresh()`), so it falls to 0 after an import. `SettingsState.clipseWaiting` and
the Apps hub suggestion read it. The row's detail says "412 entries waiting";
the button reads Import while anything is waiting and Done once nothing is, so it
also works for someone whose first-start import already ran. The hub suggestion
still only appears while the key says the import has not happened. The history is
read when the shell starts and again on import; clipse's file is not watched.

To check by hand: with a real clipse history, press Import and see the entries
and pictures arrive. Tried against a fake clipse file in a throwaway root:
count 3, Import, three entries, count 0. If clipse holds more than
`clipboard.maxEntries`, the surplus is pruned on import and keeps counting as
waiting.
