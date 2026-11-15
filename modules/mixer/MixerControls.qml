import QtQuick
import qs.config
import qs.components
import qs.services
import "../../services/mixer.js" as Logic

Item {
    id: root

    property real volume: 0
    property real most: Audio.maxVolume
    property bool muted: false
    property bool listening: false
    property real peak: 0
    property real span: 0

    signal moved(real value)
    signal toggled

    implicitWidth: bar.width + readout.width + mute.width + Appearance.padding.large + Appearance.padding.small
    implicitHeight: Math.max(bar.implicitHeight, mute.implicitHeight)

    LevelSlider {
        id: bar

        anchors.right: readout.left
        anchors.rightMargin: Appearance.padding.large
        anchors.verticalCenter: parent.verticalCenter

        width: Math.round(Math.max(Appearance.sizes.menuWidth * 0.45, root.span * 0.36))
        value: root.volume
        to: Math.max(root.most, root.volume)
        step: Config.values.volume.step
        dimmed: root.muted
        peak: root.peak
        live: Mixer.watching
        lit: root.listening ? Appearance.colour.warning : Appearance.colour.accent
        onMoved: v => root.moved(v)
    }

    StyledText {
        id: readout

        anchors.right: mute.left
        anchors.rightMargin: Appearance.padding.small
        anchors.verticalCenter: parent.verticalCenter

        width: metrics.width
        horizontalAlignment: Text.AlignRight
        text: Logic.percent(root.volume)
        color: root.muted ? Appearance.colour.textFaint : Appearance.colour.textDim
        font.pixelSize: Appearance.font.size.small
    }

    TextMetrics {
        id: metrics

        font.family: Appearance.font.family
        font.pixelSize: Appearance.font.size.small
        text: "150%"
    }

    Button {
        id: mute

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        style: root.muted ? "plate" : "bare"
        alarm: root.muted
        icon: root.listening ? (root.muted ? "mic_off" : "mic") : root.muted ? "volume_off" : "volume_up"
        onClicked: root.toggled()
    }
}
