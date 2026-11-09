# A plugin can notify at any time, and has a folder of its own

Status: ready-for-agent
GitHub: #809

Every message but `results` and `update` is dropped unless it answers
something the person did in the last 10 seconds (`PluginHost.qml`). That is
right for pages and fills, which would jump under the person's hands, but a
notification breaks nothing. A plugin also has no agreed place to keep state.

Use case: Voice tells you a rule was added from the island, and keeps the
last thing it paused between runs.

Done when: a `notify` effect is shown at any time, at most one per plugin
every few seconds, while pages, fills and the other effects keep the gate;
and the program gets `BANDITSHELL_PLUGIN_DATA`, a folder made for it under
the shell's state folder, documented in `docs/plugins/README.md`.
