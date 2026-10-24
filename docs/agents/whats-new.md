# What's new: the log written at every push

Every push is accompanied by a new entry in `docs/whats-new.json`, written at
push time. Uncommitted work in progress gets its entry when it is pushed, not
before: an entry describes an update somebody can have, and until the push
nobody can have it.

**The log is not for the repo.** It is the source the shell itself reads to
tell the user what changed (the What's new card in the update menu, see
`services/WhatsNew.qml`), so every entry is written for the RECIPIENT:
someone who has been using the previous version. Plain declarative
sentences. No internal jargon, no file paths only the author would know, no
commit hashes as prose - the entry says what is different now, not what was
committed.

## Short, always

Set by the owner on 2026-10-25, after a card full of paragraphs that nobody
read. Each change is one bullet, and a bullet is one short line:

- 70 characters at most, one sentence.
- Say what is different now. Leave out the cause, the old behaviour and how
  it works.
- One bullet per thing the reader would notice. A detail of the same thing
  folds into its bullet or goes.
- Most entries have one or two bullets.

| Too long | Right |
| --- | --- |
| A fresh install has a wallpaper from the first second: a moonlit pixel landscape that ships with the shell. The default used to point at a picture nothing installed, so the screen stayed black... | Fresh installs start with a wallpaper, not a black screen |
| The shell starts even when qt6-websockets, which talks to OBS, or qt6-multimedia, which plays sound and video, is missing. One missing module used to leave the whole screen black... | The shell starts without qt6-websockets or qt6-multimedia |

The long story goes elsewhere. A big release gets a post on the blog at
banditshell.marcusrosado.com for anyone who wants to read through it; a
small push gets no post, only its bullets. The site has no blog page yet, so
until it does the detail lives in the PR body.

## The shape of an entry

Entries are listed newest first. Each entry has:

| Field               | What it is                                                                 |
| ------------------- | -------------------------------------------------------------------------- |
| `id`                | The version line the entry ships under. Required. The push date by convention (`2026-09-27`), with `-2`, `-3`... on a second push the same day. The marker the shell stores is this id, so it must be unique and stable. |
| `date`              | `YYYY-MM-DD`, when the push landed.                                        |
| `changes`           | One bullet per noticeable thing, in the order a reader should meet them.   |
| `example`           | `true` on the seed entry only. The shell skips it; the first real entry replaces it. |
| `impact`            | Optional. What the update does to the person's setup, so the update menu can say so before they press the button. See below. |

Each change carries:

| Field     | What it is                                                                                              |
| --------- | ------------------------------------------------------------------------------------------------------- |
| `type`    | One of: `issues` (a tracked issue was fixed), `bugs` (something broken was fixed), `features` (something new it can do), `ui` (something looks or moves differently), `config` (config.json keys or files the shell writes changed). |
| `severity`| `major` or `minor`.                                                                                     |
| `text`    | The bullet the recipient reads, 70 characters at most. See Short, always.                               |

## Impact

An entry may carry an `impact` object. Every key is optional:

| Key       | What it is                                                                                  |
| --------- | ------------------------------------------------------------------------------------------- |
| `restart` | `true` when the shell must restart for the entry to take effect.                            |
| `cli`     | `true` when `banditshell` commands changed.                                                 |
| `binds`   | Ids or old command strings of the binds the entry changes, as a list of strings.            |
| `deps`    | Packages the entry newly needs, as a list of strings.                                       |

`banditshell update check` reads the diff first (a changed qmldir or `shell.qml` means restart, a
changed `cli/`, `api/` or `lua/` means commands, new `add_step` lines in `install.sh` mean
packages) and uses `impact` to add to it. With no `impact` the diff alone decides. `impact` can
turn a restart or a warning on; it cannot turn off what the diff found, so leave it out unless
the diff cannot see the effect (a bind that now does something else, a package the code calls
by name).

## Major and Minor

Everything is classified, and the classification is Major or Minor.

**THE MAJOR BAR.** Major is reserved for changes that break or redefine
something the recipient already has:

- a config.json key removed, renamed or reinterpreted;
- a user config file created, edited or deleted by the shell;
- a gesture or keybind that now does something different;
- data loss or security exposure;
- something the user must DO (an action, a migration) or their setup degrades.

Everything else - new features, polish, fixes, visual changes - is Minor, no
matter how much work it was. "New" is never Major by itself. Nothing the user
must not act on is Major.

## Recalibration

Agents inflate Major. Before classifying an entry, reread the last ten
entries in the log. If the recent Majors would not have made a recipient act
or break something, the bar has drifted: classify against the corrected bar,
and say so in the entry itself or in a note - a recalibration is also news
about the log. Recheck every ten entries or so; the drift is slow and it is
punctuated, which is exactly why the check is periodic rather than
continuous.

## Accumulation

A recipient who has skipped several pushes sees ALL accumulated entries since
their last-seen version when they pull or update - not just the newest. Write
each entry so it stands alone. Never write "as mentioned last time", because
for most of your readers there was no last time.

## The id is the version

The `id` of the newest real entry is the version number of the build. `banditshell version`, the
update menu and Settings > About show it, so it is what a person reads out when they report a bug.
Keep it a date: `2026-10-17`, then `2026-10-17-2` for a second push the same day. An id that is not
a date (`v1`) works in the shell but cannot be tagged and the promote script refuses it.

## Tags and the stable channel

A commit that reaches the `stable` branch gets a git tag made from its id: `v`, then the date with
dots, then the number if there is one. `2026-10-17` is `v2026.10.17`, and `2026-10-16-7` is
`v2026.10.16-7`. `main` pushes are not tagged. `scripts/promote-stable.sh` (or `banditshell dev
promote`) checks main and prints the `git push origin main:stable` and the tag commands; it pushes
nothing unless run with `--push`, and agents never run it with `--push`. Write the entry before
promotion: the tag is made from the newest entry on main at that moment. `docs/architecture/updates.md`
has the whole update loop and the channels.

## The card

`services/WhatsNew.qml` reads this file; entries newer than the marker
(`whats-new-seen` in the shell's state dir; older copies kept `updates.seen` in config.json, which is copied over once and then left alone) accumulate and surface in the
update menu when the user opens it; nothing summons it at launch. Entries
are marked seen when the person dismisses the card, not when it is shown.
Entries that are only incoming, before the update is taken, are listed in
the same menu from the target's copy of this file and are not marked. A config.json the shell creates on a first
start begins at the newest entry, so a new install shows nothing until the
next push. The example entry in the file is skipped by
the shell and exists only to show the shape; replace it at the first push
under this rule.
