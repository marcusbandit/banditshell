# Wallpaper: replay the reveal

Status: ready-for-agent

Row: Look › Wallpaper › Reveal, its "play it" tool. It shows a not-built toast
today.

## What to build

- `services/Wallpaper.qml`: `replayOn(screen, x, y)` sets the origin and emits
  a signal.
- `modules/WallpaperWindow.qml`: on that signal for its screen, empty the back
  slot and restart the sweep so the current picture grows out again from the
  point.
- `SettingsActions.qml` `previewReveal`: map the tool's centre to fractions of
  the window and call it.

## Done when

The button replays the reveal at the configured length, from the button.
