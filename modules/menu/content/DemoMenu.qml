pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

// A menu that is not wired up yet, standing in with plausible rows.
//
// Demo content rather than grey skeleton bars, because the two answer different
// questions. A skeleton tells you the panel has the right SHAPE; rows that look
// like the real thing tell you whether the DESIGN works at the density the real
// thing will have. The second is the one worth knowing now, so these carry real
// labels, real icons and a real toggle that toggles nothing.
Column {
    id: root

    // [{ icon, label, detail, toggle }]
    property var rows: []
    property string footer: "not wired up yet"

    spacing: Appearance.padding.small

    Repeater {
        model: root.rows

        delegate: MenuRow {
            id: row

            required property var modelData

            width: root.width
            icon: modelData.icon ?? ""
            label: modelData.label ?? ""
            detail: modelData.detail ?? ""
            selected: modelData.selected ?? false

            // The state is local and goes nowhere. It exists so the row can be
            // pressed and answer, which is the only way to judge whether the
            // press feels right.
            property bool on: modelData.toggle ?? false
            onActivated: on = !on

            Toggle {
                visible: modelData.toggle !== undefined
                checked: row.on
                onToggled: row.on = !row.on
            }
        }
    }

    Item {
        width: 1
        height: Appearance.padding.small
    }

    StyledText {
        text: root.footer
        color: Appearance.colour.textFaint
        font.pixelSize: Appearance.font.size.small
    }
}
