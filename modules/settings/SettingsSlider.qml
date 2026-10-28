import QtQuick
import qs.config
import qs.components

Row {
    id: root

    property real value: 0
    property real from: 0
    property real to: 1
    property real step: 1
    property real warnAbove: root.to
    property string text: ""
    property real trackWidth: 180
    property var ends: []

    signal moved(real value)

    spacing: Appearance.padding.small

    StyledText {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.ends.length > 0
        text: root.ends[0] ?? ""
        font.pixelSize: Appearance.font.size.small
        color: Appearance.colour.textFaint
    }

    Slider {
        anchors.verticalCenter: parent.verticalCenter
        width: root.trackWidth
        value: root.value
        from: root.from
        to: root.to
        step: root.step
        warnAbove: root.warnAbove
        enabled: root.enabled
        onMoved: v => {
            const s = root.step > 0 ? root.step : 0.01;
            const snapped = Math.round((v - root.from) / s) * s + root.from;
            root.moved(Math.max(root.from, Math.min(root.to, +snapped.toFixed(4))));
        }
    }

    StyledText {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.ends.length > 1
        text: root.ends[1] ?? ""
        rightPadding: Appearance.padding.large
        font.pixelSize: Appearance.font.size.small
        color: Appearance.colour.textFaint
    }

    StyledText {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(64, implicitWidth)
        horizontalAlignment: Text.AlignRight
        text: root.text
        color: Appearance.colour.textDim
    }
}
