pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property var actions: [
        {
            key: "poweroff",
            icon: "power_settings_new",
            label: "Shut down",
            detail: "",
            command: ["systemctl", "poweroff"]
        },
        {
            key: "reboot",
            icon: "restart_alt",
            label: "Restart",
            detail: "",
            command: ["systemctl", "reboot"]
        },
        {
            key: "logout",
            icon: "logout",
            label: "Log out",
            detail: "ends this session",
            command: ["loginctl", "terminate-user", ""]
        },
        {
            key: "lock",
            icon: "lock",
            label: "Lock",
            detail: "",

            safe: true,
            command: ["loginctl", "lock-session"]
        }
    ]

    function run(entry: var): void {
        const cmd = entry.command.slice();

        if (entry.key === "logout")
            cmd[2] = Quickshell.env("USER");
        runner.command = cmd;
        runner.running = true;
    }

    Process {
        id: runner
    }
}
