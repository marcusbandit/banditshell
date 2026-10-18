import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.settings

Column {
    id: root

    readonly property var d: Bluetooth.deviceAt(SettingsView.pin?.id ?? "")
    readonly property string st: !root.d ? "" : root.d.blocked ? "blocked" : root.d.connected ? "on" : (root.d.paired || root.d.bonded) ? "paired" : "near"
    readonly property bool busy: !!root.d && (!!root.d.pairing || Bluetooth.stateLabel(root.d) === "connecting")

    spacing: Appearance.padding.card

    Item {
        width: parent.width
        height: 180

        SquircleRect {
            anchors.fill: parent
            radius: Appearance.rounding.large
            color: Appearance.colour.fill
        }

        Icon {
            anchors.centerIn: parent
            name: root.d ? Bluetooth.icon(root.d) : "bluetooth"
            size: Appearance.icon.hero
            color: Appearance.colour.text
        }
    }

    SettingsFacts {
        width: parent.width
        facts: {
            if (!root.d)
                return [["state", "gone"]];
            const out = [["state", root.busy ? "connecting" : ({
                            on: "connected",
                            paired: "paired",
                            near: "nearby",
                            blocked: "blocked"
                        })[root.st]]];
            if (root.d.batteryAvailable)
                out.push(["battery", `${Math.round(root.d.battery * 100)}%`]);
            out.push(["trusted", root.d.trusted ? "yes · joins without asking" : "asks first"]);
            return out;
        }
    }

    Flow {
        width: parent.width
        spacing: Appearance.padding.small
        visible: !!root.d

        Button {
            visible: root.st === "blocked"
            size: 0
            text: "Unblock"
            onClicked: Bluetooth.setBlocked(root.d, false)
        }

        Button {
            visible: root.st !== "blocked"
            size: 0
            style: "accent"
            interactive: !root.busy
            text: root.st === "on" ? "Disconnect" : root.st === "near" ? "Pair" : "Connect"
            onClicked: {
                const name = root.d.name;
                const was = root.st;
                Bluetooth.toggleDevice(root.d);
                if (was === "on")
                    SettingsView.drop(`${name} disconnected`, "bluetooth");
            }
        }

        Button {
            visible: root.st === "on" || root.st === "paired"
            size: 0
            text: root.d?.trusted ? "Stop trusting" : "Trust"
            onClicked: Bluetooth.setTrusted(root.d, !root.d.trusted)
        }

        Button {
            visible: root.st === "on" || root.st === "paired"
            size: 0
            style: "ring"
            text: "Forget"
            onClicked: {
                const name = root.d.name;
                Bluetooth.forget(root.d);
                SettingsView.unpin();
                SettingsView.drop(`forgot ${name}`, "delete");
            }
        }

        Button {
            visible: root.st !== "blocked"
            size: 0
            style: "ring"
            alarm: true
            text: "Block"
            onClicked: {
                const name = root.d.name;
                Bluetooth.setBlocked(root.d, true);
                SettingsView.drop(`blocked ${name}`, "block");
            }
        }
    }
}
