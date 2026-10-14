# Idle: lock, screens off, sleep

Status: needs-triage

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
