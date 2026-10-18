pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    function logind(verb: string): var {
        return ["sh", "-c", 'if command -v systemctl >/dev/null 2>&1; then exec systemctl "$1"; fi; exec loginctl "$1"', "sh", verb];
    }

    readonly property var actions: [
        {
            key: "poweroff",
            icon: "power_settings_new",
            label: "Shut down",
            detail: "",
            command: root.logind("poweroff")
        },
        {
            key: "reboot",
            icon: "restart_alt",
            label: "Restart",
            detail: "",
            command: root.logind("reboot")
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
