local host = require("lua.host")

hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
        .. " && systemctl --user start xdg-desktop-portal-hyprland hypridle")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")

    hl.dispatch(hl.dsp.focus({ workspace = 1 }))
    hl.exec_cmd("clipse -listen")

    hl.exec_cmd("~/.config/hypr/scripts/shell-up 'qbittorrent --no-splash' spotify")

    hl.exec_cmd("~/.local/bin/zen-pseudo-manager") -- keeps the pseudo window
    -- hl.exec_cmd("udiskie")

    if host.is("banditbox") then
        hl.exec_cmd("~/Projects/diablo/deploy/tmux-start.sh")
    end
end)

hl.bind("SUPER + T", hl.dsp.exec_cmd("foot"))
