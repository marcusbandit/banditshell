# Pointer: speed, natural scroll, tap to click

Status: ready-for-agent

Rows: Input › Pointer › Mouse speed `mouseSpeed`, Touchpad speed `padSpeed`,
Natural scrolling `naturalScroll`, Tap to click `tapClick`.

## What to build

- Write `input:sensitivity`, `input:touchpad:...` (`natural_scroll`,
  `tap-to-click`) and a per-device sensitivity for touchpads through the shell's
  Hyprland include, applied live with `hyprctl keyword`.
- Read the current values back on open (`CompositorSync` already reads natural
  scroll).
- The pointer preview should take the pad's real shape from libinput.
