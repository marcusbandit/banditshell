# Testing: what gets a test, and how much

On 2026-10-24 the suite held 2016 cases in about 23.6k lines, against about
145k lines of code. That is 16%. The count looks big because each case is
small: one `test.it` per behaviour, and most run in well under a millisecond.
The whole suite takes about 24 seconds on banditbox.

Nearly every plain `.js` file already has a test. What has none is the logic
that lives inside QML files and a few scripts, because `node --test` never
runs QML. `.scratch/test-gaps/` maps that code, ranked by what a bug would
cost the person using the shell.

## The ceiling is 40%

Test lines stay at or below 40% of code lines. That is a ceiling. Nobody gains
from climbing toward it, and a test is never written to move the number. A
test is written because a piece of code is risky, as the next section defines
it.

Measure from the repo root:

    git ls-files tests | xargs cat | wc -l
    git ls-files -- '*.qml' '*.js' '*.mjs' '*.sh' '*.py' '*.lua' cli/banditshell \
        ':!tests/**' ':!.scratch/**' ':!docs/**' ':!.claude/**' | xargs cat | wc -l

## What gets a test

Code where a mistake costs the user something they will not see right away:

- It writes outside the shell: `config.json`, the Hyprland config, sysfs, the
  package database, the user's own files. A bad write survives a restart.
- It parses another program's output (`nmcli`, `hyprctl`, `pacman`, `upower`,
  `bluetoothctl`). Keep a captured real output in `tests/fixtures/` and test
  against that, so a tool update that changes the format shows up as a failure.
- It builds a command line or a shell string. Quoting bugs hide until a file
  name has a space or a quote in it.
- It handles a secret: a password, the keyring, clipboard history.
- It does date, time or duration math.
- It ranks, matches or orders things the user picks from.
- It fixes a bug. The PR that fixes it carries the test that would have caught
  it.

## What does not

- Layout, animation, colour and springs. Look at those with
  `banditshell dev try` and a screenshot.
- Property bindings, and wrappers that start a process and pass its output
  through untouched.
- Counts and lists that grow every time a feature lands, unless the number is
  itself the promise (the settings list rows 1 to 121 are one).
- Grepping QML source for a string to prove a feature exists. A rule every file
  must follow is a lint rule in `scripts/lint-rules.js`, not a test.

## How

- Tests only run plain JavaScript. Logic inside a QML file gets a test by moving
  its pure functions into a `.js` file next to it, with `.pragma library` at the
  top, imported by the QML. `services/ranking.js` and `tests/ranking.test.js`
  show the whole pattern. The new file goes in its package's `module.json`
  under `owns.js`, or `banditshell dev modules` fails.
- Move only what has no QML in it: strings in, values out. A function that
  reads a singleton takes that value as an argument instead.
- Shell and Python scripts run from node with stub commands on `PATH`; see
  `tests/fixtures/cli-stubs.js`.
- One file per subject, `tests/<subject>.test.js`. Test names read as a
  sentence about behaviour: `ranks exact over prefix over word start`.
- The suite stays under a minute. A test that needs a real compositor, a real
  network or `sleep` does not belong in it.
