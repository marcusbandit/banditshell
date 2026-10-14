pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

Column {
    id: root

    property var facts: []

    spacing: 4

    Repeater {
        model: root.facts

        delegate: Item {
            required property var modelData

            width: root.width
            height: Appearance.font.line.small

            StyledText {
                id: term

                text: modelData[0]
                color: Appearance.colour.textFaint
            }

            StyledText {
                x: term.implicitWidth + Appearance.padding.card
                width: parent.width - x
                horizontalAlignment: Text.AlignRight
                text: String(modelData[1])
                elide: Text.ElideRight
            }
        }
    }
}
