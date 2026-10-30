-- banditshell: example Hyprland binds, written against the stable API.
--
-- Copy the lines you want into your own bind file, for example
-- ~/.config/hypr/lua/binds.lua. The first line loads the module. It needs
-- the file banditshell.lua that `banditshell doctor api` (and install.sh)
-- places beside your hyprland.lua; that file is banditshell's, never edit it.
--
-- A name like bs.launcher.toggle is an action id. It is not a command line:
-- when the key is pressed, the banditshell checkout you have installed turns
-- the id into whatever command it stands for today. The command line can be
-- reshaped by an update and these lines keep working. `banditshell api list`
-- prints every id and what it does; `banditshell api show <id>` shows one.
--
-- Pass an action, never call it: hl.bind(keys, bs.launcher.toggle) is right,
-- bs.launcher.toggle() would run the action while the config loads.
-- An action that takes arguments is called with them once, and the result is
-- what gets bound: bs.wallpaper.set("/path/to/file.png").
-- A name that does not exist never stops the config; it shows a notice once.

local bs = require("banditshell")
bs.need(1)

-- Panels. Toggles, so the key that summoned a panel also puts it away.
hl.bind("SUPER + SPACE", bs.launcher.toggle)
hl.bind("SUPER + V", bs.panel.clipboard.toggle)
hl.bind("SUPER + ESCAPE", bs.panel.session.toggle)
hl.bind("SUPER + I", bs.panel.settings.toggle)
hl.bind("SUPER + N", bs.panel.notifications.toggle)
hl.bind("SUPER + C", bs.panel.calendar.toggle)
hl.bind("SUPER + M", bs.panel.media.toggle)
hl.bind("SUPER + SHIFT + M", bs.panel.island.toggle)
hl.bind("SUPER + K", bs.panel.calculator.toggle)
hl.bind("XF86Calculator", bs.panel.calculator.toggle, { locked = true })
hl.bind("SUPER + E", bs.panel.files.toggle)

-- The rescue: every panel and menu away.
hl.bind("SUPER + SHIFT + ESCAPE", bs.panel.close)

-- The sidebar menus, by key. `banditshell panel` lists every name.
hl.bind("SUPER + A", bs.panel.audio.toggle)
hl.bind("SUPER + W", bs.panel.network.toggle)
hl.bind("SUPER + B", bs.panel.bluetooth.toggle)
hl.bind("SUPER + SHIFT + B", bs.panel.battery.toggle)

-- The hotkey sheet. Which key is a question mark depends on your layout:
-- SHIFT + slash on US and UK, SHIFT + plus on Danish and Swedish.
hl.bind("SUPER + SHIFT + slash", bs.panel.hotkeys.toggle)

-- The sidebar column, and the whole chrome on or off.
hl.bind("SUPER + Z", bs.screen.sidebar.toggle)
hl.bind("SUPER + SHIFT + K", bs.screen.border.toggle)

-- Time. The ten minutes is an example, not a setting.
hl.bind("SUPER + T", bs.panel.clock.toggle)
hl.bind("SUPER + CTRL + T", bs.clock.timer.start("10m"))
hl.bind("SUPER + SHIFT + T", bs.clock.timer.toggle)
hl.bind("SUPER + ALT + T", bs.clock.alarm.snooze)

-- Screenshots.
hl.bind("SUPER + P", bs.screenshot.save)
hl.bind("SUPER + SHIFT + P", bs.screenshot.save_frozen)
hl.bind("SUPER + CTRL + P", bs.screenshot.copy)

-- The wallpaper the shell draws, and its picker.
hl.bind("SUPER + SHIFT + W", bs.wallpaper.toggle)
hl.bind("SUPER + CTRL + W", bs.wallpaper.next)
hl.bind("SUPER + ALT + W", bs.panel.wallpaper.toggle)

-- Where the sound comes out. Needs `banditshell output assign` once.
hl.bind("SUPER + O", bs.output.toggle)

-- Focus modes and quiet notifications.
hl.bind("SUPER + F", bs.focus.quiet.toggle)

-- Tablet mode from the hinge switch of a convertible. Your switch has its own
-- name: `hyprctl devices` prints it under Switches.
local switch = "Lenovo Yoga Tablet Mode Control switch"
hl.bind("switch:on:" .. switch, bs.action("tablet.on", "compositor"), { locked = true })
hl.bind("switch:off:" .. switch, bs.action("tablet.off", "compositor"), { locked = true })

-- bs.bind is hl.bind that also fills in the description from the action table,
-- which is what Hyprland's own bind list shows.
bs.bind("SUPER + SHIFT + A", "panel.close")

-- Your own function can run several actions.
hl.bind("SUPER + SHIFT + Z", function()
    bs.run("screen.border.toggle")
    bs.run("wallpaper.toggle")
end)

-- Starting the shell from your own autostart without banditshell on PATH:
-- hl.on("hyprland.start", function() hl.exec_cmd(bs.cli() .. " start") end)

-- Not the shell's: volume and mute are wpctl's, the media keys playerctl's.
-- `session.lock` asks logind, and locks the shell itself without it.
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
hl.bind("SUPER + L", bs.session.lock)
