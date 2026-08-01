pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

// CPU, memory, temperature. This one is real.
//
// Sampling is tied to this component's lifetime, so the shell reads /proc only
// while someone is looking at the numbers.
Column {
    id: root

    spacing: Appearance.padding.normal

    Component.onCompleted: SysInfo.watch(true)
    Component.onDestruction: SysInfo.watch(false)

    Repeater {
        model: [
            {
                icon: "speed",
                label: "CPU",
                value: SysInfo.cpu,
                detail: `${Math.round(SysInfo.cpu * 100)}%`
            },
            {
                icon: "memory",
                label: "Memory",
                value: SysInfo.memory,
                detail: `${SysInfo.memoryUsedGb.toFixed(1)} of ${SysInfo.memoryTotalGb.toFixed(1)} GB`
            },
            {
                icon: "thermostat",
                label: "Temperature",
                // No absolute scale exists for "hot", so this is against a
                // plausible ceiling rather than pretending to be a percentage.
                value: Math.min(1, SysInfo.temperature / 100),
                detail: SysInfo.temperature > 0 ? `${Math.round(SysInfo.temperature)} C` : "unavailable",
                warn: SysInfo.temperature >= 80
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
                // Reuse the accent's "past normal" behaviour for a hot chip.
                warnAbove: gauge.modelData.warn ? 0 : 1
            }
        }
    }

    Separator {
        width: parent.width
        visible: SysInfo.swap > 0
    }

    MenuRow {
        width: root.width
        visible: SysInfo.swap > 0
        interactive: false
        icon: "swap_horiz"
        label: "Swap"
        detail: `${Math.round(SysInfo.swap * 100)}% used`
    }
}
