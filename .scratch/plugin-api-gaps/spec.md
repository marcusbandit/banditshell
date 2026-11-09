# Plugin API gaps, measured against Raycast

Status: needs-triage

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
