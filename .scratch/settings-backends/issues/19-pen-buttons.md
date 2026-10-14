# Pen buttons

Status: done

Rows: Input › Pen › Lower button `penBtn1`, Upper button `penBtn2` (right
click, middle click, erase, nothing).

## What to build

- Map the stylus buttons in Hyprland's tablet device config or through the
  pen-pad helper (`scripts/pen-pad.py`), keyed by `pen.device`.
- Keys `pen.lowerButton`, `pen.upperButton`.

## Built

Keys `pen.lowerButton` and `pen.upperButton` live in `config/Config.qml`, back
the rows (`configBacked`, `cfg` on the rows) and carry over a planned value
once. They are keyed by `pen.device`.

What does the remapping: a new helper, `scripts/pen-buttons.py`, run by
`services/PenButtons.qml`. The existing pen helper cannot: `pen-pad.py` reads
the pad node, not the pen, so it never sees the stylus buttons. Hyprland's own
tablet config cannot either: `input:tablettool:eraser_button_mode` and
`eraser_button_override` only choose which button a Pro Pen 3 treats as its
eraser button; nothing there turns a side button into a right or middle click
or into nothing. So the helper grabs the pen, hands every event through a
uinput stand-in with the same name (so the `hl.device` region mapping still
matches), and changes only the two side buttons: right click is BTN_STYLUS,
middle click is BTN_STYLUS2, nothing drops it, and erase reports the eraser
tool for as long as the button is held. The mapping logic is a pure class with
tests in `tests/pen-buttons.test.js`.

Decision: the defaults are right click and middle click, what the stylus sends
as it comes, not the mockup's stand-in "erase" for the upper button. On the
defaults the helper never starts and nothing is grabbed. Only a changed button
makes the shell sit between the pen and Hyprland. The rows say which state
they are in ("as the pen sends them", "remapped", "pen not found", "can't
reach the pen").

Not verified on hardware (grabbing a device was off limits while building):

- That Hyprland and clients treat the stand-in exactly like the real pen
  (proximity, pressure, region mapping, the tool swap for erase).
- That the lower button really is BTN_STYLUS on the Pro Pen 2.
- It needs write access to `/dev/uinput` (this machine has it by ACL) and the
  `input` group.
- If the pen misbehaves, set both buttons back to their defaults: the helper
  stops and the pen is released.
