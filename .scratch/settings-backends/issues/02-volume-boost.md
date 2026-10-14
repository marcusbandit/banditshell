# Volume past 100% as a switch

Status: ready-for-agent

Row: Sound › Output › Past 100% `overAmp`. Planned default is on, because the
shell allows 150% today (`Audio.maxVolume` is a fixed 1.5).

## What to build

- Key `volume.boost` (bool, default true).
- `services/Audio.qml`: `maxVolume` is 1.5 when on, 1 when off. `quantise` and
  every slider already clamp to it, so the sidebar, the sound menu and the
  keybind step follow.
- Turning it off while above 100% should bring the volume down to 100%.

## Done when

With it off, no control can push past 100%; the panel's slider loses its mark.
