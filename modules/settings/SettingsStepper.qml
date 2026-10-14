import QtQuick
import qs.config
import qs.components

Row {
    id: root

    property real value: 0
    property real from: 0
    property real to: 1
    property real step: 1
    property string text: ""

    signal moved(real value)

    spacing: 2

    SettingsTool {
        anchors.verticalCenter: parent.verticalCenter
        icon: "remove"
        tip: "less"
        enabled: root.enabled && root.value - root.step >= root.from - 0.00001
        onClicked: root.moved(Math.max(root.from, +(root.value - root.step).toFixed(4)))
    }

    StyledText {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(68, implicitWidth)
        horizontalAlignment: Text.AlignHCenter
        text: root.text
        color: Appearance.colour.text
    }

    SettingsTool {
        anchors.verticalCenter: parent.verticalCenter
        icon: "add"
        tip: "more"
        enabled: root.enabled && root.value + root.step <= root.to + 0.00001
        onClicked: root.moved(Math.min(root.to, +(root.value + root.step).toFixed(4)))
    }
}
