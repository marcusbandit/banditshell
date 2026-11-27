pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

Item {
    id: root

    property string icon: ""

    property string label: ""

    property bool on: false

    property bool detailed: false

    signal toggled

    signal opened(bool keyed)

    readonly property color fg: root.on ? Appearance.colour.onChosen : Appearance.colour.text

    readonly property real seam: Appearance.button.seam

    readonly property real chevronWidth: Math.round(root.height * 0.8)

    implicitHeight: Appearance.sizes.rowHeight

    function tone(hovered: bool, pressed: bool): color {
        const base = root.on ? Appearance.colour.chosen : Appearance.colour.fill;
        const layer = pressed ? Appearance.colour.fillStrong : hovered ? Appearance.colour.fill : null;
        return layer ? Appearance.blend(base, root.fg, layer.a) : base;
    }

    Item {
        id: main

        readonly property bool keyable: true

        function press(): void {
            root.toggled();
        }

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.detailed ? root.width - root.chevronWidth - root.seam : root.width

        scale: mainPress.value

        Follow {
            id: mainPress

            target: mainPointer.pressed ? Appearance.press.plate : 1
            speed: Appearance.animation.revealSpeed
            epsilon: Appearance.animation.fadeEpsilon
            startsAtTarget: true
        }

        SquircleRect {
            id: mainPlate

            anchors.fill: parent
            pill: "object"
            topRightRadius: root.detailed ? Appearance.button.seamRadius : main.height / 2
            bottomRightRadius: root.detailed ? Appearance.button.seamRadius : main.height / 2
            topLeftRadius: main.height / 2
            bottomLeftRadius: main.height / 2
            color: mainTone.value
            rim: 1
        }

        FollowColour {
            id: mainTone

            target: root.tone(mainPointer.containsMouse, mainPointer.pressed)
            speed: Appearance.animation.revealSpeed
        }

        FocusMark {
            id: mainRing

            shown: main.activeFocus
            pill: "object"
            topLeftRadius: mainPlate.topLeftRadius + mainRing.reach
            bottomLeftRadius: mainPlate.bottomLeftRadius + mainRing.reach
            topRightRadius: mainPlate.topRightRadius + mainRing.reach
            bottomRightRadius: mainPlate.bottomRightRadius + mainRing.reach
        }

        Icon {
            id: glyph

            anchors.left: parent.left
            anchors.leftMargin: Appearance.padding.normal
            anchors.verticalCenter: parent.verticalCenter
            name: root.icon
            fill: root.on ? 1 : 0
            color: root.fg
        }

        StyledText {
            anchors.left: glyph.right
            anchors.leftMargin: Appearance.padding.small
            anchors.right: parent.right
            anchors.rightMargin: Appearance.padding.normal
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            color: root.fg
            elide: Text.ElideRight
        }

        MouseArea {
            id: mainPointer

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: root.toggled()
            onPressAndHold: root.detailed ? root.opened(false) : root.toggled()
        }
    }

    Item {
        id: chevron

        readonly property bool keyable: root.detailed

        function press(): void {
            root.opened(true);
        }

        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.chevronWidth
        visible: root.detailed

        scale: chevronPress.value

        Follow {
            id: chevronPress

            target: chevronPointer.pressed ? Appearance.press.plate : 1
            speed: Appearance.animation.revealSpeed
            epsilon: Appearance.animation.fadeEpsilon
            startsAtTarget: true
        }

        SquircleRect {
            id: chevronPlate

            anchors.fill: parent
            pill: "object"
            topLeftRadius: Appearance.button.seamRadius
            bottomLeftRadius: Appearance.button.seamRadius
            topRightRadius: chevron.height / 2
            bottomRightRadius: chevron.height / 2
            color: chevronTone.value
            rim: 1
        }

        FollowColour {
            id: chevronTone

            target: root.tone(chevronPointer.containsMouse, chevronPointer.pressed)
            speed: Appearance.animation.revealSpeed
        }

        FocusMark {
            id: chevronRing

            shown: chevron.activeFocus
            pill: "object"
            topLeftRadius: chevronPlate.topLeftRadius + chevronRing.reach
            bottomLeftRadius: chevronPlate.bottomLeftRadius + chevronRing.reach
            topRightRadius: chevronPlate.topRightRadius + chevronRing.reach
            bottomRightRadius: chevronPlate.bottomRightRadius + chevronRing.reach
        }

        Icon {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: -Appearance.padding.hair
            name: "chevron_right"
            color: root.fg
        }

        MouseArea {
            id: chevronPointer

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: root.opened(false)
        }
    }
}
