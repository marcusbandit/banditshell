# Alert sounds

Status: needs-triage

Rows: Sound › Alerts and media › Alert sounds `alerts`, Sound set `alertSet`
(soft, clear, wood), Alert volume `alertVol`.

## What to build

- A small player (pw-play or QtMultimedia) in a new service, with three sound
  sets shipped in the repo.
- Hooks: a notification arriving (respecting do not disturb and per-app rules),
  low battery, and errors the shell reports.
- Keys: `sound.alerts`, `sound.alertSet`, `sound.alertVolume`.

## To decide

The sounds themselves.
