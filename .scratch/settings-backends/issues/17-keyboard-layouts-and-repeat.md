# Keyboard layouts and key repeat

Status: done

Rows: Input › Keyboard › Layouts `kbLayouts` (lead, drop, add), Repeat after
`kbDelay`, Repeat rate `kbRate`. The panel reads the current layouts from
`hyprctl getoption input:kb_layout` and keeps edits in its planned state.

## What to build

- Write `input:kb_layout` (comma list, lead first), `input:repeat_delay` and
  `input:repeat_rate` through the shell's Hyprland include (behind
  `sourceEdits`), and apply live with `hyprctl keyword`.
- Bind Super + Space to switch layouts if it is free (the row says it).

## Built

`input:kb_layout`, `input:repeat_delay` and `input:repeat_rate` go through the
option writer built under ticket 16, behind `sourceEdits`, and are read back
from `hyprctl -j getoption` when the panel opens and after every config
reload. `kbDelay`, `kbRate` and `layouts` left `planDefaults`; the three rows
lost `isNew`. Sliders are debounced (a drag is one write), writes are queued
one at a time, and a failed write shows what Hyprland said and puts the old
value back on screen.

`KbLayoutsWidget` writes through `SettingsState.setLayouts`, not
`plan("layouts")`. The colemak entry in the Add pool needs a variant, so
`input:kb_variant` is written alongside, ordered so the variant list is never
longer than the layout list while Hyprland reloads in between.

Live apply: no `hyprctl keyword` (see 16); the reload applies it.

Super + Space: after a write that leaves two or more layouts, and only if no
bind already runs `switchxkblayout` and the chord is free (scanned binds and
`hyprctl -j binds` both agree), the shell adds
`hl.bind("SUPER + SPACE", hl.dsp.exec_cmd("hyprctl switchxkblayout all next"))`
to the file that already holds the binds. Hyprland's Lua dispatchers have no
layout-cycling call, so the bind goes through `hyprctl`. The row says what
switches layouts: the bind's chord, an xkb `grp:` option from `kb_options`
("right alt" here), "super + space is taken · <what holds it>", or "no key
switches layouts yet".

Still to check by a person:

- Super + Space is taken on this machine (the launcher), so the bind path was
  only exercised on a copy with the launcher bind removed.
- A real reload picks up a new `kb_layout` and key repeat without a restart.
