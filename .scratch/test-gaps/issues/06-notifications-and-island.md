# Tests for which notification shows, sounds or goes away

Status: ready-for-agent
Tier: 2

The notification store, rules, timing and search are tested. What is not is
the decision layer above them: what is held, what pops up, what sounds, and in
what order the island shows it.

## services/Notifications.qml

Extract the held, popup, sound and timeout rules from `onNotification`,
`timeoutFor`, `setQuiet`, `drop` and `snooze` into a function of the incoming
notification, the settings and `now`. Test quiet hours, a muted app, a pinned
notification surviving a clear, and the expire timeout of 0, which the
freedesktop notification spec says means never and which `timeoutFor` treats
as the default (#114, waiting on the owner's call). Quickshell 0.3.2 passes the
timeout through in milliseconds, unchanged; pin that too.

## modules/island/Island.qml

`arrange`, `deckEntries` and `merged`: test which alert comes first when
several arrive together, that nothing is dropped when the deck is full, and
that a click opens the panel the alert belongs to.

## modules/island/AlertDeck.qml

`cards`, `part`, `toggle` and `clearAll`: test collapsed groups, that a sweep
removes only what was swept, and that a tap opens a notification and never
dismisses it; only a swipe or the close button removes one.

## modules/ipc/NotificationsIpc.qml

`held`, `list` and `oneLine`: the audit says `held()` answers with the hover
state, not the held notifications. Check, file if true, and test the IPC
answers against a fixed store.
