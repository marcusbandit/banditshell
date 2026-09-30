pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

Item {
    id: root

    required property var parts

    required property real advance

    property color color: Appearance.colour.text

    readonly property int cells: {
        let n = 0;
        for (const p of root.parts)
            n += p.cells;
        return n;
    }

    implicitWidth: root.cells * root.advance
    implicitHeight: Math.round(Appearance.font.size.small * 4 / 3)

    Row {
        anchors.fill: parent

        Repeater {
            model: root.parts

            delegate: Item {
                id: part

                required property var modelData

                width: part.modelData.cells * root.advance
                height: root.height

                StyledText {
                    anchors.fill: parent
                    visible: !part.modelData.glyph
                    verticalAlignment: Text.AlignVCenter

                    text: part.modelData.text ?? ""
                    color: root.color
                }

                Icon {
                    anchors.centerIn: parent
                    visible: !!part.modelData.glyph

                    glyph: part.modelData.glyph ?? ""
                    size: Appearance.font.size.small
                    color: root.color
                }
            }
        }
    }
}
