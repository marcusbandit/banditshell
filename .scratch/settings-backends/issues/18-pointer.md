# Pointer: speed, natural scroll, tap to click

Status: done

Rows: Input › Pointer › Mouse speed `mouseSpeed`, Touchpad speed `padSpeed`,
Natural scrolling `naturalScroll`, Tap to click `tapClick`.

## What to build

- Write `input:sensitivity`, `input:touchpad:...` (`natural_scroll`,
  `tap-to-click`) and a per-device sensitivity for touchpads through the shell's
  Hyprland include, applied live with `hyprctl keyword`.
- Read the current values back on open (`CompositorSync` already reads natural
  scroll).
- The pointer preview should take the pad's real shape from libinput.

## Built

Mouse speed is `input:sensitivity`, Natural scrolling is
`input:touchpad:natural_scroll`, Tap to click is `input:touchpad:tap-to-click`
(written as `tap_to_click`, the Lua spelling; Hyprland rejected the dashed
one). All four rows lost `isNew`, and `mouseSpeed`, `padSpeed`, `naturalScroll`
and `tapClick` left `planDefaults`; they are read back from Hyprland on open
and after a reload, and written through the option writer (see 16), debounced
and queued like the keyboard rows. The row is the touchpad's natural scroll;
the mouse's own `input:natural_scroll` has no row.

Touchpad speed is a per-device `sensitivity` in an `hl.device` block, written
to every touchpad. `scripts/pointing-devices.py` lists pointing devices and
their pad size straight from `/run/udev/data` (no root; tested on a fixture
tree), and the shell keeps the ones Hyprland also lists in
`hyprctl -j devices`. With no touchpad the row is disabled and says so. The
value shown is the device block's, else the global one.

The pointer preview takes the pad's shape from udev's `ID_INPUT_WIDTH_MM` and
`ID_INPUT_HEIGHT_MM`, clamped to 1:1 to 2.2:1; without a touchpad it stays
3:2.

Still to check by a person: this desktop's only "touchpad" is the Wacom's
finger surface (224 x 148 mm), so a laptop with a real touchpad is the
better test of the per-device block and the shape.
