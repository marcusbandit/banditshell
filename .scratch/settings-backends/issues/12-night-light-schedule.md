# Night light on a schedule

Status: needs-triage

Row: Display › Light and warmth › On a schedule `nightSched` (off, sunset, set
times).

## What to build

- `services/Display.qml`: a timer that warms the screens at the start of the
  window and clears it at the end, easing over a few minutes.
- Sunset: compute sunrise and sunset from the time zone's coordinates or a set
  location; no network needed.
- Keys: `screen.schedule` (`off` | `sunset` | `times`), `screen.warmFrom`,
  `screen.warmTo`.
