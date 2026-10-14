# Battery charging: hold the charge, warning, nearly empty

Status: ready-for-human

Rows: Power › Battery › Hold the charge `chargeLimit`, Stop at `chargeMax`,
Warn at `lowWarn`, Nearly empty `lowAction`.

## What to build

- Charge limit: write `charge_control_end_threshold` under
  `/sys/class/power_supply/BAT*/` where the firmware supports it. It needs root:
  a polkit rule or a small udev/systemd helper installed by the installer.
- Warn at: `services/Battery.qml` already warns; make its threshold the key.
- Nearly empty: suspend or hibernate at 5% via logind.
- Keys: `battery.holdCharge`, `battery.holdAt`, `battery.warnAt`,
  `battery.nearlyEmpty`.

Needs a laptop to verify.
