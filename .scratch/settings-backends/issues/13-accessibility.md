# Accessibility: less motion, larger text, more contrast

Status: ready-for-agent

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
