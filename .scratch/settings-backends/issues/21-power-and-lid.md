# Power profile and lid

Status: ready-for-human

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
