# Tests for the helper scripts and the code highlighter

Status: ready-for-agent
Tier: 3

Lower stakes: a wrong colour, a stuck pen button, a missed lyric. Each one
gets a test when a bug turns up in it, or when someone is already in the file.

## components/highlight.js

Already plain JavaScript, so a test costs nothing to set up. Test that an
unterminated string does not colour the rest of the block, escapes at the end
of a string, CRLF line ends, and language detection from a shebang.

## scripts/browser-cookies.py

Test which browser's cookies are read for each default browser, and that it
never falls back to Firefox's cookies when the user picked another browser.

## scripts/pen-pad.py

`handle`: test that held buttons are released when the pad disconnects.

## scripts/palette.py and scripts/wallpaper-colours.py

Test the clustering and hue bins against a few small fixed images, and that
the colour cache is reused when the file has not changed.

## scripts/cpu-temperature.sh

It picks a sensor from sysfs: Package id 0, then Tctl, Tdie, then acpitz.
Give it a root folder override so a test can hand it a fake sysfs, and test
the order.

## scripts/github-summary.sh

Test the exit codes when `gh` is missing or signed out, and that one failed
query leaves the rest of the summary instead of an empty panel.

## scripts/tablet-state.py and scripts/pick-file.py

In tablet-state, the bit test and the ioctl numbers, which are plain
arithmetic. In pick-file, the picked, cancelled and no-chooser exit codes, with
the portal and `gi` stubbed out.

## scripts/spicy-lyrics.py, scripts/find-qt.sh, scripts/in-terminal.sh

One test each for the main path: the right cache entry for a track, the probe
order for Qt tools, and the flags each terminal gets.
