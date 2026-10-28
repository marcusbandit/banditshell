import QtQuick
import qs.config
import qs.components

Item {
    id: root

    property bool open: false

    property string tip: ""

    signal toggled

    readonly property bool keyable: true

    function press(): void {
        root.toggled();
    }

    readonly property bool hovered: pointer.containsMouse && root.Window.activeFocusItem?.keyable !== true

    implicitWidth: Math.max(Appearance.sizes.minTarget, Appearance.font.iconSize + Appearance.padding.small * 2)
    implicitHeight: implicitWidth

    SquircleRect {
        anchors.fill: parent
        pill: "object"
        color: Appearance.colour.fill

        opacity: hoverFade.value

        Follow {
            id: hoverFade

            target: root.hovered ? 1 : 0
            speed: Appearance.animation.revealSpeed
            epsilon: Appearance.animation.fadeEpsilon
            startsAtTarget: true
        }
    }

    FocusMark {
        shown: root.activeFocus
        pill: "object"
    }

    Icon {
        anchors.centerIn: parent

        name: "expand_more"
        color: root.open || root.hovered ? Appearance.colour.text : Appearance.colour.textFaint
        rotation: turn.value

        Follow {
            id: turn

            target: root.open ? 180 : 0
            speed: Appearance.animation.revealSpeed
            startsAtTarget: true
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
        asked: root.hovered
    }
}
