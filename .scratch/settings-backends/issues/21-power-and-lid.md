# Power profile and lid

Status: done

Rows: Power › Power and lid › Power mode `profile` (saver, balanced, fast), On
battery `lidBattery`, Plugged in `lidPlugged`, With screens attached
`lidDocked`. The Saver tile on the Power hub and the play mode also set the
profile.

## What to build

- Power mode through `powerprofilesctl` (power-profiles-daemon) or tuned's
  equivalent; read the current profile back.
- Lid actions through logind (`HandleLidSwitch`, `HandleLidSwitchExternalPower`,
  `HandleLidSwitchDocked`); a drop-in needs root, or the shell inhibits the lid
  switch and acts itself.

## Machines without a lid

Since 2026-10-14 the panel hides the Lid group, and the page reads "Power",
when there is no `/proc/acpi/button/lid` and no built-in panel (eDP, LVDS,
DSI). The Battery page hides when there is no battery. The backend should
leave the lid switches alone on such machines.

## Built

- Power mode: `services/PowerProfile.qml`. It uses `powerprofilesctl` when
  power-profiles-daemon answers, else `tuned-adm` (saver is powersave, fast is
  throughput-performance; tuned's other profiles read back as the nearest
  of the three), else the row greys and says no daemon is installed. The
  profile is read back live (a `gdbus monitor` on the daemon, plus a 30 s
  poll), so changes by other tools show. It is not in config:
  `SettingsState` serves `profile` in `v()` and `write()`, so the Saver
  tile, the play mode and the Power hub keep working through
  `SettingsState.set("profile", ...)`. With no daemon a set is refused
  and not logged as a change. The row offers only the profiles the daemon lists.
- Lid: `services/Lid.qml`, no root. Only where there is a lid (the panel's
  old detection, now `Lid.present`: `/proc/acpi/button/lid` or an eDP, LVDS
  or DSI output; `SettingsState.hasLid` uses it). On such a machine the shell holds
  `systemd-inhibit --what=handle-lid-switch --mode=block` while it runs,
  watches logind's `LidClosed` (`gdbus monitor` plus `busctl
  get-property`), and on open-to-closed does what `power.lid.*` says:
  screens attached (any enabled non-built-in output) use `docked`, otherwise
  battery or mains. Actions are suspend, hibernate, lock (`Lock.lock()`) and
  nothing. A lid already closed when the shell starts does nothing. Without a
  lid, nothing runs and nothing is inhibited.
- Keys `power.lid.onBattery` ("suspend"), `power.lid.pluggedIn` ("lock"),
  `power.lid.docked` ("nothing"), in config and `configBacked`.
- `services/Suspension.qml` is the shared "suspend, hibernate or lock" with
  the hibernate check; the hibernate choice is greyed on the rows when it
  cannot work. The panel got a per-option `unavailable` on rows
  (`SettingsEntry.qml`).
- Pure parts in `services/lid.js`, `powerprofile.js`, `suspension.js`,
  tested in `tests/power.test.js`.

### A person with a laptop must check

- Close the lid on battery, on mains and with a monitor plugged in: each
  should do what its row says; with the shell stopped, logind's own
  behaviour should return.
- `systemd-inhibit --list` should show banditshell blocking
  `handle-lid-switch` while the shell runs.
- That a docked laptop with the lid closed and "nothing" keeps running, and
  that "lock" brings up the shell's lock screen.
- Change the profile with `powerprofilesctl set performance` and watch the
  row follow; on a tuned machine, check the three tuned names are right.
