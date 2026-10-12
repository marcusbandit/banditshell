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
            detail: "",
            command: ["sh", "-c", "session=\"${XDG_SESSION_ID:-$(loginctl show-user \"$(id -u)\" -p Display --value)}\"; [ -n \"$session\" ] || exit 1; exec loginctl terminate-session \"$session\""]
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
        runner.command = entry.command;
        runner.running = true;
    }

    Process {
        id: runner
    }
}
