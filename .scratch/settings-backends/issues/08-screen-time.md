# Screen time: per-app counting, grey at the cap, breaks

Status: needs-triage

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
