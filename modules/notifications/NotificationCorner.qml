pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

Item {
    id: root

    required property real inset

    readonly property real panelWidth: Appearance.sizes.notificationWidth

    required property bool onStage

    property bool wanted: Config.values.notifications.placement !== "island"

    readonly property var items: root.wanted && root.onStage ? Notifications.popups : []

    readonly property bool any: root.items.length > 0

    readonly property Item maskItem: plate

    readonly property real pad: Appearance.padding.normal

    NotificationCopier {
        entries: Notifications.history
    }

    Item {
        id: plate

        x: root.width - root.panelWidth - root.inset
        y: root.inset
        width: root.panelWidth
        height: list.height > 0 ? list.height + root.pad * 2 : 0
        visible: height > 0.5

        DropShadow {
            anchors.fill: parent
            radius: Appearance.rounding.large
            blur: Appearance.padding.large
            offset.y: Math.round(Appearance.padding.small / 2)
        }

        SquircleRect {
            anchors.fill: parent
            radius: Appearance.rounding.large
            color: Appearance.colour.surfaceSolid
            stroke: Appearance.colour.fillStrong
            strokeWidth: 1
        }

        Column {
            id: list

            x: root.pad
            y: root.pad
            width: plate.width - root.pad * 2

            Repeater {
                model: ScriptModel {
                    values: root.items
                }

                delegate: Item {
                    id: slot

                    required property var modelData

                    width: list.width
                    height: card.height

                    NotificationCard {
                        id: card

                        width: slot.width
                        entry: slot.modelData
                        collapses: true

                        onReleased: Notifications.dismiss(slot.modelData)
                        onKept: Notifications.expire(slot.modelData)
                    }
                }
            }
        }
    }
}
