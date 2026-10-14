# Night light on a schedule

Status: done

Row: Display › Light and warmth › On a schedule `nightSched` (off, sunset, set
times).

## What to build

- `services/Display.qml`: a timer that warms the screens at the start of the
  window and clears it at the end, easing over a few minutes.
- Sunset: compute sunrise and sunset from the time zone's coordinates or a set
  location; no network needed.
- Keys: `screen.schedule` (`off` | `sunset` | `times`), `screen.warmFrom`,
  `screen.warmTo`.

## Built

`services/Display.qml` has a timer (every 20 s while a schedule is on) that
asks `services/nightlight.js` for the window and how far into it we are. It
warms the screens at the start and clears them at the end, easing over
`screen.easeMinutes` (5): in from the start, out so that it is clear by the
end. Keys: `screen.schedule` (`off` | `sunset` | `times`), `screen.warmFrom`,
`screen.warmTo`, `screen.easeMinutes`.

- Sunset mode works out sunrise and sunset offline (the standard sunrise
  equation) from the coordinates of the zone in use, found in
  `/usr/share/zoneinfo/zone.tab` and `zone1970.tab`, or from the position
  geoclue gave when zone from network was turned on, while that zone is still
  the one in use. Polar night keeps the window open, the midnight sun never
  opens it.
- Moving the warmth by hand (slider, toggle, CLI) holds the schedule until the
  next edge of the window.
- The eased steps never overwrite the remembered warm strength, so the next
  night starts from what the person chose, not from a half-eased value.
- The scheduler only acts on a change: outside a window it leaves a manual
  warmth alone. It cannot clear a warmth it did not set after a restart that
  skipped the end of a window.
- Decision: the panel had no way to set "set times", so two slider rows (Warm
  from, Warm until, quarter-hour steps) sit under the schedule row and are
  disabled unless it is on set times. They are not in the mockup; drop them if
  that matters more than being able to set the times.

Still to check by a person: the whole easing against the real bs-gamma over a
sunset (nothing here ever applied warmth), and that suspend and resume lands
the screens right at the next 20 s tick.
