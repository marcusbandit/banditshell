# Accessibility: less motion, larger text, more contrast

Status: done

Rows: System › Accessibility › Less motion `reduceMotion`, Larger text
`largerText`, More contrast `contrast`. The panel already honours less motion
in its own previews.

## What to build

- Keys `access.lessMotion`, `access.largerText`, `access.moreContrast`.
- `config/Appearance.qml`: larger text uses base 11 in place of `font.base`;
  more contrast uses label alphas 0.96, 0.8, 0.68, 0.24; less motion makes
  `Follow` snap and shortens `anim.*` to near zero (keep opacity fades).
- The Text size row is disabled while larger text is on (the panel already does
  this).

## Built

Keys `access.lessMotion`, `access.largerText`, `access.moreContrast`, plus the
tunables `access.largerBase` (11), `access.contrastLabel` (0.96, 0.8, 0.68,
0.24) and `access.stillMs` (1). `config/Appearance.qml` reads them, so the whole
shell follows with no per-widget work.

- Larger text replaces the font base everywhere (`Appearance.fontBase`), more
  contrast replaces the label alphas (`Appearance.labelAlphas`).
- Less motion: `animation.fast/normal/slow` become `stillMs`, `Follow` and the
  workspace model snap, the wallpaper reveal is a cut, and the decorative
  battery loops stop.
- Opacity fades keep their length: the 38 opacity animations now read
  `Appearance.animation.fade.*`, which is the unscaled tier. Colour fades go
  instant with the rest. The looping activity indicators (mic, battery) use
  the unscaled tier too, so a near-zero duration never makes them strobe.
- The panel's own previews read the real key through `SettingsState` (the key
  is config-backed now); the Text size and Pace rows are disabled as before.

Still to check by a person: an hour of normal use with less motion on, for
anything that still slides or that looks wrong when snapped; larger text on the
tablet board and the lock face, where text is already big.
