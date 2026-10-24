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

## scripts/spicy-lyrics.py, scripts/find-qt.sh, scripts/in-terminal.sh

One test each for the main path: the right cache entry for a track, the probe
order for Qt tools, and the flags each terminal gets.
