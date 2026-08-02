pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

// Bluetooth. This one is real, and it is all of it.
//
// Everything bluez will let you do to an adapter or a device is here: power,
// scanning, being findable, accepting pairing; and per device connect, pair,
// cancel a pairing, forget, trust, block, and whether it may wake the machine.
//
// IN TWO LAYERS, because that list is much longer than what anyone came here
// for. The surface is the list you actually use: turn it on, tap the headphones.
// Everything else unrolls out of the row it belongs to, one at a time, and rolls
// back up when you open another. A menu that shows every switch at once is a
// menu you have to read; a menu that shows one row per device is a menu you can
// aim at.
//
// Discovery runs while this menu is open and stops when it closes. Unlike wifi
// scanning it is also visible to other people's devices, so leaving it on in the
// background would be rude as well as wasteful.
Column {
    id: root

    spacing: Appearance.padding.small

    // Which layer is unrolled: a device address, "adapter", or nothing. ONE at a
    // time, which is what keeps the menu a menu rather than a settings page, and
    // what keeps its height bounded no matter how many devices are paired.
    property string opened: ""

    function toggleLayer(key: string): void {
        root.opened = root.opened === key ? "" : key;
    }

    // SCANNING IS A THING YOU ASK FOR, not the price of opening the menu.
    //
    // It used to run the whole time this was open, which put a list of every
    // television and doorbell in the building above the four devices you own,
    // reordering itself every few seconds under the cursor. Discovery now runs
    // only while the pairing layer is open, which also means the machine is only
    // broadcasting while you are actually pairing something.
    onOpenedChanged: Bluetooth.setDiscovering(root.opened === "pair")
    Component.onDestruction: Bluetooth.setDiscovering(false)

    // One switch inside a layer. The whole row is the target, not the switch:
    // a 34px toggle is a bad thing to ask anyone to hit, and the label says what
    // it does, so tapping the label doing nothing would be the surprise.
    //
    // NO ICONS in here, unlike the rows outside. Out there a glyph answers "what
    // is this thing"; in here every row is a sentence about the same device, so a
    // column of glyphs would only push the sentences right and make the ones
    // without a glyph look misaligned.
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

    // Something that HAPPENS, rather than something that is on or off. An arrow
    // where the switches keep their toggle, so the right edge stays a column and
    // the difference between "set this" and "do this" is visible before you
    // read either.
    component Act: MenuRow {
        Icon {
            name: "chevron_right"
            color: Appearance.colour.textFaint
        }
    }

    // A line of fact, not a control. Address, adapter, the things you go looking
    // for once a year and need exactly then.
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

            Icon {
                anchors.verticalCenter: parent.verticalCenter

                visible: Bluetooth.enabled
                name: "expand_more"
                color: root.opened === "adapter" ? Appearance.colour.text : Appearance.colour.textFaint
                rotation: root.opened === "adapter" ? 180 : 0

                Behavior on rotation {
                    NumberAnimation {
                        duration: Appearance.anim.fast
                        easing.type: Easing.OutBack
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -Appearance.padding.small
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleLayer("adapter")
                }
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
        // YOURS ONLY. What is merely nearby lives behind "Pair new device",
        // because a device you have never met is not something you do anything
        // with except pair it.
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

                // The tap is the thing you came for: connect it, or pair it if
                // you never have. Everything else is in the layer.
                onActivated: Bluetooth.toggleDevice(entry.modelData)

                Icon {
                    name: "expand_more"
                    color: entry.showing ? Appearance.colour.text : Appearance.colour.textFaint
                    rotation: entry.showing ? 180 : 0

                    Behavior on rotation {
                        NumberAnimation {
                            duration: Appearance.anim.fast
                            easing.type: Easing.OutBack
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -Appearance.padding.small
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleLayer(entry.modelData.address)
                    }
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

                // Last, because it undoes everything above it.
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

    // THE DOOR TO EVERYTHING ELSE. Behind it: the radio actually scanning, and
    // whatever is broadcasting nearby. Closed, none of that exists and none of
    // it costs anything.
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

                // Tap to pair, tap again to give up on it. Pairing can hang for
                // a minute on a device that has wandered out of range, and a row
                // you cannot take back is a row you have to close the menu to
                // escape.
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
