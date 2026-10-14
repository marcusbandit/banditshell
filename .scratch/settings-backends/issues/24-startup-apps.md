# Startup apps

Status: done

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

## Built

`services/StartupApps.qml` lists and switches all three sources in place. `startup-apps.js` and `desktop-entries.js` hold the parsing, tested in node (`tests/startup-apps.test.js`, `tests/desktop-entries.test.js`). Decision: the list is read from the system, not kept in config.

- Hyprland: every single-line `hl.exec_cmd("...")` in every scanned Lua file, except session plumbing (`systemctl ...`, `dbus-update-activation-environment`). Off comments the line (`-- hl.exec_cmd(...)`), on removes the comment, through `HyprConfig.commit` (verified, reverted on failure) and behind `sourceEdits`. A `shell-up` line is split into one row per app: off drops that argument and remembers it in a trailing `-- off: 'qbittorrent --no-splash'`, on puts it back. The wrapper line itself is never commented out, because it starts the shell. Toggling affects the next login, not the running session.
- systemd: user services that are enabled, or the user's own disabled ones, whose ExecStart runs an installed desktop entry (so vesktop shows, tmux and the diablo units do not). `systemctl --user enable|disable`, never `--now`.
- XDG autostart: `~/.config/autostart/*.desktop` for this desktop (OnlyShowIn and NotShowIn honoured). Off sets `Hidden=true` in that file, on sets it false. Add writes a new file named after the chosen desktop entry; remove deletes the file (undo writes it back). Only these rows can be removed.
- Nothing runs XDG autostart on this Hyprland session (no uwsm or dex, and `xdg-desktop-autostart.target` is inactive), so the shell launches the enabled entries itself once per session. `StartupApps` is referenced from `shell.qml` so it runs at boot. The guard is a directory `$XDG_RUNTIME_DIR/banditshell-autostart-$HYPRLAND_INSTANCE_SIGNATURE`; it also stands down when `xdg-desktop-autostart.target` is active, and does nothing outside Hyprland. Entries with `Terminal=true` are listed but not launched.
- Each row says where it comes from (hyprland, systemd, autostart); the "Add an app" row says how many of the listed apps start.

Still to check by a person: the first time this lands in the live session, remmina-applet (the one entry in `~/.config/autostart`) starts once, since nothing started it before. Not listed: `autostart-launcher.service` starts what is in `~/.config/autostart-managed/` (claude-launcher, spotify), a fourth source outside the three this ticket names. Systemd enable and disable were not run on the live machine; the listing was checked read-only and the write path is two lines.
