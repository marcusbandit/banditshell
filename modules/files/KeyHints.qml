pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

Flow {
    id: root

    property var keys: []

    spacing: Appearance.padding.normal

    Repeater {
        model: root.keys

        delegate: Row {
            id: hint

            required property var modelData

            spacing: Appearance.padding.small

            StyledText {
                text: hint.modelData[0]
                font.pixelSize: Appearance.font.size.small
                color: Appearance.colour.accent
            }

            StyledText {
                text: hint.modelData[1]
                font.pixelSize: Appearance.font.size.small
                color: Appearance.colour.textDim
            }
        }
    }
}
