# On-screen keyboard: key repeat on and off

Status: done

Row: Input › Tablet › Held keys repeat `boardRepeat`. The mockup maps it to
`tablet.repeatDelay`, but a delay of 0 makes `modules/keyboard/TabletKey.qml`
fire on every frame, so there is no off today.

## What to build

- Key `tablet.repeat` (bool, default true).
- `TabletKey.qml`: do not start the delay timer when it is off.
- Keep `tablet.repeatDelay` and `tablet.repeatInterval` as they are; the row's
  detail already reads them ("500 ms, then every 45").

## Done when

Holding a key on the on-screen board types once with the switch off.

## Built

`tablet.repeat` (default on). `TabletKey` only starts the delay timer when it is
on, so a held key types once with it off. The row's detail now reads the
configured `tablet.repeatDelay` and `tablet.repeatInterval` rather than the
default delay.

Still to check by hand: holding a key on the real board with the switch off.
