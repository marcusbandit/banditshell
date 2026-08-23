# Multi-monitor

The shell already draws itself on every screen: `shell.qml:45` wraps four surfaces in
`Variants { model: Quickshell.screens }`, and every panel's state lives on its own
`ShellWindow`, so N monitors already means N independent launchers, menus and trays. Nothing
here adds per-screen surfaces. What it fixes is the places that still answer a per-screen
question with a shell-wide answer.

There are six of them, and they are the same mistake wearing six costumes: a single slot
serving N readers, or N writers serving a single slot.

## 1. "Which screen" means the focused one

`services/Shell.qml:31-35` returns `root.windows[0]` when no screen is named, which is
registration order and therefore an arbitrary monitor. Twenty IPC verbs go through it
(`modules/Ipc.qml` lines 30, 56, 69, 113, 121, 151, 173, 181, 246, 263, 271, 297, 305, 329,
341, 354, 964, 972, 986, 1633), so the launcher, clipboard, session menu, calculator and
wallpaper picker all open on whichever monitor happened to register first rather than the one
you are looking at.

`forScreen("")` resolves explicit name, then `Hypr.focusedScreen`, then `windows[0]`. That is
already the rule `services/Settings.qml:149` uses, and already what `Hypr.focusedScreen`'s own
comment at `services/Hypr.qml:664-666` promises it is for: "what 'the screen' means to anything
summoned by a keybind rather than reached for with the cursor."

One edit, twenty verbs. The `close` verbs keep looping `Shell.windows`, because closing
everywhere is right.

## 2. Workspace bands are per monitor

