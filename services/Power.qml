pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The ways a session can end, and how each one is actually done.
//
// Here rather than inside either thing that draws it. The panel on the right
// edge and the power menu parked for the dashboard offer the same five choices,
// and a list of ways to lose your work that exists in two files is a list that
// will eventually disagree with itself about which one reboots.
//
// `safe` is the whole safety model: it marks the actions that cost nothing to
// get wrong. Everything else is expected to ask first, and it is the caller that
// asks, because what a confirmation looks like belongs to the thing being
// clicked, not to this table.
Singleton {
    id: root

    readonly property var actions: [
        {
            key: "lock",
            icon: "lock",
            label: "Lock",
            detail: "",
            // Locking is harmless and instant, so it is the one that does not ask.
            safe: true,
            command: ["loginctl", "lock-session"]
        },
        {
            key: "suspend",
            icon: "bedtime",
            label: "Suspend",
            detail: "sleep to RAM",
            safe: true,
            command: ["systemctl", "suspend"]
        },
        {
            key: "logout",
            icon: "logout",
            label: "Log out",
            detail: "ends this session",
            command: ["loginctl", "terminate-user", ""]
        },
        {
            key: "reboot",
            icon: "restart_alt",
            label: "Restart",
            detail: "",
            command: ["systemctl", "reboot"]
        },
        {
            key: "poweroff",
            icon: "power_settings_new",
            label: "Shut down",
            detail: "",
            command: ["systemctl", "poweroff"]
        }
    ]

    function actionFor(key: string): var {
        return root.actions.find(a => a.key === key) ?? null;
    }

    function run(entry: var): void {
        const cmd = entry.command.slice();
        // terminate-user needs the actual user, and hardcoding a name in a
        // config file is how a power menu ends up logging out someone else.
        if (entry.key === "logout")
            cmd[2] = Quickshell.env("USER");
        runner.command = cmd;
        runner.running = true;
    }

    Process {
        id: runner
    }
}
