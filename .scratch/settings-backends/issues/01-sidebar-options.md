# Sidebar options

Status: ready-for-agent

Rows (Desktop › Sidebar): Clock `sbClock`, Date `sbDate`, Sound `sbSound`,
Network `sbNet`, Bluetooth `sbBt`, Battery `sbBatt`, Tray `tray`, Special
workspaces `specialsShown`. Modes (ticket 09) also want their glyph here.

Update button `sbUpdate` is done: it shipped with the update loop as
`sidebar.update` (`always` | `new` | `never`, default `new`).

Proposed keys, from the mockup:

- `sidebar.clock.style`: `stacked` | `small` | `one line` | `off` (default `stacked`)
- `sidebar.clock.date`: `day and month` | `day` | `off` (default `day and month`)
- `sidebar.status.sound|network|bluetooth|battery`: bool (default true)
- `sidebar.tray.enabled`: bool (default true). The mockup row has no key; this
  name sits next to `sidebar.tray.max`.
- `sidebar.workspaces.rack`: bool (default true). The mockup names
  `sidebar.workspaces.specials`, but that key already holds the list of pinned
  special workspaces, so the switch needs its own name.

## What to build

- `modules/sidebar/SidebarClock.qml`: stacked is today's look; small is the
  same at `font.size.small`; one line is one `StyledText` "HH:mm" at the small
  size with `rotation: -90` inside an Item whose height is the text's width;
  off hides the time. The date shows "14\nOCT", "14", or nothing, and still
  opens the calendar on tap or pull. The spacer between time and date only
  shows when both do.
- `modules/sidebar/StatusIcons.qml`: filter `gauges` by the four keys; battery
  still needs `Battery.available`.
- `modules/sidebar/TrayIcons.qml`: `shown` is empty when the tray is off.
- `modules/sidebar/WorkspacePlates.qml`: `deck` is empty when the rack is off.
- Mode glyph: an accent, filled icon above the status icons while a mode other
  than none is on. The mode lives in the settings module today
  (`SettingsState.modeIcon`); pass it in from `ShellWindow` as a property so the
  sidebar does not import the settings module.

The panel's sidebar preview (`modules/settings/SidebarReplica.qml`) already
draws all of these, so it is the reference for the look.

## Done when

Each row changes the real sidebar live, and the replica and the real sidebar
agree.
