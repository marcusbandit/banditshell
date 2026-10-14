pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Notifications
import qs.config
import qs.components
import qs.services

Item {
    id: root

    required property var entry

    property bool hovered: false

    property real lift: 0

    signal dismissed

    readonly property var notification: root.entry?.notification ?? null
    readonly property bool live: root.entry?.live ?? false
    readonly property bool urgent: root.entry?.urgency === NotificationUrgency.Critical

    readonly property var actions: root.live ? (root.entry?.pressable(root.notification?.actions) ?? []) : []
    readonly property var primary: root.live ? ((root.notification?.actions ?? []).find(a => a.identifier === "default") ?? null) : null

    readonly property real pad: Appearance.padding.card
    readonly property real badgeSize: Appearance.sizes.notificationBadge

    readonly property string picture: root.entry?.picture ?? ""
    readonly property string mark: root.entry?.mark ?? ""

    implicitHeight: root.pad * 2 + Math.max(root.badgeSize, words.implicitHeight) + (actionRow.visible ? (Appearance.padding.normal + actionRow.implicitHeight) * reach.value : 0)

    Follow {
        id: reach

        speed: Appearance.animation.revealSpeed
        epsilon: 0.005
        target: root.hovered && root.actions.length > 0 ? 1 : 0
    }

    MouseArea {
        id: press

        property real fromY: 0
        property bool moved: false

        readonly property real travel: Math.max(1, root.implicitHeight * 0.6)

        anchors.fill: parent
        cursorShape: press.moved ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        preventStealing: press.moved

        onPressed: mouse => {
            press.fromY = mouse.y;
            press.moved = false;
        }

        onPositionChanged: mouse => {
            const up = press.fromY - mouse.y;
            if (!press.moved && up >= Config.values.control.dragThreshold)
                press.moved = true;
            if (press.moved)
                root.lift = Math.max(0, Math.min(1, up / press.travel));
        }

        onReleased: {
            if (!press.moved) {
                if (root.primary)
                    root.primary.invoke();
                root.dismissed();
            } else if (root.lift >= Config.values.control.pullCommit) {
                root.dismissed();
            }
            root.lift = 0;
            press.moved = false;
        }

        onCanceled: {
            root.lift = 0;
            press.moved = false;
        }
    }

    Item {
        id: badge

        x: root.pad
        y: root.pad
        width: root.badgeSize
        height: root.badgeSize

        readonly property bool pictured: root.picture !== "" && art.ready
        readonly property bool marked: root.mark !== "" && sign.ready

        SquircleRect {
            anchors.fill: parent
            radius: Appearance.rounding.normal
            color: Appearance.colour.fillStrong
            visible: !badge.pictured && !badge.marked
        }

        Icon {
            anchors.centerIn: parent
            visible: !badge.pictured && !badge.marked
            size: Math.round(badge.width / 2)
            name: root.urgent ? "priority_high" : "notifications"
            fill: 1
            color: root.urgent ? Appearance.colour.alarm : Appearance.colour.textDim
        }

        SquircleImage {
            id: sign

            anchors.fill: parent
            source: root.mark
            fillMode: Image.PreserveAspectCrop
            radius: Appearance.rounding.normal
            visible: !badge.pictured
        }

        SquircleImage {
            id: art

            anchors.fill: parent
            source: root.picture
            fillMode: Image.PreserveAspectCrop
            radius: Appearance.rounding.normal
        }
    }

    Column {
        id: words

        x: badge.x + badge.width + Appearance.padding.normal
        y: root.pad + Math.max(0, (root.badgeSize - Math.min(root.badgeSize, implicitHeight)) / 2)
        width: root.width - x - root.pad
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
                color: Appearance.colour.fillStrong
            }

            Rectangle {
                y: Appearance.padding.small
                width: parent.width * Math.max(0, root.entry?.progress ?? 0) / 100
                height: Appearance.font.stem * 2
                color: Appearance.colour.accent
            }
        }
    }

    Flow {
        id: actionRow

        x: words.x
        y: root.pad + Math.max(root.badgeSize, words.implicitHeight) + Appearance.padding.normal
        width: words.width
        spacing: Appearance.padding.small
        visible: root.actions.length > 0
        opacity: reach.value

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
