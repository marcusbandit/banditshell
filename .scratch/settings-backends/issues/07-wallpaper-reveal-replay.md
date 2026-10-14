# Wallpaper: replay the reveal

Status: done

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

## Built

`Wallpaper.replayOn(screen, x, y)` sets the origin and emits `replayRequested`.
`WallpaperWindow` listens for its own screen and calls the new
`WallpaperView.replay()`, which empties the back slot, picks a fresh seed and
restarts the sweep, so the current picture grows out of black at the configured
length. `previewReveal` maps the tool's centre to fractions of the settings
window and replays on every screen when the wallpaper target is "everywhere", or
on the settings screen otherwise.

The ticket put the listener in `WallpaperWindow`; the slots and the sweep belong
to `WallpaperView`, so the window only forwards. To check by hand: the shader
does not render offscreen, so the look of the replay is unverified.
