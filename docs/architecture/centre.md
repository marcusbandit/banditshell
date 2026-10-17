# The centre of the screen

Written 2026-10-17, during the full audit on branch `full-system-audit-roadmap`.
This is a proposal, not a decision. DESIGN.md stays the record of what was
decided; this file is the plan that the branch builds toward, and the reasons.

## Three places, three questions

The shell grew three surfaces that all want to be the main one. They stop
competing once each one answers a different question.

The island, at the top centre, answers "what is happening". Music, a timer,
an app opening, a download, a live notification, the volume you just changed,
dictation, a recording. It is driven by the world, not by you. The pointer is
its input: hover to look closer, press to act on the one thing it shows.

The launcher answers "what do I want". Apps, commands, settings, files,
answers, and every history the shell keeps: notifications, clipboard, recent
files, downloads. It is driven by you. The keyboard is its input.

The sidebar answers "where am I". Workspaces are a map you read with your
eyes and drag things across, and the tray holds menus that belong to other
programs. Everything else in it today is a copy of something the island or the
launcher does better, so in the rail style it shrinks to workspace pips and
only shows a status icon when something is off: low battery, a VPN up, the
mic live, quiet hours, an update waiting.

The menus (sound, network, bluetooth, battery, calendar, clock, update) do not
change role. They are the full view of one domain, the place DESIGN.md
section 3 asks to handle the whole domain. What changes is how many doors lead
to them.

## Live goes up, history goes down

A thing that is happening shows in the island. Once it has happened, it
belongs to a history, and every history is a launcher mode.

| Domain | Live, in the island | History and control, in the launcher |
| --- | --- | --- |
| Notifications | the deck, one card per thread | `notifications`, search, reply, mute, snooze |
| Clipboard | "Copied" for half a second | `clipboard` (the panel stays for dragging) |
| Downloads | a ring while it runs, the file when it lands | `latest downloads` |
| Timers | a ring with the time left, the alarm when it rings | `timer`, `alarm` |
| Updates | "update ready" with a one-line summary | `update`, `whats new` |
| Screenshots | the thumbnail with Copy and Edit | `latest screenshots` |

The island never needs the keyboard and the launcher never needs to stay on
screen. A press on an island row that has a history opens the launcher with
the right words already typed, which is the one hand-off the shell is
missing today (`Launcher.show(text)`, `banditshell panel launcher open
<query>`).

This is why the corner notification tray goes. Live notifications already
arrive in the island when `notifications.placement` is `island`, and the
history was the only reason left to keep a column of cards on the right edge,
a head-turn away on a 32:9 screen. The audit found the tray also lost history
on every reload, deleted a card when you pressed it, and never showed when
anything arrived.

## Every door calls an action

Today a keybind, a launcher command row, an island row and a sidebar icon
each reach the same thing their own way: a CLI string, a function call on a
service, a case in `ShellWindow.act()`, a hard import of a menu. That is the
coupling that makes the shell one piece.

The branch introduces action ids (`api/actions.tsv`): `launcher.toggle`,
`panel.clipboard.toggle`, `screenshot.copy_frozen`, `wallpaper.next`. They are
the shell's verbs, and they are a promise: an id is never deleted, only
deprecated with a pointer to its replacement. Every door should end up
calling one:

- Hyprland binds call `bs.launcher.toggle` from the Lua module, which runs
  `banditshell action launcher.toggle`. The CLI can be regrouped again and no
  user config changes.
- Scripts and `.desktop` files run `banditshell action <id>`.
- The hotkey sheet reads each id's description, so it shows "Open or close
  the launcher" instead of the raw command.
- Later, launcher command rows and island rows carry an action id instead of
  a closure, so a module can offer a verb without importing the module that
  performs it.

## How the parts talk once they ship apart

The architecture audit (`.scratch/audit-2026-10-17/architecture.md`) measured
how tangled the tree is: ShellWindow names every panel ten times, Cli.qml held
every IPC handler, the launcher reaches 101 of 110 services, and five import
cycles block a clean split. It also pinned the one hard constraint: anything
that draws inside the chassis has to live in one process, because the metaball
field merges their shapes. So "ship the launcher alone" means a small core, a
host, and the launcher package composed into one config tree, not a separate
program.

Inside one process, packages talk through four things, in this order of
preference:

1. Registries in core that a package fills from its own entry file: panels,
   menus, activities, launcher sources, settings pages, config schema. The
   host draws whatever registered and imports no feature.
2. Interface singletons in core for the few cross-package calls that are
   real dependencies (`SessionControl` for "lock now", `Notify` for "post an
   alert", `Focus` for "which screen is off stage"). The package that owns the
   behaviour implements them.
3. Action ids for anything a user could also trigger by hand.
4. IPC targets, owned by the package next to its code (the `Cli.qml` split
   on this branch), for anything outside the process.

Across processes and for other programs: action ids, IPC, and later a
`banditshell events` stream of JSON lines (workspace, panel, media, activity,
notification) so a status bar or a script can follow the shell without
polling.

A boundary check (`scripts/check-modules.js`, `banditshell dev modules`) reads
a `module.json` per package and fails on any new import, singleton use or
config read that crosses a boundary without being declared. Today's
violations are a committed baseline that can only shrink.

## The update loop, seen from the person who did not write it

People who did not write this shell run it. For them an update must say
what it is before it happens, check that the new version loads before it
replaces the old one, restart only when restarting is needed, and come back on
its own if the new version does not start. The branch moves the update logic
out of inline shell strings in QML into `banditshell update
check|apply|rollback|status`, so the terminal, the update menu and the tests
all go through the same steps.

Binds are part of this. An update that changes the CLI no longer reaches a
user's Hyprland config at all, because the config only names action ids
through the Lua module, and the module is loaded through a frozen shim that
finds whichever checkout is current.

## What stays open

These are choices for the owner, not for an agent:

- Whether the corner tray is deleted or kept as an opt-in `placement`.
- Pills: 57 pill shapes are drawn two ways (circular ends on 21, the shell's
  own power on 36). One of the two should win.
- How far to retire the Material 3 parts: Button's five styles and shape
  morphs, the wavy scrubber, the lobed password marks, the Material Symbols
  font.
- Whether the rail becomes the default sidebar style.
- Release channels (`stable` that moves only after checks pass, `main` as
  the edge) and version numbers.
