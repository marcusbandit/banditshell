pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

Column {
    id: root

    spacing: Appearance.padding.normal

    Component.onCompleted: SystemInfo.watch(true)
    Component.onDestruction: SystemInfo.watch(false)

    Repeater {
        model: [
            {
                icon: "speed",
                label: "CPU",
                value: SystemInfo.cpu,
                detail: `${Math.round(SystemInfo.cpu * 100)}%`
            },
            {
                icon: "memory",
                label: "Memory",
                value: SystemInfo.memory,
                detail: `${SystemInfo.memoryUsedGb.toFixed(1)} of ${SystemInfo.memoryTotalGb.toFixed(1)} GB`
            },
            {
                icon: "thermostat",
                label: "Temperature",

                value: Math.min(1, SystemInfo.temperature / 100),
                detail: SystemInfo.temperature > 0 ? `${Math.round(SystemInfo.temperature)} C` : "unavailable",
                warn: SystemInfo.temperature >= 80
            }
        ]

        delegate: Item {
            id: gauge

            required property var modelData

            width: root.width
            implicitHeight: label.implicitHeight + bar.height + Appearance.padding.small

            Icon {
                id: glyph

                anchors.left: parent.left
                anchors.top: parent.top
                name: gauge.modelData.icon
                color: gauge.modelData.warn ? Appearance.colour.accent : Appearance.colour.textDim
            }

            StyledText {
                id: label

                anchors.left: glyph.right
                anchors.leftMargin: Appearance.padding.normal
                anchors.top: parent.top
                text: gauge.modelData.label
                color: Appearance.colour.textDim
            }

            StyledText {
                anchors.right: parent.right
                anchors.top: parent.top
                text: gauge.modelData.detail
                font.pixelSize: Appearance.font.size.small
                color: gauge.modelData.warn ? Appearance.colour.accent : Appearance.colour.textDim
            }

            Slider {
                id: bar

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                enabled: false
                value: gauge.modelData.value

                warnAbove: gauge.modelData.warn ? 0 : 1
            }
        }
    }

    Separator {
        width: parent.width
        visible: SystemInfo.swap > 0
    }

    MenuRow {
        width: root.width
        visible: SystemInfo.swap > 0
        interactive: false
        icon: "swap_horiz"
        label: "Swap"
        detail: `${Math.round(SystemInfo.swap * 100)}% used`
    }
}
