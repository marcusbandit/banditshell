# Plugin API gaps, measured against Raycast

Status: ready-for-agent

Asked 2026-11-09 while building the Voice launcher plugin
(`~/Projects/voice/banditshell-plugin`): what would the ideal version of that
plugin look like in Raycast, and what does banditshell's plugin API lack to
build it here. The four gaps below are the ones that plugin runs into. Each is
one ticket in `issues/`.

The Voice plugin controls what happens to playing sound while you dictate:
pause, dim or keep, globally and per app. Its rows are QML with a segmented
control and a level slider, changed in place with Left and Right, which
Raycast cannot do. What it cannot do here:

1. Show a mic in the bar or island that turns red while you dictate and lists
   what it paused (Raycast: menu bar extra).
2. Give actions their own chords, such as Ctrl+D to dim (Raycast: an action's
   `shortcut`).
3. Take a value inline from plain search, such as `dim spotify 15` (Raycast:
   command `arguments`).
4. Know whether the launcher is open, so live updates stop when it closes. It
   guesses with a 60 second window after each query today.

Smaller gaps found in the same pass, not ticketed: no refresh while the
launcher is closed, popups only right after a user action
(`PluginHost.qml` gate, 10 s), no dropdown beside a list page's filter, facts
only on a full detail page, `launcher run <id>` only for rows in the last
answer, no plugin-declared hotkeys, no storage API.

## Triage, 2026-11-09

The owner's ask: the Voice plugin is "not great... not utilizing" the API;
close what banditshell lacks to build a well-made Raycast extension here.
Calls the owner made:

- Status items go in both the sidebar rail and the island, and the plugin
  picks one per item.
- Arguments are real boxes after the command word, Raycast style, not hints.
- All four smaller gaps are in this round. Storage is a private data folder,
  not an API: a plugin is a program and can write files.

Order, each one PR, smallest first so the Voice plugin can drop its
workarounds as they land:

1. `04` open and close, with refresh while closed through a manifest
   `background` flag: the program keeps running and times its own refresh,
   so the shell needs no `interval`
2. `02` action shortcuts
3. `01` status items in the rail and the island; the program stays running
   for them
4. `05` notify at any time, and the data folder
5. `06` facts in the side preview
6. `07` hotkeys and deep links for rows that are not on screen
7. `08` a dropdown beside a list page's filter
8. `03` inline arguments, last because it is the largest change to the
   search field
