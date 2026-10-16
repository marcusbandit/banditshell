import QtQuick
import Quickshell.Services.Notifications
import qs.config
import qs.components

Item {
    id: root

    required property var entry

    property real size: Appearance.sizes.notificationBadge
    property real radius: Appearance.rounding.normal
    property real power: Appearance.rounding.power

    readonly property bool urgent: root.entry?.urgency === NotificationUrgency.Critical

    readonly property string picture: root.entry?.picture ?? ""
    readonly property string mark: root.entry?.mark ?? ""

    readonly property bool pictured: root.picture !== "" && art.ready
    readonly property bool marked: root.mark !== "" && sign.ready

    implicitWidth: root.size
    implicitHeight: root.size

    SquircleRect {
        anchors.fill: parent
        radius: root.radius
        cornerPower: root.power
        color: Appearance.colour.fillStrong
        visible: !root.pictured && !root.marked
    }

    Icon {
        anchors.centerIn: parent
        visible: !root.pictured && !root.marked
        size: Math.round(root.width / 2)
        name: root.urgent ? "priority_high" : "notifications"
        fill: 1
        color: root.urgent ? Appearance.colour.alarm : Appearance.colour.textDim
    }

    SquircleImage {
        id: sign

        anchors.fill: parent
        source: root.mark
        fillMode: Image.PreserveAspectCrop
        radius: root.radius
        power: root.power
        visible: !root.pictured
    }

    SquircleImage {
        id: art

        anchors.fill: parent
        source: root.picture
        fillMode: Image.PreserveAspectCrop
        radius: root.radius
        power: root.power
    }
}
