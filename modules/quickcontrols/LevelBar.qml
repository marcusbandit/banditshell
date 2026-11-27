pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root

    property real value: 0
    property real from: 0
    property real to: 1
    property real step: 0.05
    property real warnAbove: 1

    property bool dimmed: false

    property string icon: ""

    property string reading: ""

    property bool toggles: false

    signal moved(real value)

    signal toggled

    readonly property bool keyable: root.enabled
    readonly property string adjusts: "horizontal"

    function adjust(steps: int): void {
        root.ask(root.value + steps * root.step);
    }

    function press(): void {
        if (root.toggles)
            root.toggled();
    }

    readonly property real fraction: Math.max(0, Math.min(1, (root.value - root.from) / Math.max(0.0001, root.to - root.from)))

    property real dragged: 0

    readonly property real shown: pointer.dragging ? root.dragged : glide.value

    readonly property real travel: Math.max(1, root.width - root.height)

    readonly property real fillWidth: root.height + root.shown * root.travel

    readonly property color lit: root.dimmed ? Appearance.colour.fillStronger : Appearance.colour.chosen

    readonly property color ink: root.dimmed ? Appearance.colour.text : Appearance.colour.onChosen

    implicitHeight: Math.round(Appearance.sizes.rowHeight * 0.85)

    function ask(v: real): void {
        const wanted = Math.max(root.from, Math.min(root.to, v));
        const f = (wanted - root.from) / Math.max(0.0001, root.to - root.from);
        root.dragged = f;
        glide.value = f;
        root.moved(wanted);
    }

    function askAt(x: real): void {
        const f = Math.max(0, Math.min(1, (x - root.height / 2) / root.travel));
        root.ask(root.from + f * (root.to - root.from));
    }

    Follow {
        id: glide

        target: root.fraction
        speed: Appearance.animation.trackSpeed
        epsilon: 0.001
    }

    SquircleRect {
        id: track

        anchors.fill: parent
        pill: "object"
        color: pointer.containsMouse ? Appearance.colour.fillStrong : Appearance.colour.fill
        rim: 1
    }

    SquircleRect {
        visible: root.warnAbove > root.from && root.warnAbove < root.to && (pointer.containsMouse || root.value > root.warnAbove)
        x: root.height / 2 + (root.warnAbove - root.from) / Math.max(0.0001, root.to - root.from) * root.travel - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: Appearance.stroke.ring
        height: Math.round(root.height * 0.4)
        pill: "object"
        color: Appearance.colour.textFaint
    }

    StyledText {
        id: readingBelow

        anchors.right: parent.right
        anchors.rightMargin: Math.round(root.height / 2)
        anchors.verticalCenter: parent.verticalCenter
        text: root.reading
        color: Appearance.colour.textDim
        font.pixelSize: Appearance.font.size.small
    }

    SquircleRect {
        id: fill

        width: root.fillWidth
        height: root.height
        pill: "object"
        color: litTone.value
        scale: 1

        FollowColour {
            id: litTone

            target: root.lit
            speed: Appearance.animation.revealSpeed
        }

        Item {
            anchors.fill: parent
            clip: true

            StyledText {
                x: readingBelow.x
                anchors.verticalCenter: parent.verticalCenter
                text: root.reading
                color: root.ink
                font.pixelSize: Appearance.font.size.small
            }
        }

        Icon {
            x: Math.round((root.height - width) / 2)
            anchors.verticalCenter: parent.verticalCenter
            name: root.icon
            fill: root.dimmed ? 0 : 1
            color: root.ink
        }
    }

    FocusMark {
        shown: root.activeFocus
        pill: "object"
    }

    MouseArea {
        id: pointer

        anchors.fill: parent
        anchors.topMargin: -Math.max(0, (Appearance.sizes.minTarget - root.height) / 2)
        anchors.bottomMargin: anchors.topMargin
        hoverEnabled: true
        preventStealing: true
        cursorShape: pointer.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor

        property bool dragging: false
        property bool onIcon: false
        property real fromX: 0

        onPressed: mouse => {
            pointer.fromX = mouse.x;
            pointer.onIcon = root.toggles && mouse.x < root.height;
            pointer.dragging = !pointer.onIcon;
            if (pointer.dragging)
                root.askAt(mouse.x);
        }

        onPositionChanged: mouse => {
            if (!pointer.pressed)
                return;
            if (!pointer.dragging && Math.abs(mouse.x - pointer.fromX) > Config.values.control.dragThreshold)
                pointer.dragging = true;
            if (pointer.dragging)
                root.askAt(mouse.x);
        }

        onReleased: {
            if (!pointer.dragging && pointer.onIcon)
                root.toggled();
            pointer.dragging = false;
            pointer.onIcon = false;
        }

        onCanceled: {
            pointer.dragging = false;
            pointer.onIcon = false;
        }

        onWheel: wheel => {
            const touchpad = wheel.pixelDelta.x !== 0 || wheel.pixelDelta.y !== 0;
            const natural = wheel.inverted || (touchpad ? Compositor.naturalScrollTouchpad : Compositor.naturalScrollMouse);
            root.ask(root.value + wheel.angleDelta.y / 120 * (natural ? -1 : 1) * root.step);
        }
    }
}
