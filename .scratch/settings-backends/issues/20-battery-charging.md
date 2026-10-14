# Battery charging: hold the charge, warning, nearly empty

Status: done

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

## Built

- Keys `battery.holdCharge` (true), `battery.holdAt` (80), `battery.warnAt`
  (15), `battery.nearlyEmpty` ("suspend", "hibernate" or "nothing"), in
  `config/Config.qml`, served through `configBacked`. The row still shows
  "suspend at 5%"; a transform turns that into the stored word, so an old
  planned value carries over by itself.
- Hold the charge: `services/ChargeLimit.qml`. It reads
  `charge_control_end_threshold` (world-readable) every 30 s, and writes the
  wanted value (`holdAt`, or 100 when `holdCharge` is off) through
  `pkexec /usr/local/libexec/banditshell-charge-limit <n>` whenever the
  battery disagrees, which also re-asserts it after firmware resets on resume.
  If the firmware keeps a different number, it stops retrying that number and
  the row says so.
- The helper is `scripts/charge-limit.sh` plus the polkit action
  `assets/polkit/org.banditshell.charge-limit.policy` (active local session
  only, no password). The helper accepts one number from 50 to 100 and
  writes only to `BAT*/charge_control_end_threshold`; nothing is made
  world-writable. Installed by `install.sh --charge-limit`, which is opt-in,
  explains itself in `--help`, installs polkit if missing, and skips on a
  machine whose battery has no threshold.
- The row says why when it cannot hold: "needs the helper · run bash
  .../install.sh --charge-limit", or "this battery has no charge limit in its
  firmware" (which also greys the row and the hub tile).
- Warn at: `Battery.lowThreshold` is the key; the re-arm margin stays 5 points
  above it.
- Nearly empty: at 5% on battery the shell notifies "Battery nearly empty",
  counts down 30 s, and runs `systemctl suspend` or `hibernate`. Plugging in
  during the countdown cancels it. After acting it waits for a resume before
  it will count down again. Hibernate is greyed (and falls back to suspend)
  unless `/sys/power/state` has `disk` and logind's `CanHibernate` says yes.
  The steps are pure in `services/battery.js`, tested in `tests/power.test.js`.

### A person with a laptop must check

- Run `bash install.sh --charge-limit`, then slide "Stop at" and read
  `cat /sys/class/power_supply/BAT*/charge_control_end_threshold`. Toggle
  "Hold the charge" off and it should read 100.
- That the threshold is set again after a suspend and resume, and after a
  reboot (start the shell).
- Firmware that has the attribute but ignores the number (some only take
  fixed steps): the row should say where it stayed.
- Set "Warn at" to 30 and discharge: one notification. At 5% on battery:
  the countdown notification, then suspend; plug in during the 30 s and
  nothing should happen.
- Hibernate: the choice should be greyed without swap and `resume=`.
