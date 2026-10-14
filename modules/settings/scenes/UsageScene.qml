pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.settings
import "keyframes.js" as Frames

Item {
    id: root

    readonly property real stageHeight: 260
    readonly property var hours: SettingsState.usageHours
    readonly property int nowHour: new Date(SettingsState.tick).getHours()
    readonly property int cap: SettingsState.v("capHours") * 60

    property real grown: 0

    NumberAnimation on grown {
        from: 0
        to: 1
        duration: 1300
        running: !SettingsView.reduceMotion
    }

    Component.onCompleted: if (SettingsView.reduceMotion)
        root.grown = 1

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Appearance.padding.large
        spacing: Appearance.padding.small

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: SettingsState.usedMinutes >= 60 ? `${Math.floor(SettingsState.usedMinutes / 60)} h ${SettingsState.usedMinutes % 60}` : `${SettingsState.usedMinutes} min`
            font.pixelSize: Appearance.font.size.large
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: `of ${SettingsState.v("capHours")} h · ${Math.round(SettingsState.usedMinutes / Math.max(1, root.cap) * 100)}%`
            color: Appearance.colour.textFaint
        }
    }

    Row {
        id: bars

        x: 20
        y: root.height - 18 - 60
        width: root.width - 40
        height: 60
        spacing: 3

        readonly property real bar: (width - 23 * spacing) / 24

        Repeater {
            model: root.hours

            delegate: SquircleRect {
                required property int modelData
                required property int index

                readonly property real k: Frames.ARRIVE(Math.max(0, Math.min(1, (root.grown * 1300 - index * 25) / 700)))

                anchors.bottom: parent.bottom
                width: bars.bar
                height: Math.max(2, modelData / 60 * 60) * k
                radius: 2
                color: index === root.nowHour ? Appearance.colour.accent : Appearance.colour.fillStronger
            }
        }
    }
}
