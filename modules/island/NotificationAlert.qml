pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Notifications
import qs.config
import qs.components
import qs.services

Item {
    id: root

    required property var entry

    property bool loose: false

    property real dragX: 0
    property bool dragging: false
    property real dragLift: 0
    property bool flinging: false
    property bool tucking: false

    signal dismissed
    signal putAway

    readonly property real lift: press.axis === "up" ? root.dragLift : rise.value
    readonly property real shiftX: root.dragging ? root.dragX : slide.value
    readonly property real shiftFade: Math.min(1, Math.abs(root.shiftX) / Math.max(1, root.width))

    function fling(direction: int): void {
        if (root.flinging || root.tucking)
            return;
        slide.value = root.shiftX;
        root.dragging = false;
        root.flinging = true;
        slide.target = direction * root.width * 1.15;
    }

    function tuck(): void {
        if (root.flinging || root.tucking)
            return;
        rise.value = root.lift;
        root.tucking = true;
        rise.target = 1;
    }

    readonly property bool hovered: pointer.hovered

    readonly property var notification: root.entry?.notification ?? null
    readonly property bool live: root.entry?.live ?? false
    readonly property bool urgent: root.entry?.urgency === NotificationUrgency.Critical

    readonly property var actions: root.live ? (root.entry?.pressable(root.notification?.actions) ?? []) : []
    readonly property var primary: root.live ? ((root.notification?.actions ?? []).find(a => a.identifier === "default") ?? null) : null

    readonly property real pad: Appearance.padding.card
    readonly property real badgeSize: Appearance.sizes.notificationBadge
    readonly property real closeSize: Appearance.font.line.small + Appearance.padding.small

    implicitHeight: root.pad * 2 + Math.max(root.badgeSize, words.implicitHeight) + (actionRow.visible ? Appearance.padding.normal + actionRow.implicitHeight : 0)

    HoverHandler {
        id: pointer
    }

    Follow {
        id: slide

        speed: Appearance.animation.trackSpeed
        epsilon: 0.5

        onValueChanged: if (root.flinging && Math.abs(slide.value) >= root.width) {
            root.flinging = false;
            root.dismissed();
        }
    }

    Follow {
        id: rise

        speed: Appearance.animation.trackSpeed * 1.2
        epsilon: 0.004

        onValueChanged: if (root.tucking && rise.value >= 0.96) {
            root.tucking = false;
            root.putAway();
        }
    }

    Follow {
        id: glow

        speed: Appearance.animation.revealSpeed * 1.5
        epsilon: 0.005
        target: root.hovered && !press.moved ? 1 : 0
    }

    Item {
        id: body

        x: root.shiftX
        width: root.width
        height: root.height
        y: root.loose ? -root.lift * root.height * 0.4 : 0
        opacity: (root.loose ? 1 - root.lift : 1) * (1 - root.shiftFade * 0.9)

        SquircleRect {
            anchors.fill: parent
            anchors.margins: Appearance.padding.small
            color: press.pressed && !press.moved ? Appearance.colour.fillStrong : Appearance.colour.fill
            opacity: glow.value
            visible: glow.value > 0.01
        }

        NotificationMark {
            id: badge

            x: root.pad
            y: root.pad
            size: root.badgeSize
            entry: root.entry
            scale: 1 + 0.06 * glow.value
        }

        Column {
            id: words

            x: badge.x + badge.width + Appearance.padding.normal
            y: root.pad + Math.max(0, (root.badgeSize - Math.min(root.badgeSize, implicitHeight)) / 2)
            width: root.width - x - root.pad - root.closeSize - Appearance.padding.small
            spacing: Appearance.padding.small / 2

            StyledText {
                width: parent.width
                visible: text !== ""
                text: root.entry?.appName ?? ""
                color: root.urgent ? Appearance.colour.alarm : Appearance.colour.textFaint
                elide: Text.ElideRight
            }

            StyledText {
                width: parent.width
                visible: text !== ""
                text: root.entry?.summary || (!root.entry?.body ? "(no message)" : "")
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            StyledText {
                width: parent.width
                visible: text !== ""
                text: root.entry?.brief || root.entry?.body || ""
                textFormat: Text.StyledText
                color: Appearance.colour.textDim
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Item {
                width: parent.width
                height: Appearance.padding.small + Appearance.font.stem * 2
                visible: (root.entry?.progress ?? -1) >= 0

                Rectangle {
                    y: Appearance.padding.small
                    width: parent.width
                    height: Appearance.font.stem * 2
                    radius: height / 2
                    color: Appearance.colour.fillStrong
                }

                Rectangle {
                    y: Appearance.padding.small
                    width: parent.width * Math.max(0, root.entry?.progress ?? 0) / 100
                    height: Appearance.font.stem * 2
                    radius: height / 2
                    color: Appearance.colour.accent
                }
            }
        }
    }

    MouseArea {
        id: press

        property real fromX: 0
        property real fromY: 0
        property string axis: ""
        property var trail: []
        readonly property bool moved: press.axis !== ""

        readonly property real travel: Math.max(1, root.implicitHeight * 0.6)

        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: press.moved ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        preventStealing: press.moved

        function reset(): void {
            press.axis = "";
            press.trail = [];
        }

        onPressed: mouse => {
            press.fromX = mouse.x;
            press.fromY = mouse.y;
            press.reset();
        }

        onPositionChanged: mouse => {
            if (press.pressedButtons !== Qt.LeftButton)
                return;
            const dx = mouse.x - press.fromX;
            const up = press.fromY - mouse.y;
            const threshold = Config.values.control.dragThreshold;
            if (!press.axis) {
                if (Math.abs(dx) >= threshold && Math.abs(dx) > Math.abs(up))
                    press.axis = "x";
                else if (up >= threshold)
                    press.axis = "up";
            }
            if (press.axis === "x") {
                root.dragging = true;
                root.dragX = dx;
                press.trail = [...press.trail.filter(p => Date.now() - p.t < 120), {
                        x: mouse.x,
                        t: Date.now()
                    }];
            } else if (press.axis === "up") {
                root.dragLift = Math.max(0, Math.min(1, up / press.travel));
            }
        }

        onReleased: mouse => {
            if (!press.moved) {
                if (mouse.button === Qt.RightButton) {
                    root.fling(1);
                } else {
                    if (root.primary)
                        root.primary.invoke();
                    root.dismissed();
                }
            } else if (press.axis === "x") {
                const first = press.trail[0];
                const last = press.trail[press.trail.length - 1];
                const speed = first && last && last.t > first.t ? (last.x - first.x) / (last.t - first.t) : 0;
                const thrown = Math.abs(speed) > 0.6 && Math.sign(speed) === Math.sign(root.dragX);
                if (Math.abs(root.dragX) > root.width / 3 || thrown) {
                    root.fling(Math.sign(root.dragX) || 1);
                } else {
                    slide.value = root.dragX;
                    root.dragging = false;
                    slide.target = 0;
                }
            } else {
                rise.value = root.dragLift;
                if (root.dragLift >= Config.values.control.pullCommit) {
                    root.tucking = true;
                    rise.target = 1;
                } else {
                    rise.target = 0;
                }
            }
            press.reset();
        }

        onCanceled: {
            if (root.dragging) {
                slide.value = root.dragX;
                root.dragging = false;
                slide.target = 0;
            }
            if (press.axis === "up") {
                rise.value = root.dragLift;
                rise.target = 0;
            }
            press.reset();
        }
    }

    Item {
        x: root.shiftX + root.width - root.pad - width + Appearance.padding.small / 2
        y: root.pad - Appearance.padding.small / 2
        width: root.closeSize
        height: root.closeSize
        opacity: glow.value * body.opacity
        visible: opacity > 0.01

        SquircleRect {
            anchors.fill: parent
            radius: width / 2
            cornerPower: 2
            color: close.containsMouse ? Appearance.colour.fillStronger : Appearance.colour.fillStrong
            scale: close.pressed ? Appearance.press.ring : close.containsMouse ? Appearance.press.ringHover : 1

            Behavior on scale {
                NumberAnimation {
                    duration: Appearance.animation.fast
                    easing.type: Easing.OutCubic
                }
            }
        }

        Icon {
            anchors.centerIn: parent
            name: "close"
            size: Appearance.font.size.small
            color: close.containsMouse ? Appearance.colour.text : Appearance.colour.textDim
        }

        MouseArea {
            id: close

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: root.fling(1)
        }
    }

    Flow {
        id: actionRow

        x: root.shiftX + words.x
        y: body.y + root.pad + Math.max(root.badgeSize, words.implicitHeight) + Appearance.padding.normal
        width: words.width + root.closeSize + Appearance.padding.small
        spacing: Appearance.padding.small
        visible: root.actions.length > 0
        opacity: body.opacity

        Repeater {
            model: root.actions

            Button {
                required property var modelData

                size: 0
                text: modelData.text
                width: Math.min(implicitWidth, actionRow.width)

                onClicked: {
                    if (root.live)
                        modelData.invoke();
                    root.dismissed();
                }
            }
        }
    }
}
