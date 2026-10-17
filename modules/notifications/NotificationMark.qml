import QtQuick
import Quickshell.Services.Notifications
import qs.config
import qs.components
import qs.services

Item {
    id: root

    required property var entry

    property real size: Appearance.sizes.notificationBadge
    property real radius: Appearance.rounding.normal
    property real power: Appearance.rounding.power

    readonly property bool badged: root.size >= Appearance.sizes.notificationBadge

    readonly property bool urgent: root.entry?.urgency === NotificationUrgency.Critical

    readonly property string picture: root.entry?.picture ?? ""
    readonly property string spec: root.entry?.markSpec ?? ""

    readonly property bool pictured: root.picture !== "" && art.ready

    readonly property real badgeSize: Math.round(root.size * 0.4)
    readonly property real ring: Math.max(2, Math.round(root.size / 16))

    implicitWidth: root.size
    implicitHeight: root.size

    AppMark {
        anchors.centerIn: parent
        visible: !root.pictured
        spec: root.spec
        size: root.size
        fallback: root.urgent ? "priority_high" : "notifications"
        color: root.spec !== "" ? Appearance.colour.text : root.urgent ? Appearance.colour.alarm : Appearance.colour.textDim
        fits: AppIcons.fits
        onMeasured: (path, box) => AppIcons.recordFit(path, box)
    }

    SquircleImage {
        id: art

        anchors.fill: parent
        source: root.picture
        fillMode: Image.PreserveAspectCrop
        radius: root.radius
        power: root.power
    }

    SquircleRect {
        anchors.fill: parent
        radius: root.radius
        cornerPower: root.power
        stroke: Appearance.colour.alarm
        strokeWidth: root.ring
        visible: root.urgent && root.badged
    }

    Item {
        id: corner

        readonly property real across: root.badgeSize + root.ring * 2

        x: root.width - corner.across + root.ring
        y: root.height - corner.across + root.ring
        width: corner.across
        height: corner.across
        visible: root.pictured && root.badged && root.spec !== ""

        SquircleRect {
            anchors.fill: parent
            radius: width / 2
            cornerPower: 2
            color: Appearance.colour.ink
        }

        AppMark {
            anchors.centerIn: parent
            spec: root.spec
            size: root.badgeSize
            color: Appearance.colour.text
            fits: AppIcons.fits
        }
    }
}
