# Window layouts

Status: needs-triage

Row: Desktop › Windows › Layout `layout` (dwindle, master, scrolling, hy3, add
custom). The layout cards and their previews are in the panel.

## What to build

- Write `general:layout` through the shell's Hyprland include (behind
  `sourceEdits`).
- Detect the hyprscrolling and hy3 plugins (`hyprctl plugin list`) and only
  offer their layouts when loaded; say how to install them otherwise.
- Custom layouts: how they plug in is undecided. The card stays an entry point
  with its info tip and Add button.
