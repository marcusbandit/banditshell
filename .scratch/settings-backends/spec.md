# Settings backends

Status: done

The settings panel (`modules/settings/`) is a port of the settings-demo mockup
(`~/.t3/projects/settings-demo`). Every setting in the mockup has a row in the
panel. Most rows write something real: a key in config.json, or a call into a
service the shell already has. The rest have nothing behind them in the shell
yet. This spec is the plan for giving each of those a backend.

All thirty tickets were built on 2026-10-14, on the `settings-backends` branch.
Each ticket's `## Built` section says what landed and what a person still has to
check. The one row still planned is the custom tiling layout (ticket 16), which
waits on a design. Carrying an old planned value into config is generic:
`SettingsState.adopt()` does it for every key that moves into `configBacked`.

## How a planned setting works today

- The row is marked `isNew` in `modules/settings/catalogue.js`. The pane says
  "new · nothing behind it in the shell yet" under it.
- Its value lives in `SettingsState.planned`, saved to
  `~/.local/state/banditshell/settings.json`, with its default in
  `SettingsState.planDefaults`. Flipping it changes the panel and its preview,
  and is logged in recent changes, but the shell ignores it.
- Some rows carry the config key the mockup proposed (`cfg`). The pane shows it.
  Those keys do not exist in `config/Config.qml` yet.

## How a backend lands

For each ticket:

1. Build the behaviour in the shell, in the module or service it belongs to.
2. If it is a config.json setting, add the key to the `defaults` in
   `config/Config.qml` with the default from `planDefaults`.
3. In `SettingsState.qml`, move the row's key out of `planDefaults` and into
   `configBacked` (or into the `v()`/`write()` switch when a service owns it).
4. Carry the user's planned value over once: on load, if `planned[key]` exists
   and the config key is still at its default, write the planned value and drop
   it from `planned`.
5. Drop `isNew` from the row (and its layer children) in `catalogue.js`.
6. Update `tests/settings.test.js`: the test that every config key exists will
   now cover the new key.
7. Add a what's-new entry when it is pushed. Adding keys is not Major.

## Order

Grouped by how much they change and how many people they reach. Each line is a
ticket under `issues/`.

### Shell surfaces the panel already draws

These are the cheapest and the most visible: the panel's sidebar preview
already shows them working.

- 01 Sidebar options: clock style, date, status icons, tray
  switch, specials rack, mode glyph
- 02 Volume past 100% as a switch
- 03 Hotkey sheet board shapes: ansi, iso, split
- 04 On-screen keyboard: key repeat on and off
- 05 Launcher: forget what it learned
- 06 Clipboard: import from clipse now
- 07 Wallpaper: replay the reveal

### Shell features with a clear home

- 08 Screen time: per-app counting, grey at the cap, breaks
- 09 Do not disturb, and what modes do with it
- 10 Notification rules per app
- 11 Alert sounds
- 12 Night light on a schedule
- 13 Accessibility: less motion, larger text, more contrast
- 14 Region: 24-hour clock, date format, time zone, language, formats

### Hyprland and system settings

These write outside the shell: Hyprland's config through the shell's own
include (`sourceEdits`), or system services.

- 15 Screens: turn off and mirror
- 16 Window layouts: dwindle, master, plugins, custom
- 17 Keyboard layouts and key repeat
- 18 Pointer: speed, natural scroll, tap to click
- 19 Pen buttons
- 20 Battery charging: hold the charge, warning, nearly empty
- 21 Power profile and lid
- 22 Idle: lock, screens off, sleep
- 23 Default apps
- 24 Startup apps (renamed from "At sign-in")
- 25 Hotspot
- 26 VPN tunnels
- 27 Restore settings from a file
- 28 OBS connection fields
- 29 VIA boards: light the bound keys
- 30 Terminal colours that follow the theme

## Open questions from the mockup's handoff

- `wallpaper.fit` is shown as "crop allowance". Confirm that is what it means.
- Streamer mode is shown as a band on a chosen screen. Confirm.
- Gesture feel maps to `control.pullCommit` only. Confirm whether the related
  pull settings should move with it.
- How custom tiling layouts plug in is undecided (ticket 16).
