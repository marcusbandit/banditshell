# Hotkeys and deep links reach plugin rows that are not on screen

Status: resolved
PR: #818
GitHub: #811

`banditshell panel launcher run plugin:<id>:<item>` and a hotkey on a plugin
row only work while that row is in the plugin's last answer. Raycast
commands have deep links and hotkeys that always work.

Use case: a hotkey that opens Voice's history or toggles a rule, pressed
with the launcher closed.

Done when: running a plugin row that is not on screen asks the program for
it and runs it, so `launcher run` and hotkeys work from cold.
