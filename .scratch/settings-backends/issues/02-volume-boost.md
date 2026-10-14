# Volume past 100% as a switch

Status: done

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

## Built

`volume.boost` (default on). `Audio.maxVolume` is 1.5 with it on and 1 off;
when it flips off while the volume is above 100%, `Audio` sets it to 100%. The
panel's volume row and the sound scene use `Audio.maxVolume` directly, so the
past-100 mark goes away with the switch.

Still to check by hand: turning it off with a real sink above 100%.
