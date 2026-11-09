# A plugin can own a live item in the bar or island

Status: resolved
PR: #815
GitHub: #805

A plugin cannot put anything outside the launcher. The island takes live
items only over IPC (`modules/island/ActivityIpc.qml`), so a plugin would have
to shell out to `qs ipc call` like any outside script, and the sidebar IPC
only switches it on and off.

Use case: Voice wants a mic that turns red while you dictate and lists what
it paused ("Spotify dimmed, Zen paused"). Clicking it would open the plugin's
rows.

Done when: a manifest can declare a status item, the plugin updates its icon,
text and tone with a protocol message at any time, a click runs an action or
opens the plugin's rows, and the program is started for it without a query.
