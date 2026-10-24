# Tests for alarms, schedules and anything that counts time

Status: ready-for-agent
Tier: 2

Time bugs hide until a clock change, midnight or a restart. Every function
below should take `now` as an argument, so a test can set it.

## services/Clock.qml

`sweepAlarms`, `adopt`, `applyOffsets` and `toggleTimer`. Test that an alarm
that came due while the shell was down rings once at start and is not armed
again, that a repeating alarm moves to its next day across a daylight saving
change, and that a paused timer resumes with the time it had left.

## services/Display.qml

`evaluateSchedule`: test the warmth schedule across midnight, at the exact
switch minute and after the machine sleeps through a switch. The level sender
gives up after repeated failures; test that it recovers once a write succeeds.

## services/Usage.qml

`forDay`, `absorb` and `prune`: test a session that crosses midnight, two
shells merging their spans, and that pruning keeps the days the screen time
page shows. `UsageApps.qml` needs nothing: its pruning is in `usage-apps.js`,
which `tests/screen-time.test.js` already loads.

## services/Pomodoro.qml

`start`, `skip` and `reconcile`: test that a restart in the middle of a phase
resumes it with the right length, and that skipping a break starts the next
focus phase.

## services/Battery.qml

`dayKey`, `record` and `absorbLog`: test that health history keeps one sample
a day and survives a corrupt log line. `timeLabel` moves as it is.
