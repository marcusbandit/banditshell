pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

Item {
    id: root

    property string icon: ""

    property string label: ""

    property string detail: ""

    property bool on: false

    signal toggled

    signal opened(bool keyed)

    readonly property real dot: Math.round(Appearance.sizes.rowHeight * 0.9)

    readonly property real inset: Math.round((root.height - root.dot) / 2)

    implicitHeight: Math.round(Appearance.sizes.rowHeight * 1.5)

    implicitWidth: Math.ceil(root.inset * 3 + root.dot + title.advanceWidth + Appearance.padding.small + Appearance.icon.small)

    TextMetrics {
        id: title

        font.family: Appearance.font.family
        font.pixelSize: Appearance.font.size.small
        text: root.label
    }

    Item {
        id: body

        readonly property bool keyable: true

        function press(): void {
            root.opened(true);
        }

        anchors.fill: parent
        scale: bodyPress.value

        Follow {
            id: bodyPress

            target: bodyPointer.pressed ? Appearance.press.plate : 1
            speed: Appearance.animation.revealSpeed
            epsilon: Appearance.animation.fadeEpsilon
            startsAtTarget: true
        }

        SquircleRect {
            id: plate

            anchors.fill: parent
            radius: root.inset + root.dot / 2
            color: plateTone.value
            rim: 1
        }

        FollowColour {
            id: plateTone

            target: bodyPointer.pressed ? Appearance.colour.fillStronger : bodyPointer.containsMouse && !dotPointer.containsMouse ? Appearance.colour.fillStrong : Appearance.colour.fill
            speed: Appearance.animation.revealSpeed
        }

        FocusMark {
            id: bodyRing

            shown: body.activeFocus
            radius: plate.radius + bodyRing.reach
        }

        MouseArea {
            id: bodyPointer

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: root.opened(false)
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: root.inset * 2 + root.dot
            anchors.right: chevron.left
            anchors.rightMargin: Appearance.padding.small
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            StyledText {
                width: parent.width
                text: root.label
                color: Appearance.colour.text
                elide: Text.ElideRight
            }

            StyledText {
                width: parent.width
                text: root.detail
                visible: root.detail !== ""
                color: Appearance.colour.textDim
                font.pixelSize: Appearance.font.size.small
                elide: Text.ElideRight
            }
        }

        Icon {
            id: chevron

            anchors.right: parent.right
            anchors.rightMargin: root.inset
            anchors.verticalCenter: parent.verticalCenter
            name: "chevron_right"
            size: Appearance.icon.small
            color: Appearance.colour.textFaint
        }
    }

    Item {
        id: dot

        readonly property bool keyable: true

        function press(): void {
            root.toggled();
        }

        x: root.inset
        y: root.inset
        width: root.dot
        height: root.dot
        scale: dotPress.value

        Follow {
            id: dotPress

            target: dotPointer.pressed ? Appearance.press.plate : 1
            speed: Appearance.animation.revealSpeed
            epsilon: Appearance.animation.fadeEpsilon
            startsAtTarget: true
        }

        SquircleRect {
            anchors.fill: parent
            pill: "object"
            color: dotTone.value
            rim: root.on ? 0 : 1
        }

        FollowColour {
            id: dotTone

            target: root.on ? (dotPointer.containsMouse ? Appearance.blend(Appearance.colour.chosen, Appearance.colour.onChosen, 0.12) : Appearance.colour.chosen) : dotPointer.containsMouse ? Appearance.colour.fillStronger : Appearance.colour.fillStrong
            speed: Appearance.animation.revealSpeed
        }

        FocusMark {
            shown: dot.activeFocus
            pill: "object"
        }

        Icon {
            anchors.centerIn: parent
            name: root.icon
            fill: root.on ? 1 : 0
            color: root.on ? Appearance.colour.onChosen : Appearance.colour.text
        }

        MouseArea {
            id: dotPointer

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: root.toggled()
        }
    }
}
