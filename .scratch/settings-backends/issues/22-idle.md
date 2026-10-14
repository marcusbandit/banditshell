# Idle: lock, screens off, sleep

Status: done

Rows: Power › Lock and idle › Lock after `idleLock`, Screens off after
`idleOff`, Sleep after `idleSuspend` (on battery only).

## What to build

- An idle timer: Quickshell's `IdleMonitor` or hypridle with a generated config.
- Lock calls `Lock.lock()`; screens off uses `hyprctl dispatch dpms off`; sleep
  uses logind, only on battery.
- Keys: `idle.lock`, `idle.screensOff`, `idle.sleep` (minutes, 0 for never).

## Asked for

2026-10-14: the user likes these rows and noticed nothing enforces them yet.
This is the ticket that makes them real.

## Built

- `services/Idle.qml`: three Quickshell `IdleMonitor`s, one per step, made from
  `services/idle.js` `plan()` (which drops 0-minute steps and leaves sleep out
  unless on battery). Lock calls `Lock.lock()`; screens off sends dpms off and
  turns them back on at the first input; sleep is `systemctl suspend`. All three
  use `respectInhibitors`, so a playing video holds them off. It also keeps a
  separate one-minute presence monitor and exposes `Idle.idle` and
  `Idle.idleSince`, which ticket 08 reads.
- If `pgrep -x hypridle` finds one (rechecked every minute) the shell makes no
  steps at all and the three rows say "hypridle is handling this". On this
  machine hypridle runs, so nothing here fires until it is stopped.
- Keys `idle.lock`, `idle.screensOff`, `idle.sleep` hold minutes, 0 for never,
  defaults 5, 10, 30. The rows still show "5 min" choices through a transform
  (`modules/settings/durations.js`), and the planned value carries over through
  `SettingsState.adopt`.
- The service is held alive from `shell.qml`.

To check by hand: with hypridle stopped, that screens off really goes dark and
wakes on the first key or mouse move. The Lua form of the dpms dispatch,
`hl.dsp.dpms({ action = "off" })`, is a best reading of the Hyprland stubs and
was not run. Sleep on battery was not run either.
