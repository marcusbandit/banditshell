import QtQuick
import qs.config

Item {
    id: root

    property string glyph: ""
    property string tip: ""

    signal nudged

    readonly property bool hovered: pointer.containsMouse

    implicitWidth: Math.max(Appearance.sizes.minTarget, Appearance.font.iconSize + Appearance.padding.small * 2)
    implicitHeight: implicitWidth

    G2Rect {
        anchors.fill: parent
        radius: height / 2
        color: Appearance.colour.fill
        opacity: root.hovered ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.fast
            }
        }
    }

    Icon {
        anchors.centerIn: parent

        name: root.glyph
        color: !root.enabled ? Appearance.colour.textGhost : root.hovered ? Appearance.colour.text : Appearance.colour.textFaint

        Behavior on color {
            ColorAnimation {
                duration: Appearance.anim.fast
            }
        }
    }

    MouseArea {
        id: pointer

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.nudged()
    }

    HoverTip {
        text: root.tip
        asked: pointer.containsMouse
    }
}