Every screen's sidebar draws the FOCUSED monitor's workspaces. `WorkspaceModel` is instantiated
per screen but reads `Hypr.activeId` (`services/Hypr.qml:22-27`, the focused workspace) and
`Hypr.specialShown` (`:186`, the focused monitor's scratchpad). `services/Hypr.qml:198-203`
already admits this in a comment: a per-screen consumer could ask about its own screen, and
"nothing does yet".

### The band model

A monitor owns a contiguous run of workspaces:

```
band(k) = [k * count + 1 .. k * count + count]      count = Appearance.sizes.wsPersistent
```

where `k` is the monitor's position in an explicit ordered list of monitor names, never a
spatial or id-derived one. With `count = 5`, the first monitor owns 1-5 and the second 6-10.

### Where the order comes from

`config/Config.qml` gains `sidebar.workspaces.order: []`. An empty default array is the correct
declaration: `Config.qml:1433-1453` treats `[]` as a list whose user value survives a merge at
any length, where a non-empty default would be a fixed-length tuple that reverts whenever the
length changes.

It is SEEDED from the compositor rather than invented. `hyprctl workspacerules -j` reports
`{workspaceString, enabled, monitor}` for every rule, so grouping by monitor and sorting each
monitor by its lowest numeric workspace gives the order the compositor is already keeping. On a
machine whose `rules.conf` binds 1-5 to one output and 6-10 to another, the seeded order
reproduces exactly that and nothing moves on first run.

Monitors with no rule are appended in `Quickshell.screens` order. The seed is written once so
the order is stable afterwards, and a name is never removed when a monitor is unplugged, so
replugging restores the same band.

### Reading it back

`Hypr` gains:

- `bandFor(screen)` - the first workspace id of that monitor's run.
- `activeOn(screen)` - that monitor's own active workspace, from `Hyprland.monitors`, with the
  same "a scratchpad is not where you are" rule `activeId` already applies at `:22-27`.
- The existing `specialByMonitor` map (`:204`) is finally read per screen instead of through
  `specialShown`.

`WorkspaceModel` takes a `screen`, resolves its band once, and targets `band + i` for slot `i`.
The four style files (`modules/sidebar/WorkspacePlates.qml:134,507`, `WorkspaceMap.qml:64`,
`WorkspaceBlocks.qml:53`, `modules/windows/WorkspaceShelf.qml:184`) stop reading the global
`Hypr.activeId` and read the model's own answer. `modules/windows/WindowEdge.qml:545` does the
same.

`Hypr.switchTo(id)` keeps working unchanged, because a band member is a real workspace id.

### Applying a change

Reordering in the settings page writes `sidebar.workspaces.order` and emits, for each monitor
whose band moved:

```
hyprctl keyword workspace <id>, monitor:<name>
```

Binding only. `rules.conf` is never rewritten, because `workspacerules -j` does not report
`layout` or `layoutopt` and a shell that regenerated the rules would silently drop them. On a
machine where ws 6 carries `layout:scrolling, layoutopt:direction:down`, that option survives.

`hyprctl keyword` is runtime state and a `hyprctl reload` reverts it to `rules.conf`, so the
apply is re-run on the existing `configReloaded` signal (`services/Hypr.qml:750`).

### Section 7: the control

A new settings page, which `services/Settings.qml:55-59` makes a two-part change: add
`{ key: "screens", title: "Screens", icon: "monitor" }` to `pages`, and drop
`modules/settings/pages/ScreensPage.qml` next to the other two. The file name is resolved by
convention; no dispatch table grows a case.

The page is one `MenuRow` per monitor in band order, the band as the row's `detail`, and up/down
buttons in the trailing slot. `MenuRow`'s `default property alias trailing` puts children in the
right-aligned slot, and its row-wide `MouseArea` must stay declared first so it sits under them
(`components/MenuRow.qml:99-104`).

Not drag-to-reorder. There is no `DropArea` or `Drag.*` anywhere in the repo, and
`DESIGN.md:1571-1595` records why hand-rolled dragging here is harder than it looks. Two buttons
match every existing settings idiom.

This control is not a convenience. `config/Config.qml:527-529` records that Quickshell's IPC
reads a bracketed argument as an argument LIST and splats it, so an array can never be set from
the CLI. The settings page is the only way this key is editable.

## 3. Three surfaces stop contending for the keyboard

Two exclusive layer surfaces is the "typing goes nowhere" failure that
`modules/ShellWindow.qml:128-210` spends eighty lines guarding against. Three places create it
the moment a second monitor exists.

- **`components/Prompts.qml`** is a shell-wide list of keyboard claims. `modules/menu/Menus.qml:177`
  turns it into `needsKeyboard`, which feeds `WlrLayershell.keyboardFocus` on every
  `ShellWindow`. A password field open on one monitor makes another monitor's surface claim
  `Exclusive` too. Claims get keyed by their window, and `Prompts.activeIn(window)` answers per
  surface.
- **`modules/picker/PickerWindow.qml:35`** claims `Exclusive` on every screen while the picker
  is open. The claim latches to whichever screen was focused when it opened. Every screen stays
  VISIBLE, so a selection can still be dragged on any monitor; only the keyboard is owned in one
  place, which is what Escape needs.
- **`installer/askpass.qml:146`** is a bare `PanelWindow` with no `Variants` and no `screen:`,
  so the sudo prompt appears on one output while taking `Exclusive`. It gets wrapped the way
  `installer/shell.qml:188-196` already wraps the progress surface, with the same latch.

## 4. The picker freezes per output

`modules/picker/PickerState.qml:122` freezes with bare `grim "$f"`, which captures the whole
layout as one image spanning every monitor. `modules/picker/Picker.qml:183-189` then paints that
file into each per-screen overlay with `anchors.fill: parent` and `fillMode: Image.Stretch`, so
every monitor shows the entire layout squeezed across its own width.

`frozenPath` becomes a map keyed by screen name, filled by one `grim -o <name>` per screen.
`Picker.qml` shows its own screen's file.

This also removes a latent scale bug. `PickerState.qml:75` crops the frozen frame at
`x + screen.x`, which assumes layout coordinates equal image pixels, true only while every
monitor is at scale 1.0. A per-output frame is already output-local, so the offsets go away and
the arithmetic is correct at any scale.

The live path (`:84`, `grim -g` against the layout) is already correct and does not change.

## 5. Notifications land once

`modules/notifications/NotificationTray.qml:251` reads the `Notifs` singleton unfiltered on
every screen, so one notification pops on all of them. Popups render only on the focused screen.
Expanding the tray by hand LATCHES it to that screen, so moving the pointer to another monitor
does not yank an open tray away; the latch clears when it collapses.

Two shared slots underneath it are last-writer-wins today and stop being bools:

- `services/Notifs.qml:58` `paused` is written by `NotificationTray.qml:259` from every tray's
  `expanded`. Collapsing a tray that was never expanded resumes countdowns under a list being
  read on another screen. It becomes a set of holders, and `paused` is derived from whether the
  set is non-empty.
- `services/NotifEntry.qml:467` `held` is written by every card
  (`modules/notifications/NotificationCard.qml:183-184`). Pinning card A sets `entry.pinned`,
  which flips card B's `held`, which writes back and clobbers A. The entry derives `held` from
  its cards rather than being told by each of them. `services/NotifEntry.qml:490-491` already
  names this as a known weakness.

Section 5 mostly falls out of gating the popups: with one tray live, N drops to 1. The holder
set is what keeps it correct while focus moves.

## 6. Focus restore stops being one slot

`services/Hypr.qml:605` `focusedAddress` is a single string that seven panels snapshot on open
and hand back on close: `services/Settings.qml:147`,
`modules/calculator/CalculatorPanel.qml:197`, `modules/clipboard/ClipboardPanel.qml:112`,
`modules/cheatsheet/CheatSheet.qml:779`, `modules/launcher/ListLauncher.qml:121`,
`modules/launcher/NiagaraLauncher.qml:504`, `modules/session/SessionMenu.qml:138`.

Two panels open on two monitors overwrite each other's idea of what to focus on close. Each
panel keeps its own snapshot in its own instance. `Hypr.focusedAddress` stays what it is, the
live answer; it simply stops being used as storage.

## Not in scope

- **Per-screen wallpaper.** `services/Wallpaper.qml:168-172` argues deliberately for one
  wallpaper across every monitor. Unchanged.
- **Resource duplication.** `modules/MicIndicator.qml:218` opens a unix socket per screen,
  `modules/TopNotch.qml:293` runs a per-second clock per screen, and
  `modules/cheatsheet/CheatSheet.qml:908-926` runs `hyprctl` twice per screen. All are N times
  more work than needed and none is a correctness bug. Hoisting them into `services/` is a
  separate change.
- **`modules/sidebar/WorkspaceMap.qml:39`** measures a client's width against `Screen.width`,
  this screen's, while the client may be on another monitor. Once section 2 lands, a map only
  ever draws its own monitor's workspaces, so the mismatch stops being reachable. No edit.
- **Dev harnesses.** `lockpreview.qml`, `calcpreview.qml`, `batterypreview.qml`, `qrpreview.qml`
  and `windowpreview.qml` are unplaced single-screen windows on purpose.

## Verification

The shell runs live, so every section is checkable rather than argued:

- `banditshell shot` plus `grim -o <name>` on each output, before and after.
- Sections 1, 5: invoke a verb with the pointer on each monitor in turn and confirm the surface
  appears under it.
- Section 2: `hyprctl dispatch focusmonitor` between outputs and confirm each sidebar highlights
  its own workspace; confirm `hyprctl workspacerules -j` still reports the same bindings after a
  reorder, minus only what moved.
- Section 3: open a password prompt on one monitor and type; confirm keystrokes land.
- Section 4: open the picker and confirm each overlay shows its own screen unstretched.
