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

## The shape of an entry

Entries are listed newest first. Each entry has:

| Field               | What it is                                                                 |
| ------------------- | -------------------------------------------------------------------------- |
| `id`                | The version line the entry ships under. Required. The push date by convention (`2026-09-27`), with `-2`, `-3`... on a second push the same day. The marker the shell stores is this id, so it must be unique and stable. |
| `date`              | `YYYY-MM-DD`, when the push landed.                                        |
| `changes`           | One line each, in the order a reader should meet them.                     |
| `example`           | `true` on the seed entry only. The shell skips it; the first real entry replaces it. |

Each change carries:

| Field     | What it is                                                                                              |
| --------- | ------------------------------------------------------------------------------------------------------- |
| `type`    | One of: `issues` (a tracked issue was fixed), `bugs` (something broken was fixed), `features` (something new it can do), `ui` (something looks or moves differently), `config` (config.json keys or files the shell writes changed). |
| `severity`| `major` or `minor`.                                                                                     |
| `text`    | The one line the recipient reads.                                                                       |

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

## The card

`services/WhatsNew.qml` reads this file; entries newer than the marker
(`updates.seen` in the user's config.json) accumulate and surface in the
update menu, and the shell summons that menu once at launch when there is
anything pending. Entries are marked seen when the card has been believed on
screen, not when it is dismissed. The example entry in the file is skipped by
the shell and exists only to show the shape; replace it at the first push
under this rule.
