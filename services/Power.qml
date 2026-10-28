pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "suspension.js" as Sleep

Singleton {
    id: root

    readonly property var actions: [
        {
            key: "poweroff",
            icon: "power_settings_new",
            label: "Shut down",
            detail: "",
            logind: true,
            command: Sleep.logindCommand("poweroff")
        },
        {
            key: "reboot",
            icon: "autorenew",
            label: "Restart",
            detail: "",
            logind: true,
            command: Sleep.logindCommand("reboot")
        },
        {
            key: "logout",
            icon: "logout",
            label: "Log out",
            detail: "",
            command: Sleep.logoutCommand()
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
        if (entry.key === "lock" && !SessionControl.logind) {
            SessionControl.requestLock();
            return;
        }
        if (entry.logind && SessionControl.lacksLogind(entry.label))
            return;
        Config.flush();
        runner.command = entry.command;
        runner.running = true;
    }

    Process {
        id: runner
    }
}
