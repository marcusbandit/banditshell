pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

Column {
    id: root

    spacing: Appearance.padding.small

    property string opened: ""

    function toggleLayer(key: string): void {
        root.opened = root.opened === key ? "" : key;
    }

    property bool showing: false

    readonly property bool discovering: root.showing && root.opened === "pair"

    onDiscoveringChanged: Bluetooth.setDiscovering(root.discovering)

    onShowingChanged: if (!root.showing)
        root.opened = ""

    Component.onDestruction: Bluetooth.setDiscovering(false)

    component Choice: MenuRow {
        id: choice

        property bool on: false

        signal flipped

        onActivated: choice.flipped()

        Toggle {
            checked: choice.on
            onToggled: choice.flipped()
        }
    }

    component Act: MenuRow {}

    component Fact: StyledText {
        leftPadding: Appearance.padding.normal
        topPadding: Appearance.padding.small
        bottomPadding: Appearance.padding.normal
        color: Appearance.colour.textFaint
        font.pixelSize: Appearance.font.size.small
    }

    MenuRow {
        id: adapterRow

        width: root.width
        icon: Bluetooth.statusIcon()
        label: "Bluetooth"
        detail: !Bluetooth.available ? "no adapter" : !Bluetooth.enabled ? "off" : Bluetooth.anyConnected ? `${Bluetooth.connectedDevices.length} connected` : Bluetooth.discovering ? "scanning" : "on, nothing connected"
        interactive: Bluetooth.available
        onActivated: Bluetooth.setEnabled(!Bluetooth.enabled)

        Row {
            spacing: Appearance.padding.normal

            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                checked: Bluetooth.enabled
                onToggled: Bluetooth.setEnabled(!Bluetooth.enabled)
            }

            Expander {
                anchors.verticalCenter: parent.verticalCenter

                visible: Bluetooth.enabled
                open: root.opened === "adapter"
                tip: "adapter settings"
                onToggled: root.toggleLayer("adapter")
            }
        }
    }

    MenuLayer {
        width: root.width
        open: root.opened === "adapter" && Bluetooth.enabled

        Choice {
            label: "Scan for devices"
            on: Bluetooth.discovering
            onFlipped: Bluetooth.setDiscovering(!Bluetooth.discovering)
        }

        Choice {
            label: "Visible to others"
            on: Bluetooth.discoverable
            onFlipped: Bluetooth.setDiscoverable(!Bluetooth.discoverable)
        }

        Choice {
            label: "Allow new pairings"
            on: Bluetooth.pairable
            onFlipped: Bluetooth.setPairable(!Bluetooth.pairable)
        }

        Fact {
            text: Bluetooth.adapterName ? `${Bluetooth.adapterName} · ${Bluetooth.adapterId}` : Bluetooth.adapterId
        }
    }

    Separator {
        width: parent.width
        visible: Bluetooth.enabled
    }

    Repeater {

        model: Bluetooth.enabled ? Bluetooth.known.slice(0, Appearance.sizes.deviceListMax) : []

        delegate: Column {
            id: entry

            required property var modelData

            readonly property bool known: entry.modelData.paired || entry.modelData.bonded
            readonly property bool showing: root.opened === entry.modelData.address

            width: root.width
            spacing: 0

            MenuRow {
                width: entry.width
                icon: Bluetooth.icon(entry.modelData)
                label: entry.modelData.name || entry.modelData.address
                detail: Bluetooth.stateLabel(entry.modelData)
                selected: entry.modelData.connected

                onActivated: Bluetooth.toggleDevice(entry.modelData)

                Expander {
                    open: entry.showing
                    tip: "more"
                    onToggled: root.toggleLayer(entry.modelData.address)
                }
            }

            MenuLayer {
                width: entry.width
                open: entry.showing

                Choice {
                    label: "Connect on its own"
                    detail: entry.modelData.trusted ? "" : "asks every time"
                    on: entry.modelData.trusted
                    onFlipped: Bluetooth.setTrusted(entry.modelData, !entry.modelData.trusted)
                }

                Choice {
                    visible: Bluetooth.canWake(entry.modelData)
                    label: "Wake from sleep"
                    on: entry.modelData.wakeAllowed
                    onFlipped: Bluetooth.setWakeAllowed(entry.modelData, !entry.modelData.wakeAllowed)
                }

                Choice {
                    label: "Block it"
                    detail: entry.modelData.blocked ? "refuses connections" : ""
                    on: entry.modelData.blocked
                    onFlipped: Bluetooth.setBlocked(entry.modelData, !entry.modelData.blocked)
                }

                Act {
                    label: "Forget it"
                    onActivated: {
                        root.opened = "";
                        Bluetooth.forget(entry.modelData);
                    }
                }

                Fact {
                    text: entry.modelData.address
                }
            }
        }
    }

    StyledText {
        visible: Bluetooth.enabled && !Bluetooth.known.length
        leftPadding: Appearance.padding.normal
        text: "nothing paired yet"
        color: Appearance.colour.textFaint
        font.pixelSize: Appearance.font.size.small
    }

    MenuRow {
        width: root.width
        visible: Bluetooth.enabled
        icon: "add"
        label: "Pair new device"
        detail: root.opened !== "pair" ? "" : Bluetooth.strangers.length ? `${Bluetooth.strangers.length} nearby` : "looking"
        onActivated: root.toggleLayer("pair")

        Icon {
            name: "expand_more"
            color: root.opened === "pair" ? Appearance.colour.text : Appearance.colour.textFaint
            rotation: root.opened === "pair" ? 180 : 0

            Behavior on rotation {
                NumberAnimation {
                    duration: Appearance.anim.fast
                    easing.type: Easing.OutBack
                }
            }
        }
    }

    MenuLayer {
        width: root.width
        open: root.opened === "pair"

        Repeater {
            model: Bluetooth.strangers.slice(0, Appearance.sizes.deviceListMax)

            delegate: MenuRow {
                required property var modelData

                icon: Bluetooth.icon(modelData)
                label: modelData.name || modelData.address
                detail: Bluetooth.stateLabel(modelData)

                onActivated: modelData.pairing ? Bluetooth.cancelPair(modelData) : Bluetooth.toggleDevice(modelData)
            }
        }

        Fact {
            visible: !Bluetooth.strangers.length
            text: "put the device in pairing mode"
        }
    }

    StyledText {
        visible: !Bluetooth.available
        text: "no bluetooth adapter on this machine"
        color: Appearance.colour.textFaint
        font.pixelSize: Appearance.font.size.small
    }
}
