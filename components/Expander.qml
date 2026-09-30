import QtQuick
import qs.config

Item {
    id: root

    property bool open: false

    property string tip: ""

    signal toggled

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

        name: "expand_more"
        color: root.open || root.hovered ? Appearance.colour.text : Appearance.colour.textFaint
        rotation: root.open ? 180 : 0

        Behavior on rotation {
            NumberAnimation {
                duration: Appearance.anim.fast
                easing.type: Easing.OutBack
            }
        }
    }

    MouseArea {
        id: pointer

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }

    HoverTip {
        text: root.tip
        asked: pointer.containsMouse
    }
}
