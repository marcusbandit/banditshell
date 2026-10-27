# Where the tests are missing

GitHub: #104

Audit of 2026-10-24. The rule that decides what gets a test is
`docs/agents/testing.md`; this folder is where that rule says to look first.

## What was measured

- 2016 test cases, 22.5k lines in `tests/` without fixtures, about 144k lines
  of code: 16%.
- 119 of 125 plain `.js` files are loaded by a test. That part is done.
- 521 of 541 QML files are never touched by a test, because `node --test` does
  not run QML. Most of them are layout and need no test. The services are the
  gap: 128 files, 26k lines, much of it glue around a `.js` sibling that is
  already tested, plus inline decisions that are not.
- 11 of 25 shell scripts and 10 of 16 Python scripts have no test. The C
  helpers in `src/` (1.3k lines) are built by the update tests, never run.

Nine Haiku agents read every untested service, the busiest launcher, island
and panel files, and every untested script, and ranked each file. Their
rankings ran high (33 files called high); the tiers below are re-cut against
the rule, and every bug listed was checked by reading the code before it was
filed.

## Tiers

Tier 1 is code where a bug costs something the user cannot get back or cannot
see: their files, their config, their password, their system. Tier 2 is code
where a bug shows up on screen and a retry or a restart fixes it. Tier 3 is
everything else; it gets a test when a bug turns up there, not before.

| Tier | Ticket                                                    | About    |
| ---- | --------------------------------------------------------- | -------- |
| 1    | [01 writes outside the shell](issues/01-writes-outside-the-shell.md) | 130 cases |
| 1    | [02 secrets and privilege](issues/02-secrets-and-privilege.md)       | 80 cases  |
| 1    | [03 packages and upgrades](issues/03-packages-and-upgrades.md)       | 70 cases  |
| 2    | [04 time and schedules](issues/04-time-and-schedules.md)             | 80 cases  |
| 2    | [05 reading other programs' output](issues/05-reading-tool-output.md) | 100 cases |
| 2    | [06 notifications and the island](issues/06-notifications-and-island.md) | 70 cases |
| 2    | [07 launcher](issues/07-launcher.md)                                 | 100 cases |
| 3    | [08 scripts and the highlighter](issues/08-scripts-and-highlighter.md) | 85 cases |

At about 12 lines a case, tiers 1 and 2 add roughly 7.5k lines and take the
ratio from 16% to about 21%. Tier 3 adds under one point more. Fixtures count
on neither side. The 40% ceiling is nowhere near; more tests than this would
be testing layout.

## Bugs the audit found

Each is filed and each fix ships with the test that would have caught it.

- #105 Clearing the clipboard deletes saved images while `clipboard.json`
  cannot be read.
- #106 Rounding, gaps and border size shift into the wrong settings when
  Hyprland lacks one option.
- #107 The installer hangs at the password prompt if the prompt window dies
  after taking the request.
- #108 The previous polkit agent does not come back if it was upgraded while
  banditshell held the prompt.
- #109 The launcher stops learning new apps once it remembers 400.
- #110 Editing a keybind or monitor fails when it lives in a file sourced from
  outside `~/.config/hypr` (Omarchy's layout).
- #111 Enter on a command's output line in the launcher tries to switch the
  sound output.
- #114 A notification that asks never to expire still disappears after the
  default time. Possibly on purpose; it waits on the owner's call.

Smaller things noticed, not filed:

- `Files.humanSize(1048575)` reads `1024 kB`; it picks the unit first and
  then rounds up into the next one.
- `SystemMonitor.quitAsAdministrator` treats an empty name as a match for any
  process. The polkit prompt still shows the real process name.
- `CheatSheet.keyName` and `keybind-search.js keyLabel` name the same keys
  differently (`SHIFT L` against `Shift_L`).
- `Clipboard.classify` calls any 3, 4, 6 or 8 hex digit text a colour, so
  `2024` and `cafe` get a swatch.

Claims the agents made that were not confirmed, worth a look while writing the
tests: Ctrl+Enter on a process row in the list launcher force quits with no
confirmation; a script's password argument is typed into the search field and
reaches `fd` as an argument; `Lid.engage()` leaves a restart timer that can
bring back `systemd-inhibit` after the takeover ends.

## Left out on purpose

Layout, animation, springs and colours across `modules/`; the website under
`site/`; developer-only generators (`emoji-table.py`, `alert-sounds.py`,
`testbed.sh`, `boot-check-inner.sh`, the app-mark skill); thin services that
only forward to a tested `.js` file; the C helpers in `src/`, because the suite
has no C build step. They get a test once CI compiles them, or when a bug
turns up in one.
