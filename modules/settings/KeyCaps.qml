pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import "boards.js" as Boards

Row {
    id: root

    property string combo: ""
    property bool listening: false

    readonly property var parts: root.listening ? ["press keys"] : root.combo ? root.combo.split(" ").filter(Boolean).map(Boards.keyName) : []

    spacing: 4

    Repeater {
        model: root.parts

        delegate: Item {
            required property string modelData

            width: cap.implicitWidth + 12
            height: 28

            SquircleRect {
                anchors.fill: parent
                radius: Appearance.rounding.small
                color: root.listening ? Appearance.colour.accentFill : Appearance.colour.fillStrong
            }

            StyledText {
                id: cap

                anchors.centerIn: parent
                text: modelData
            }
        }
    }

    StyledText {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.parts.length === 0
        text: "not set"
        color: Appearance.colour.textFaint
    }
}
