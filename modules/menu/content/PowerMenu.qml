pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.components

// Power. This one is real, and it is the one menu that can lose your work.
//
// Every entry asks first. Not a modal, not an "are you sure" that trains people
// to click yes: the row itself becomes the confirmation, in place, and anything
// else you do cancels it. A power menu that acts on the first click is one
// mis-hover away from ending your session, and this one opens on hover.
Column {
    id: root

    property string arming: ""

    spacing: Appearance.padding.small

    // Disarm as soon as attention moves elsewhere.
    Component.onDestruction: root.arming = ""

    Process {
        id: runner
    }

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

    function run(entry: var): void {
        const cmd = entry.command.slice();
        // terminate-user needs the actual user, and hardcoding a name in a
        // config file is how a power menu ends up logging out someone else.
        if (entry.key === "logout")
            cmd[2] = Quickshell.env("USER");
        runner.command = cmd;
        runner.running = true;
        root.arming = "";
    }

    Repeater {
        model: root.actions

        delegate: MenuRow {
            id: row

            required property var modelData

            readonly property bool armed: root.arming === modelData.key

            width: root.width
            icon: row.armed ? "check" : modelData.icon
            label: row.armed ? `${modelData.label}, really?` : modelData.label
            detail: row.armed ? "press again" : modelData.detail
            selected: row.armed

            onActivated: {
                if (modelData.safe || row.armed)
                    root.run(modelData);
                else
                    root.arming = modelData.key;
            }
        }
    }

    StyledText {
        text: "hover elsewhere to cancel"
        visible: !!root.arming
        color: Appearance.colour.textFaint
        font.pixelSize: Appearance.font.size.small
    }
}
