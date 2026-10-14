import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.settings

Column {
    id: root

    property var row: ({})

    readonly property real barWidth: 96
    readonly property real peak: SettingsState.usageApps.length ? SettingsState.usageApps[0].ms : 1

    width: parent ? parent.width : 0

    StyledText {
        id: widest

        visible: false
        text: "00 h 00 min"
    }

    SettingsRowFrame {
        width: root.width
        interactive: false
        icon: "hourglass_empty"
        label: `${SettingsState.usedLabel} in front of the screen today`
        detail: "counted only while you are active"
        onPointed: SettingsView.hovered = root.row
    }

    SettingsRowFrame {
        width: root.width
        visible: SettingsState.usageApps.length === 0
        interactive: false
        icon: "apps"
        label: "No apps counted yet"
        detail: "they show up here as you use them"
        onPointed: SettingsView.hovered = root.row
    }

    Repeater {
        model: SettingsState.usageApps

        delegate: SettingsRowFrame {
            id: app

            required property var modelData

            width: root.width
            interactive: false
            label: Apps.nameFor(app.modelData.appClass) || app.modelData.appClass
            lead: mark
            onPointed: SettingsView.hovered = root.row

            Component {
                id: mark

                AppMark {
                    spec: AppIcons.markFor(app.modelData.appClass, "colour")
                    fallback: "apps"
                    color: Appearance.colour.textDim
                }
            }

            SquircleRect {
                anchors.verticalCenter: parent.verticalCenter
                width: root.barWidth
                height: Appearance.padding.small
                radius: height / 2
                color: Appearance.colour.fill

                SquircleRect {
                    width: parent.width * (app.modelData?.ms ?? 0) / root.peak
                    height: parent.height
                    radius: height / 2
                    color: Appearance.colour.textDim
                }
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                width: widest.implicitWidth
                horizontalAlignment: Text.AlignRight
                text: SettingsState.minutesLabel(app.modelData?.minutes ?? 0)
                color: Appearance.colour.textDim
            }
        }
    }
}
