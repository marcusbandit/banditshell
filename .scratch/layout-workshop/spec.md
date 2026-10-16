# Layout Workshop

Status: core built on branch layout-workshop (2026-10-16)

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

## Answers

Checked on Hyprland 0.56.2 (Lua 5.5) on 2026-10-16, without touching
`general.layout` or any Hyprland file.

- **Loading works without editing Hyprland files.** `hyprctl eval
  'dofile("<path>")'` runs a file the shell owns in Hyprland's own Lua state,
  and `hl.layout.register` inside it makes `lua:<name>` available at once.
  Probes registered `lua:bs_workshop_probe`, `lua:bs-workshop-check` and
  `lua:bs-workshop-check2`, none applied to a workspace; they disappear on the
  next reload. `dofile`, `io` and `os` are all present in that state.
- **A name registers once per Lua state.** A second `hl.layout.register` with
  the same name does not raise; it records a config error ("layout
  'lua:x' is already registered") that `hyprctl eval` prints and
  `hyprctl configerrors` lists until the next successful eval. So `pcall`
  cannot guard it. The generated file keeps
  `banditshell_workshop.registered[name]` and registers a thin forwarder only
  once; loading the file again swaps the implementation behind the forwarder,
  so "Use now" after an edit takes effect without a reload.
- **After a reload, load again.** `ConfigManager.hpp` has `reinitLuaState()`
  and `clearLuaLayoutProviders()`: a reload starts a fresh Lua state with no
  Lua layouts. `services/WorkshopLayouts.qml` loads every saved layout when
  the shell starts and again on every `configreloaded` event (first clearing
  the registered table, in case a state ever survives), the same way launcher
  hotkeys are bound again.
- **Reading values back.** `hyprctl eval` prints only `ok` or `error: ...`, so
  a probe reads a value with `error(tostring(x), 0)`. `hl.layout` has only
  `register`; there is no list of registered layouts and no unregister.
- **One source of truth.** The geometry engine is written twice, once in JS
  (`modules/workshop/layout-model.js`, which draws the preview) and once in Lua
  (embedded by `modules/workshop/layout-lua.js` in every generated file), line
  for line. `tests/layout-workshop.test.js` runs the generated Lua under the
  system `lua` with a mock `hl` and checks it against the JS for every starter
  and 40 random layouts, with messages, and checks the stage model against
  the hand-written `stage.lua` (copied to `tests/fixtures/stage.lua`) for 1 to
  8 windows on 5120x1440, 1200x1920 and four other areas.
- **Round-tripping.** The Workshop edits only what it made. Stage ships as a
  starter drawn in the model instead of being parsed from Lua.
- **Where it lives.** Models are kept in
  `~/.local/state/banditshell/layouts.json`; the generated Lua goes to
  `~/.local/state/banditshell/layouts/<name>.lua` and is written again from
  the models on every load, so a shell update that changes the engine reaches
  saved layouts by itself. Settings, Desktop, Windows: the "Custom layout"
  row lists saved layouts (Use, Edit, remove) and "Draw one" opens the
  Workshop inline, with the canvas in the side pane (a `workshop` pin) so it
  stays in view while the inspector scrolls. Typing "layout workshop" in the
  launcher opens it too. `WindowLayouts.available` lists every saved layout
  that loaded, so the launcher's layout rows offer them.

### The model as built

- Regions nest: a `split` (row or column) holds children; leaves are `slot`
  (one window), `stack` (many, along its axis, with per-window weights) or
  `space` (holds nothing).
- Sizes along a split: `aspect` (width:height against the cross size, capped
  at what is left), `fraction` of the split, `pixels`, then `share` of the
  rest. The last share takes the rounding remainder; with no share, the last
  region takes what is left. A region marked collapse gives its space back
  when it holds no window.
- Fill order: `first` (one entry per window) then `repeat` (cycled). A full
  slot is skipped; when everything in the pattern is full, the window joins
  the region the pattern points at.
- Arrangements: the first one whose conditions hold (fewest and most windows,
  narrowest and widest area) and whose every slot and stack is at least `fit`
  px is used; the last is the default. Stage is a main arrangement plus a
  one-stack fallback that takes over when the side columns would be 0 px.
- Messages: `taller`/`shorter` change the focused window's weight in a column
  stack, else the share or fraction of the nearest region in a column split;
  `wider`/`narrower` the same along rows; `promote` swaps the focused window
  with the first one, the same `hl.dsp.window.swap` stage's `put_on_stage`
  dispatches, deferred with `hl.timer` so it does not run inside the layout
  callback; `reset` clears weights and shares. Unknown messages
  are ignored, never refused, so no config error banner appears.
- Known difference from stage.lua: in the one-stack fallback the first window
  can grow with `taller`; stage.lua holds the stage window at weight 1 even
  there.

### Not done yet

- Binds for the messages are copied (Copy binds), not bound live. Binding them
  through `hyprctl eval` like launcher hotkeys would work, but
  `apply_layout_binds` in the user's binds.lua unbinds by chord on every
  layout switch, so the two would need agreeing first.
- Dragging region edges on the canvas; sizes are set in the inspector.
- Per-workspace layouts (workspace rules take a `layout`); "Use now" sets
  `general.layout` like every other layout row.
- Not tested live with a Workshop layout applied: the probes only registered
  layouts. Checked offscreen and against a mock `hl` in Lua 5.5.
- Opening the Workshop on an existing layout in the first moment after the
  shell starts, before `layouts.json` is read, opens a fresh stage instead.

- Checked live on 2026-10-16 by the orchestrator: the Stage starter, loaded
  with `dofile` and put on a scratch workspace through a runtime
  `hl.workspace_rule`, placed four windows exactly like `stage.lua` and
  answered taller the same way. After promote the two differ: the Workshop
  layout keeps weights with the window, stage keeps them with the slot.
- `hyprctl -j workspaces` reports `tiledLayout: lua:stage` for every Lua
  layout, including ones that are clearly running. Judge a Lua layout by
  window geometry, never by that field.
