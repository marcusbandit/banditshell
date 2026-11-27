pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

Item {
    id: root

    property string icon: ""

    property string label: ""

    property string measured: root.label

    property bool on: false

    signal toggled

    readonly property bool keyable: true

    function press(): void {
        root.toggled();
    }

    readonly property real dot: Math.round(Appearance.sizes.rowHeight * 0.9)

    readonly property real inset: Math.round((Appearance.sizes.rowHeight * 1.5 - root.dot) / 2)

    implicitHeight: Math.round(Appearance.sizes.rowHeight * 1.1)

    implicitWidth: Math.ceil(root.inset + root.dot + Appearance.padding.normal + words.advanceWidth + Appearance.padding.small)

    TextMetrics {
        id: words

        font.family: Appearance.font.family
        font.pixelSize: Appearance.font.size.small
        text: root.measured
    }

    scale: squeeze.value

    Follow {
        id: squeeze

        target: pointer.pressed ? Appearance.press.plate : 1
        speed: Appearance.animation.revealSpeed
        epsilon: Appearance.animation.fadeEpsilon
        startsAtTarget: true
    }

    FocusMark {
        id: ring

        shown: root.activeFocus
        radius: root.height / 2 + ring.reach
    }

    SquircleRect {
        id: button

        x: root.inset
        anchors.verticalCenter: parent.verticalCenter
        width: root.dot
        height: root.dot
        pill: "object"
        color: tone.value
        rim: root.on ? 0 : 1

        FollowColour {
            id: tone

            target: root.on ? (pointer.containsMouse ? Appearance.blend(Appearance.colour.chosen, Appearance.colour.onChosen, 0.12) : Appearance.colour.chosen) : pointer.containsMouse ? Appearance.colour.fillStronger : Appearance.colour.fillStrong
            speed: Appearance.animation.revealSpeed
        }

        Icon {
            anchors.centerIn: parent
            name: root.icon
            fill: root.on ? 1 : 0
            color: root.on ? Appearance.colour.onChosen : Appearance.colour.text
        }
    }

    StyledText {
        anchors.left: button.right
        anchors.leftMargin: Appearance.padding.normal
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        elide: Text.ElideRight
        text: root.label
        color: root.on || pointer.containsMouse ? Appearance.colour.text : Appearance.colour.textDim
    }

    MouseArea {
        id: pointer

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: root.toggled()
    }
}
