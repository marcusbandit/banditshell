# Screen time: per-app counting, grey at the cap, breaks

Status: done

Rows: Focus › Screen time › Today `usage`, Grey at the cap `greyCap`, Breaks
`breaks`, Every `breakEvery`. The daily total and the hour bars already come
from `services/Usage.qml` spans.

## What to build

- Per-app time: on each `Usage` beat, credit the elapsed time to the focused
  window's class (`Hypr.activeClient`), per day, in a new
  `state/usage-apps.json` kept for 14 days. Expose `appsFor(day)`. The Today
  widget then lists the top five apps with bars, as in the mockup.
- Grey at the cap: once today's total passes `usage.capHours`, desaturate the
  screen (Hyprland screen shader or a layer with a MultiEffect) until midnight
  or until the cap is raised.
- Breaks: a notification every N minutes of unbroken use.
- Keys: `usage.greyAtCap` (bool), `usage.breaks` (bool), `usage.breakEvery`
  (minutes, default 50).

## To decide

How the grey is drawn, and whether it should ever block input. Whether "active"
for per-app time should mean input activity rather than the shell being up.

## Built

- Per-app time: `services/UsageApps.qml` credits the elapsed time to the focused
  window's class on every `Usage` beat, on focus changes, and when `Idle` flips,
  and only while `Idle.idle` is false (no input for a minute, a playing video
  counts as present). Kept per day in `state/usage-apps.json` for 14 days, merged
  per app by the larger count when another shell instance writes the file.
  `UsageApps.appsFor(day)` returns the ranked list (it lives on this service
  rather than `Usage`, so `Usage` stays the span tracker). Pure logic in
  `services/usage-apps.js`.
- Today widget lists the top five apps with an icon (the AppMark path), a bar
  and the time, as in the mockup, with the bar beside the time rather than under
  the name.
- `services/UsageLimits.qml`, logic in `services/usage-limits.js`:
  - Grey at the cap never blocks input. Once today's total passes the cap it sets
    Hyprland's `decoration:screen_shader` at runtime (`hyprctl eval` on the Lua
    parser, `hyprctl keyword` on the old one, nothing written to config) to
    `assets/shaders/desaturate.frag`. Warmth uses `bs-gamma`, not a screen
    shader, so there was nothing to compose. It clears at midnight (the total
    drops on the next beat), when the cap is raised past today's total, when the
    switch goes off, and when the shell shuts down; a config reload re-applies
    it. It reads the slot first and never overwrites or clears a shader that is
    not its own.
  - Breaks send a notification through `notify-send -a banditshell`, the same
    path the battery and clock warnings use, after `usage.breakEvery` minutes
    without an idle stretch of 5 minutes or more, and again every period after.
    Turning breaks on does not fire at once.
- Keys `usage.greyAtCap` (false), `usage.breaks` (false), `usage.breakEvery` (50).

To check by hand: the grey shader on the real compositor (the offscreen test
cannot render shaders, and `hyprctl` was never run against the live session),
the Lua `hyprctl eval` form of the shader setting, and a real break nudge.
