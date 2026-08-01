pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

// The system status section.
//
// NONE OF THESE ARE WIRED UP YET. They render their resting glyph and react to
// the cursor; the services behind them come later, one at a time. What matters
// now is that the shape is right: the section is rendered FROM DATA, so adding
// an indicator is a row in `items`, and connecting one is filling in its
// bindings, never touching this layout.
Column {
    id: root

    signal opened(string key)

    readonly property var items: [
        {
            key: "audio",
            icon: "volume_up"
        },
        {
            key: "mic",
            icon: "mic"
        },
        {
            key: "network",
            icon: "wifi"
        },
        {
            key: "ethernet",
            icon: "lan"
        },
        {
            key: "bluetooth",
            icon: "bluetooth"
        },
        {
            key: "battery",
            icon: "battery_full"
        }
    ]

    spacing: Appearance.sizes.statusGap

    Repeater {
        model: root.items

        delegate: StatusIcon {
            required property var modelData

            anchors.horizontalCenter: parent.horizontalCenter

            icon: modelData.icon
            // Placeholders until a service says otherwise.
            active: modelData.active ?? false
            alert: modelData.alert ?? false
            available: modelData.available ?? true

            onActivated: root.opened(modelData.key)
        }
    }
}
