# Modules and packages

banditshell is one repository that is meant to become several parts that can ship separately: the
launcher without the lock screen, the file browser alone, the lock screen alone. The first step is
to say, in files a program can read, which part owns which file and which parts may use which. This
page describes that map, the rules a script checks against it, and the steps that come next. It
comes from the architecture audit of 2026-10-17.

Most files are where they were, and the manifests describe them. The panel contract (`LazyPanel`, the
three panel IPC bases and `PanelWindows`) lives in `modules/panel`, which core owns. `PanelWindows`
asks the window registry (`Shell`, host) and `Hypr` for the windows, so it stays a baseline reach
until the `Panels` registry exists; keeping it in core means every package that serves a panel needs
only core to import it. The root `modules/` folder holds host files only.

## Manifests

A package is a name, an owner for a set of files, and a list of the other packages it may use. Each
package has one `module.json`.

A package named after a folder under `modules/` keeps its manifest in that folder, at
`modules/<name>/module.json`. Every other package has `packages/<name>.json` at the repo root. The
name inside the file must match its place. There are 37 packages and the split is 18 and 19.

A manifest has these fields, and the check refuses any other.

```json
{
  "name": "lock",
  "summary": "the lock screen",
  "layer": 5,
  "owns": { "qml": ["modules/lock"], "services": ["Lock"], "assets": ["assets/pam.d"] },
  "requires": { "packages": ["core", "media"], "optional": [] },
  "provides": { "singletons": [], "ipc": [] },
  "config": { "namespace": ["lock"], "reads": [] }
}
```

`owns` lists paths relative to the repo root, grouped by kind (`qml`, `services`, `js`,
`components`, `assets`, `scripts`, `tests`, `src`). A path may be a file or a folder, and a folder
claims everything below it. Under `services` the entries are singleton names, so `"Lock"` means
`services/Lock.qml`. The most specific claim on a file wins, so `launcher` can own
`modules/launcher` while `launcher-ai` owns `modules/launcher/sources/AskSource.qml`. Two packages
claiming the very same path is an error.

`requires.packages` are the packages this one may import or call. `requires.optional` are packages
it may use when present; for the check they count the same, and they matter later when a missing
package must not stop the shell compiling. `layer` is a number that has to be higher than the layer
of everything the package requires, so the dependencies can never form a loop.

`provides.singletons` is the public face of the package, the singletons other packages may name.
Every other singleton the package owns is private to it. `provides.ipc` lists the `IpcHandler`
targets the package answers. `config.namespace` lists the dotted config keys the package owns, such
as `lock` or `launcher.devOps`; the longest match wins. `config.reads` lists namespaces of other
packages it may read, which in practice means the shared theme keys that belong to `core`.

The manifests describe where each package is meant to end up. Where the code reaches further than a
manifest allows today, the check records the gap in a baseline instead of the manifest being bent to
fit.

## The package map

Layers climb from `core` at 0. The package list and its first layers come from the audit; a layer was
raised where a package's requirements forced it (`compositor` is at 1, so everything that requires it
sits at 2 or above). The `launcher-` packages are the launcher's source packs, which follow the
launcher's groups in the config.

