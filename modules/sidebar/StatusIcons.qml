pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

// The system status section: the same set of things caelestia keeps by its
// clock.
//
// NONE OF THESE ARE WIRED UP YET. They render their resting glyph and react to
// the cursor; the services behind them come later, one at a time. What matters
// now is that the shape is right: the section is rendered FROM DATA, so adding
// an indicator is a row in `items`, and connecting one is filling in its
// bindings, never touching this layout.
//
// When a service lands, that row grows `icon:`/`active:` expressions and the
// delegate's `onActivated` opens its menu. Nothing else here changes.
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
        },
        // Power sits apart from the readouts: it does something, the rest report.
        {
            key: "power",
            icon: "power_settings_new",
            separated: true
        }
    ]

    spacing: Appearance.sizes.statusGap

    Repeater {
        model: root.items

        delegate: Column {
            id: entry

            required property var modelData

            width: root.width
            spacing: root.spacing

            Groove {
                width: parent.width
                // Column skips invisible children, so this costs no space when
                // an entry doesn't ask for a divider.
                visible: entry.modelData.separated ?? false
            }

            StatusIcon {
                anchors.horizontalCenter: parent.horizontalCenter

                icon: entry.modelData.icon
                // Placeholder until a service says otherwise.
                active: entry.modelData.active ?? false
                alert: entry.modelData.alert ?? false
                available: entry.modelData.available ?? true

                onActivated: root.opened(entry.modelData.key)
            }
        }
    }
}
