# Actions can declare their own key chords

Status: resolved
PR: #814
GitHub: #806

Today Ctrl+Enter runs the first alternate action (`ListLauncher.qml`) and
Ctrl+K opens the actions sheet. An action has no `shortcut` field
(`services/plugin-protocol.js`), so every other action is two steps away.

Use case: on a Voice rule row, Ctrl+P pause, Ctrl+D dim, Ctrl+M mute,
Ctrl+Backspace remove, without opening the sheet.

Done when: an action can carry `"shortcut": "ctrl+d"`, the sheet shows it
beside the action, it runs while the row is selected, and chords the launcher
already uses are refused and logged.