| package | layer | owns | requires | IPC | config namespace |
|---|---|---|---|---|---|
| core | 0 | Config, Appearance, Themes, ControlTuning, generic components, the controls kit, Relaunch, Prompts, Tooltips, TimeFormat, Polkit, modules/panel, cli.js, LevelCover | none | shell | theme, themeFromWallpaper, font, material, rounding, padding, button, anim, colour, edge, access, control, blob, region, polkit, sourceEdits |
| compositor | 1 | Hypr, HyprConfig, Monitors, Keymap, CompositorSync, chords and Lua helpers | core | migration | compositor, cli |
| apps | 2 | Apps, AppIcons, DesktopIndex, Launching, DefaultApps, StartupApps | core, compositor | none | apps, startup |
| audio | 2 | Audio, Bluetooth | core, compositor | output | audio, volume |
| capture | 2 | ScreenRecorder, modules/picker | core, compositor | picker | picker |
| cheatsheet | 2 | Keyboards, modules/cheatsheet | core, compositor | hotkeys | cheatsheet |
| clipboard | 2 | Clipboard, Dictation, modules/clipboard | core, compositor | clipboard | clipboard |
| clock | 2 | Clock, Localisation, Weather | core, compositor | timer, alarm, zone | clock, weather |
| display | 2 | Display, Backlight, DarkMode, Tablet, bs-gamma | core, compositor | screen, tablet | screen, tablet |
| files | 2 | Files, Downloads, modules/files, bs-ls, bs-pty | core, compositor | files | files |
| host | 2 | shell.qml, ShellWindow, Chassis, Ipc (the list of every target), the Shell window registry | core, compositor | border | none |
| media | 2 | Media, Lyrics, modules/media | core, compositor | media | media |
| network | 2 | Network, Hotspot, Tunnels, Tailscale, WifiJoin | core, compositor | none | network |
| password | 2 | Keyring, PasswordRequest, modules/password | core, compositor | keyring, polkit | none |
| pen | 2 | PenMap, PenButtons, modules/pen | core, compositor | penmap | pen |
| settings | 2 | modules/settings, Settings, Modes, ThemeSwitcher | core, compositor | settings, mode | settings, corner, menu |
| wallpaper | 2 | Wallpaper, modules/wallpaper (with WallpaperWindow) | core, compositor | wallpaper, wallpapers | wallpaper |
| bar | 3 | modules/sidebar, modules/menu, Tray, SidebarState | core, compositor, apps, audio, network, display | menu, sidebar | sidebar, calendar |
| calculator | 3 | Calculator, Currency, modules/calculator | core, compositor, network | calculator | none |
| keyboard | 3 | modules/keyboard, Keystrokes | core, compositor, display | keyboard | tablet.autoKeyboard, tablet.height, tablet.seam, tablet.repeat, tablet.repeatDelay, tablet.repeatInterval |
| launcher | 3 | the launcher itself, LauncherHotkeys, search.js | core, compositor, apps | launcher | launcher |
| notifications | 3 | Notifications, AppNotifications, AlertSounds, modules/notifications | core, compositor, apps | notifications, quiet | notifications, sound |
| quickcontrols | 3 | modules/quickcontrols | core, compositor, audio, display | quickcontrols | screen.grabFraction, screen.linger |
| stream | 3 | StreamState, Obs, modules/stream | core, compositor, apps, audio, network | stream | obs, stream |
| windows | 3 | modules/windows, modules/workshop, WindowLayouts, WorkshopLayouts, LayoutDraft | core, compositor, apps | none | windows |
| launcher-ai | 4 | Assistant, the ask and rewrite sources | core, compositor, launcher, clipboard | none | launcher.ai |
| launcher-devops | 4 | containers, ports, phone, ssh, systemd and monitor sources | core, compositor, launcher, files | none | launcher.devOps |
| launcher-system | 4 | brightness, wifi, vpn, record, sound and workshop sources | core, compositor, launcher, network, display, audio, capture | none | launcher.systemControls |
| launcher-tools | 4 | colour, dev, notes, snippets, emoji, typing, latest files and file search sources | core, compositor, launcher, clipboard, files | none | launcher.powerTools, launcher.typing, launcher.utilities |
| power | 4 | Battery, ChargeLimit, Power, PowerProfile, Lid, Suspension, Idle | core, compositor, notifications | none | battery, power, idle |
| updates | 4 | Update, Pacman, WhatsNew | core, compositor | none | updates, packages |
| island | 5 | modules/island, Notices, Activities, Levels | core, compositor, notifications, media, apps, clock, audio, display (optional: clipboard, capture, updates, files) | island, inspect, activity | island |
| launcher-online | 5 | browser, define, github, packages, speedtest, translate and video sources | core, compositor, launcher, files, apps | none | launcher.online |
| launcher-shell | 5 | keys, tray, workspace, actions and recent documents sources | core, compositor, launcher, launcher-tools, bar, host, clipboard, files | none | launcher.shell |
| lock | 5 | Lock, modules/lock | core, compositor, media, wallpaper, clock, power, notifications | none | lock |
| screentime | 5 | Usage, UsageApps, UsageLimits | core, compositor, power | none | usage |
| session | 5 | modules/session | core, compositor, power | session | session |

The `host` package is the shell window and everything that wires panels together. Today it still
imports most of the feature modules, which is rule R11 below, and that is the main thing the next
steps take apart.

## What the check enforces

`scripts/check-modules.js` reads the manifests, scans every `.qml` and `.js` file under `modules/`,
`services/`, `components/`, `config/` and `previews/` (comments and string contents removed, so a
name in a comment is not a use), and applies these rules.

| rule | what fails |
|---|---|
| R1 ownership | a file under `modules/`, `services/`, `components/`, `config/`, `assets/`, `scripts/`, `src/`, `tests/`, `previews/` (or `shell.qml`, `preview.qml`) that no package owns, or that two packages both claim by the same path |
| R2 imports | `import qs.modules.x`, a relative folder or a relative `.js` import whose target belongs to a package this one does not require |
| R3 singletons | a file uses a singleton owned by a package it does not require, or one that package keeps private |
| R5 config | a file reads a config key owned by another package that is not in `config.reads`, or a key no package owns. It looks at `Config.values.a.b`, `Config.get("a.b")`, `Config.set("a.b", ...)`, `cfg: "a.b"` in the settings catalogue, and properties that alias `Config.values` |
| R6 IPC | an `IpcHandler` target that no package declares, that two packages declare, that is declared by a package other than the one whose file defines it, or that is declared and defined nowhere |
| R8 dependency graph | `requires` that form a cycle, or a package whose layer is not above the layers it requires |
| R9 pure components | a file in `components/` that imports `qs.services` or `qs.modules`, or names `Config` or `Compositor`. Components take their tuning through properties; the defaults come from the `ControlTuning` singleton in `config/` |
| R11 host | `ShellWindow.qml` or `Host.qml` importing a feature module, whatever the host requires |
| R12 manifest | invalid JSON, unknown or missing fields, a wrong name, an unknown package in `requires`, an owned path that does not exist, a public singleton the package does not own |

