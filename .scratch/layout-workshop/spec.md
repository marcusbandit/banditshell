# Layout Workshop

Status: needs-triage

A place in the shell to make a Hyprland tiling layout by drawing it: the user
arranges regions on a canvas, sees windows fill them live, and the shell writes
the Lua layout behind it. The result is a real `hl.layout.register` layout, the
same kind as the hand-written stage (`~/.config/hypr/lua/stage.lua`), so it
behaves like any other layout once it is loaded.

Todo, not started. Asked for on 2026-10-16, after the launcher learned to switch
layouts (`services/WindowLayouts.qml`, PR #19).

## What a Lua layout is

The contract stage.lua uses, which the Workshop has to generate:

- `hl.layout.register(name, { recalculate = fn, layout_msg = fn })` makes
  `lua:<name>` a layout for `general.layout`.
- `recalculate(ctx)` gets `ctx.area` (x, y, w, h: the usable area of the
  workspace) and `ctx.targets` (the tiled windows in order). It places every
  target with `target:place({ x, y, w, h })`. Nothing is placed by default.
- `layout_msg(ctx, msg)` receives `hl.dsp.layout("<msg>")` calls. A layout can
  keep its own state between passes (stage keeps per-window height weights and
  the stage window per workspace).
- Hyprland hands a Lua layout no resize deltas: a mouse drag on a tiled window
  only re-runs `recalculate`. Sizes a user can change have to come from layout
  messages bound to keys.

## What stage needs, as the yardstick

If the Workshop can express stage without hand-written Lua, the model is big
enough:

- a main region held to an aspect ratio (16:9 at full height), centred;
- the remaining width split into side columns;
- extra windows dealt into the columns in an order that alternates (right,
  then left), each column stacking top to bottom;
- per-window weights inside a column, changed by `taller` and `shorter`
  messages and clamped (0.25 to 4);
- a fallback when there is no room for the columns (a monitor no wider than
  16:9: one stack);
- the last window in a stack takes the remainder, so rounding never leaves a
  seam.

## A model to start from

- **Regions** drawn on a canvas, each sized by a rule: a share of the free
  space, a fixed aspect ratio, or the remainder. Regions nest in rows and
  columns.
- **Kinds**: a slot holds one window; a stack holds many, split along one axis
  with weights.
- **Order**: which region window N lands in, written as a fill order with a
  repeat pattern (for stage: main, then right, left, right, left...).
- **Fallbacks**: a second arrangement used below a width, or below a window
  count.
- **Messages**: a small set the generated Lua answers, such as taller,
  shorter, wider, narrower and promote. The Workshop shows the Hyprland binds
  to add next to them.
- **Preview** with a window count slider and the real monitor shapes,
  including the rotated one, drawn with the same math the Lua uses.

## Open questions

- Loading without editing Hyprland files. The user keeps "Edit Hyprland files"
  off, so the shell cannot add a `require` line. Can a layout be registered
  live with `hyprctl eval` (for example `dofile` on a file the shell owns, in
  `~/.local/state/banditshell/layouts/`) and registered again after every
  reload, the way launcher hotkeys are? Check this before anything else.
- One source of truth. The geometry should come from one place, so the preview
  and the Lua cannot drift: either generate the Lua from the model and also run
  the model in QML, or run the same Lua in both.
- Round-tripping. Can a hand-written layout like stage be opened in the
  Workshop, or does the Workshop only edit what it made? Starting with "only
  its own" keeps the generator simple.
- Where it lives. Settings already has a "Custom layout" row on the layouts
  page that says custom layouts are still being worked out. The Workshop is
  what that row should open. The launcher's layout rows
  (`WindowLayouts.available`) should list Workshop layouts too.
