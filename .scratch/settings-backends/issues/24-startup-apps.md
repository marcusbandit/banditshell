# Startup apps

Status: ready-for-agent

Row: Apps › Startup apps `startup` (list with switches, remove, add). Renamed from "At sign-in" on 2026-10-14.

## What to build

- Read and write `~/.config/autostart/*.desktop` (XDG autostart), with
  `Hidden=true` for apps that are off; Hyprland users may launch these with
  `dex` or the shell itself on start.
- Or keep the list in config and launch from the shell on start; decide which.

## What actually starts on this machine (2026-10-14)

The list is empty today because nothing reads these yet. On the user's desktop
the apps that start come from three places, so the list has to read all of them:

- Hyprland's Lua config, `~/.config/hypr/lua/autostart.lua`: `hl.exec_cmd(...)`
  lines. qBittorrent and Spotify start here through a wrapper,
  `~/.config/hypr/scripts/shell-up 'qbittorrent --no-splash' spotify`, so one
  line can be several apps. Others: clipse, udiskie, zen-pseudo-manager.
- systemd user units: `vesktop.service` is enabled (Vesktop starts here), with
  `autostart-launcher.service` running `~/.local/bin/autostart-launcher`.
- XDG autostart: `~/.config/autostart/` holds only `remmina-applet.desktop`.

Switching an app off means a different thing in each: comment the exec line
through HyprConfig (behind `sourceEdits`), `systemctl --user disable`, or
`Hidden=true` in an override under `~/.config/autostart`.