Three more rules only warn, because they are easy to get wrong with commands built at runtime. R4
reports a write to another package's singleton property (`Idle.awake = ...`). R7 reports a file that
runs another package's script or helper. R10 reports a test that reads another package's files. Run
`node scripts/check-modules.js --warnings` to see them.

## The baseline

The code does not meet its own manifests yet. `modules.baseline.json` lists every violation that
exists today, one line each, keyed by rule and file so a changed line number does not disturb it.
The check passes when every violation it finds is in that list and fails on any that is not, so the
list can only shrink. When you fix violations the check says how many baseline lines are now stale;
run `node scripts/check-modules.js --write-baseline` and commit the shorter file. Never run it to
silence a new violation. R1, R8, R9 and R12 are kept empty by a test, since they have no good reason
to be in a baseline.

## Commands

```
banditshell dev modules                       check against the baseline
banditshell dev modules --matrix              which package reaches for which
banditshell dev modules --explain <package>   what a package needs, with file and line
```

The matrix has packages in rows and columns, ordered by layer. A number is how many files of the
row reach the column; `!` marks a reach the row does not declare, `o` a declared reach nothing uses.
`--explain` groups what a package uses by the package it comes from, says whether that is declared,
and shows the first places. Add `--all` to list every place. The same script runs without the CLI as
`node scripts/check-modules.js`, which is what CI runs in the `modules` job, and `node --test
tests/check-modules.test.js` covers the parsers and the repository itself.

## Adding a package

1. Decide the package's files. Prefer a folder under `modules/<name>` and name the package after it,
   so its manifest sits at `modules/<name>/module.json`. A package with no folder of its own gets
   `packages/<name>.json`.
2. Write the manifest with the fields above. List what it owns, what it requires and the layer, which
   must be above every required package.
3. Put the singletons other packages are meant to use in `provides.singletons`, the targets it
   answers in `provides.ipc`, and the config keys it owns in `config.namespace`.
4. Remove those files from the manifest that owned them before. A path claimed by two packages
   fails R1.
5. Run `banditshell dev modules`. Anything new it reports is either a missing `requires` entry that
   is a real dependency, or a reach that should not exist; decide which, and fix the code or the
   manifest. Do not add to the baseline.

A new file in an existing package needs no manifest change when its folder is already owned. A new
file in a folder no package owns, or a new top level folder, needs an `owns` entry.

## Next steps

These are steps 4 onward of the audit's refactor plan, in order. Each one removes a group of baseline lines, so
the baseline is the progress report.

1. Done: `modules/Cli.qml` is split into one IPC file per package on a shared `PanelIpc` base in
   `modules/panel`, with a snapshot test of the target names. What is left is that these files
   reach `Shell` (host) and `Hypr`, which the `Focus` and `Panels` steps below remove.
2. Break the small cycles with interface singletons: `Notify` for alerts, `SessionControl` for the
   lock, `Focus` for the off stage screen, and `Panels.open` for opening settings and the launcher.
   Split `services/Shell.qml` into a window registry and `Focus`.
3. Move the general helpers out of `Files` (`home`, `copyText`, `openWith`, `reveal`) into a core
   `System` singleton, so the launcher no longer needs the file browser.
4. Move the single consumer components and shaders into the package that uses them, and move
   `modules/controls`, `Prompts` and `Tooltips` into a core kit.
5. Give each package its own size tokens and take them out of `Appearance`, which clears the R5 lines
   on `config/Appearance.qml`.
6. Define the panel contract as a base type and make the existing panels follow it, so `ShellWindow`
   derives its mask, focus and escape order from one list.
7. Add the `Panels`, `Bands` and `Menus` registries, so `ShellWindow` imports no feature module and
   the R11 lines disappear.
8. Add the `LauncherSources` registry and let the source packs register themselves, which empties
   the launcher's R2 lines on its own packs.
9. Add the `Activities` registry for the island, replacing `Notices` and the click router in
   `ShellWindow`.
10. Give each package a config schema, move the keys that other packages read into the namespace of
    the package that owns the behaviour, and stop `Config.qml` naming other packages' keys.
11. Add `SettingsPages` and `SettingsIndex`, and split `catalogue.js` per package.
12. Move private services into their package folders, make the manifests authoritative, generate the
    package list and the CLI from them, and add the packing script that builds a single part for
    shipping.
