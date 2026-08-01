import QtQuick
import qs.config
import qs.components
import qs.services

// Battery. This one is real, and adapts to what the machine actually has.
//
// On a desktop it says so rather than drawing an empty battery, because UPower
// hands over a display device whether or not there is a battery behind it and
// the difference between "0%" and "none" matters.
Column {
    id: root

    spacing: Appearance.padding.normal

    Item {
        width: parent.width
        implicitHeight: Math.max(bigIcon.implicitHeight, headline.implicitHeight)

        Icon {
            id: bigIcon

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            name: Battery.icon()
            color: Battery.low ? Appearance.colour.accent : Appearance.colour.text
        }

        Column {
            id: headline

            anchors.left: bigIcon.right
            anchors.leftMargin: Appearance.padding.normal
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            StyledText {
                text: Battery.available ? `${Math.round(Battery.percentage * 100)}%` : "no battery"
                font.pixelSize: Appearance.font.size.large
                color: Battery.low ? Appearance.colour.accent : Appearance.colour.text
            }

            StyledText {
                text: Battery.available ? Battery.state : "this machine runs on mains"
                font.pixelSize: Appearance.font.size.small
                color: Appearance.colour.textDim
            }
        }
    }

    // The charge itself, at a glance. Same primitive as a volume slider, not
    // interactive: you can look at a battery, you cannot drag it.
    Slider {
        width: parent.width
        visible: Battery.available
        value: Battery.percentage
        warnAbove: 1

        // A slider that ignores the pointer would still take the click away from
        // whatever is under it.
        enabled: false
    }

    Separator {
        width: parent.width
        visible: Battery.available
    }

    Repeater {
        model: !Battery.available ? [] : [
            {
                icon: "schedule",
                label: Battery.timeLabel() || "fully charged",
                detail: "estimate"
            },
            {
                icon: "bolt",
                label: Battery.rate > 0 ? `${Battery.rate.toFixed(1)} W` : "idle",
                detail: Battery.charging ? "charging" : "draw"
            },
            {
                icon: "favorite",
                label: Battery.health > 0 ? `${Math.round(Battery.health)}%` : "unknown",
                detail: "health"
            }
        ]

        delegate: MenuRow {
            required property var modelData

            width: root.width
            interactive: false
            icon: modelData.icon
            label: modelData.label
            detail: modelData.detail
        }
    }
}
