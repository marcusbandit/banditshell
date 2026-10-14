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

    signal moved(real value)

    spacing: Appearance.padding.small

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
        width: Math.max(64, implicitWidth)
        horizontalAlignment: Text.AlignRight
        text: root.text
        color: Appearance.colour.textDim
    }
}
