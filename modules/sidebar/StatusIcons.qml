pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

// The system status section.
//
// NONE OF THESE ARE WIRED UP YET. They render their resting glyph, react to the
// cursor, and open a placeholder menu; the services behind them come later, one
// at a time. What matters now is that the shape is right: the section is
// rendered FROM DATA, so adding an indicator is a row in `items`, and connecting
// one is filling in its bindings, never touching this layout.
Item {
    id: root

    // `source` is the icon item itself, so whoever positions the menu can ask
    // where it actually ended up rather than being told a coordinate that only
    // this file knows how to compute.
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

    readonly property var items: [
        {
            key: "audio",
            title: "Sound",
            icon: "volume_up"
        },
        {
            key: "mic",
            title: "Microphone",
            icon: "mic"
        },
        {
            key: "network",
            title: "Network",
            icon: "wifi"
        },
        {
            key: "ethernet",
            title: "Ethernet",
            icon: "lan"
        },
        {
            key: "bluetooth",
            title: "Bluetooth",
            icon: "bluetooth"
        },
        {
            key: "battery",
            title: "Battery",
            icon: "battery_full"
        }
    ]

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
                // Placeholders until a service says otherwise.
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
}
