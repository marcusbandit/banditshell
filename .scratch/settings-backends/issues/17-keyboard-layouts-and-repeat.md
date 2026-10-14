# Keyboard layouts and key repeat

Status: ready-for-agent

Rows: Input › Keyboard › Layouts `kbLayouts` (lead, drop, add), Repeat after
`kbDelay`, Repeat rate `kbRate`. The panel reads the current layouts from
`hyprctl getoption input:kb_layout` and keeps edits in its planned state.

## What to build

- Write `input:kb_layout` (comma list, lead first), `input:repeat_delay` and
  `input:repeat_rate` through the shell's Hyprland include (behind
  `sourceEdits`), and apply live with `hyprctl keyword`.
- Bind Super + Space to switch layouts if it is free (the row says it).
