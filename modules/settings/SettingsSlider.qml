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
    property real tailWidth: 0
    property real room: Infinity

    readonly property real lead: (root.ends.length > 0 ? firstEnd.implicitWidth + root.spacing : 0) + root.spacing
    readonly property real endRoom: root.ends.length > 1 ? lastEnd.implicitWidth + root.spacing : 0
    readonly property real tail: root.endRoom + Math.max(64, reading.implicitWidth)
    readonly property real track: Math.max(80, Math.min(root.trackWidth, root.room - root.lead - root.tail))

    signal moved(real value)

    spacing: Appearance.padding.small

    StyledText {
        id: firstEnd

        anchors.verticalCenter: parent.verticalCenter
        visible: root.ends.length > 0
        text: root.ends[0] ?? ""
        font.pixelSize: Appearance.font.size.small
        color: Appearance.colour.textFaint
    }

    Slider {
        anchors.verticalCenter: parent.verticalCenter
        width: root.track
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
        id: lastEnd

        anchors.verticalCenter: parent.verticalCenter
        visible: root.ends.length > 1
        text: root.ends[1] ?? ""
        rightPadding: Appearance.padding.large
        font.pixelSize: Appearance.font.size.small
        color: Appearance.colour.textFaint
    }

    StyledText {
        id: reading

        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(64, implicitWidth, Math.min(root.tailWidth, root.room - root.lead - root.track) - root.endRoom)
        horizontalAlignment: Text.AlignRight
        text: root.text
        color: Appearance.colour.textDim
    }
}
