pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

// Wi-Fi. This one is real.
//
// Scanning runs while this is on screen and stops when it is not, which is why
// it is tied to the component's lifetime rather than to a button: a menu you can
// see is the only time the list needs to be fresh, and a radio scanning in the
// background is a laptop's battery going somewhere.
Column {
    id: root

    // A secured network you have never joined needs a password, and the place to
    // ask is the row you just pressed. Only one row can be asking at a time.
    property string asking: ""

    spacing: Appearance.padding.small

    // Scanning stops while a passphrase is being typed.
    //
    // `networks` is derived from every AP's signal strength, so a scan result
    // re-evaluates it, and a Repeater over a plain array rebuilds every delegate
    // when it does. That destroyed the password field mid-word, every couple of
    // seconds, along with its keyboard focus. Freshness is worth nothing while
    // someone is answering a prompt.
    readonly property bool scanning: !root.asking
    onScanningChanged: Network.watch(scanning)

    Component.onCompleted: Network.watch(root.scanning)
    Component.onDestruction: Network.watch(false)

    MenuRow {
        width: root.width
        icon: Network.enabled ? "wifi" : "wifi_off"
        label: "Wi-Fi"
        detail: !Network.available ? "no adapter" : !Network.hardwareEnabled ? "blocked by hardware switch" : Network.connected ? Network.activeName : "not connected"
        interactive: Network.available && Network.hardwareEnabled
        onActivated: Network.setEnabled(!Network.enabled)

        Toggle {
            checked: Network.enabled
            onToggled: Network.setEnabled(!Network.enabled)
        }
    }

    Separator {
        width: parent.width
        visible: Network.enabled
    }

    // The list. Capped, because a flat is a dozen networks and a street is
    // eighty, and a menu that scrolls forever is worse than one that says how
    // many it left out.
    Repeater {
        model: Network.enabled ? Network.networks.slice(0, Appearance.sizes.networkListMax) : []

        delegate: Column {
            id: entry

            required property var modelData

            width: root.width
            spacing: 0

            MenuRow {
                width: parent.width
                // No icon: the meter on the right says everything an icon would,
                // and says it comparably down the column.
                label: entry.modelData.name
                detail: entry.modelData.connected ? "connected" : entry.modelData === Network.connecting ? "connecting" : `${Network.securityLabel(entry.modelData)}${entry.modelData.known ? ", saved" : ""}`
                selected: entry.modelData.connected

                onActivated: {
                    const n = entry.modelData;
                    if (n.connected)
                        return n.disconnect();
                    // Known networks already have the secret; only a stranger
                    // with security on has to be asked.
                    if (n.known || !Network.secured(n))
                        return n.connect();
                    root.asking = root.asking === n.name ? "" : n.name;
                }

                Row {
                    spacing: Appearance.padding.small

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: Network.secured(entry.modelData)
                        name: "lock"
                        color: Appearance.colour.textFaint
                        font.pixelSize: Appearance.font.size.small
                    }

                    SignalBars {
                        anchors.verticalCenter: parent.verticalCenter
                        strength: Network.percent(entry.modelData)
                        activeColour: entry.modelData.connected ? Appearance.colour.text : Appearance.colour.textDim
                    }
                }
            }

            PasswordField {
                width: parent.width
                visible: root.asking === entry.modelData.name
                placeholder: `password for ${entry.modelData.name}`

                onAccepted: secret => {
                    entry.modelData.connectWithPsk(secret);
                    root.asking = "";
                }
                onCancelled: root.asking = ""
            }
        }
    }

    StyledText {
        visible: Network.enabled && Network.networks.length > Appearance.sizes.networkListMax
        text: `+${Network.networks.length - Appearance.sizes.networkListMax} more`
        color: Appearance.colour.textFaint
        font.pixelSize: Appearance.font.size.small
    }

    StyledText {
        visible: Network.enabled && !Network.networks.length
        text: "scanning"
        color: Appearance.colour.textFaint
        font.pixelSize: Appearance.font.size.small
    }
}
