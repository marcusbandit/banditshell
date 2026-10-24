# Tests for the launcher's choices between rows

Status: ready-for-agent
Tier: 2

The launcher's helpers are well tested (`tests/launcher-*.test.js`). The
choices made in the QML on top of them are not: which row wins, what a key
does to it, and what gets remembered.

## services/LauncherMemory.qml

`record` moves as it is with the decay passed in. Test that the newest key
stays once 400 are stored (#109), and that `forget` removes only its key.

## services/Apps.qml

`search`, `tier`, `nameVariants` and `frecencyAt`: test the ranking order for
exact, prefix, word and anywhere matches mixed with frequent apps. Check the
audit's note that `brandFor` anchors some patterns and not others, so
`org.mozilla.firefox` misses and `spider` matches `rider`.

## modules/launcher/LauncherSearch.qml

`activate` sends each row kind to its action. Give every kind its own name
(#111) and test the dispatch table: every kind a row builder emits has exactly
one action. Test `arrangement` and `windowRows`, where the audit says the
focused window sorts last.

## modules/launcher/ListLauncher.qml

`claimKey` and `stepRow`: test wrap-around and empty lists, and check the
audit's claim that Ctrl+Enter on a process row force quits with no
confirmation. If it does, decide whether it should and test the answer.

## modules/launcher/sources/PortSource.qml and AlphabetLauncher.qml

`actionsFor` for a user process, a root process and a systemd unit. In the
alphabet launcher, `rows` and `scrubAt`: test which letter an app with a
leading digit, an accent or an emoji is filed under.

## modules/ipc/ClockIpc.qml

`pickTimer` and `pickAlarm`: test that a command picks the right timer when
several share a label.
