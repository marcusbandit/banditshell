pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.menu.content

// The system status section, and the menus behind it.
//
// Rendered FROM DATA: adding an indicator is a row in `items`, and connecting one
// is filling in that row's bindings.
//
// What is NOT here matters as much as what is. This row is for the four things
// you reach for while doing something else: how loud, which network, which
// headphones, how much charge. Notifications have their own tray, and media,
// performance and power are going to the dashboard, where there is room to READ
// them instead of squinting at a 28px slot. A bar that carries everything is a
// bar you stop looking at.
//
// Sound and microphone are one gauge for the same reason: they are one question,
// which is whether you can hear and whether you can be heard. A muted microphone
// raises that gauge's alert rather than costing a slot of its own.
Item {
    id: root

    signal requested(string key)
    signal released

    // Which icon the cursor is on, "" for none.
    //
    // This is ONE source of truth on purpose. Letting each icon fire its own
    // enter and leave means that sliding from one to the next produces both, in
    // an order Qt does not promise, and the leave can undo the open that the
    // enter just did. Tracking the state and reacting to it changing is immune
    // to that: a leave only clears the key if it is still that icon's.
    property string hoveredKey: ""

    onHoveredKeyChanged: hoveredKey ? root.requested(hoveredKey) : root.released()

    readonly property var items: [
        {
            key: "audio",
            title: "Sound",
            icon: Audio.icon(Audio.volume, Audio.muted),
            active: !Audio.muted && Audio.volume > 0,
            // The one state in this pair worth interrupting you for: a muted
            // output you hear immediately, a muted input you find out about a
            // minute into talking to nobody.
            alert: Audio.sourceMuted,
            body: soundMenu
        },
        {
            key: "network",
            title: "Network",
            icon: Network.icon(Network.activeStrength),
            active: Network.connected,
            alert: Network.available && !Network.enabled,
            available: Network.available,
            body: networkMenu
        },
        {
            key: "bluetooth",
            title: "Bluetooth",
            icon: Bluetooth.statusIcon(),
            active: Bluetooth.anyConnected,
            available: Bluetooth.available,
            body: bluetoothMenu
        },
        {
            key: "battery",
            title: "Battery",
            icon: Battery.icon(),
            active: Battery.charging,
            alert: Battery.low,
            available: Battery.available,
            body: batteryMenu
        }
    ]

    // The icon item for a key, so whoever positions a menu can ask where the
    // icon actually ended up rather than recomputing a layout only this file
    // knows.
    function iconFor(key: string): Item {
        for (let i = 0; i < repeater.count; i++) {
            const item = repeater.itemAt(i);
            if (item?.key === key)
                return item;
        }
        return null;
    }

    function entryFor(key: string): var {
        return root.items.find(i => i.key === key) ?? null;
    }

    implicitWidth: column.implicitWidth
    implicitHeight: column.implicitHeight

    // A quiet container, so the indicators read as one control rather than a
    // column of loose glyphs.
    G2Rect {
        anchors.fill: parent
        anchors.margins: -Appearance.padding.small
        radius: Appearance.rounding.normal
        color: Appearance.colour.fill
    }

    Column {
        id: column

        anchors.centerIn: parent
        spacing: Appearance.sizes.statusGap

        Repeater {
            id: repeater

            model: root.items

            delegate: StatusIcon {
                required property var modelData

                readonly property string key: modelData.key

                icon: modelData.icon
                active: modelData.active ?? false
                alert: modelData.alert ?? false
                available: modelData.available ?? true

                // Hover IS the request. Clicking is the same intent, and matters
                // for touch and for keyboard-driven opens later.
                onHoveredChanged: {
                    if (hovered)
                        root.hoveredKey = key;
                    else if (root.hoveredKey === key)
                        root.hoveredKey = "";
                }
                onActivated: root.requested(key)
            }
        }
    }

    Component {
        id: soundMenu

        SoundMenu {}
    }

    Component {
        id: batteryMenu

        BatteryMenu {}
    }

    Component {
        id: networkMenu

        NetworkMenu {}
    }

    Component {
        id: bluetoothMenu

        BluetoothMenu {}
    }
}
