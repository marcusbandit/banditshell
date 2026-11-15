import QtQuick
import qs.config
import qs.components
import qs.services
import "../../services/mixer.js" as Logic

Item {
    id: root

    required property string appKey
    property real iconColumn: Appearance.font.iconSize
    property real gap: Appearance.padding.small
    property real sliderWidth: Appearance.sizes.screenSliderWidth
    property real valueWidth: Appearance.sizes.screenValueWidth

    readonly property var app: Mixer.outputByKey[root.appKey] ?? null
    readonly property string state: root.app ? Mixer.stateOf(root.app) : "gone"
    readonly property bool sounding: root.state === "sound"
    readonly property bool muted: root.state === "muted"
    readonly property real volume: root.app ? Mixer.volumeOf(root.app) : 0

    implicitHeight: label.implicitHeight + bar.implicitHeight

    AppMark {
        anchors.left: parent.left
        anchors.verticalCenter: bar.verticalCenter
        size: root.iconColumn
        spec: root.app ? Mixer.iconOf(root.app) : ""
        fallback: "music_note"
        color: Appearance.colour.textDim
        opacity: root.muted ? 0.3 : root.sounding ? 1 : Appearance.opacity.disabled

        MouseArea {
            anchors.fill: parent
            anchors.margins: -Appearance.padding.small
            cursorShape: Qt.PointingHandCursor
            onClicked: Mixer.toggleMute(root.app)
        }
    }

    StyledText {
        id: label

        x: root.iconColumn + root.gap
        width: root.sliderWidth
        text: root.muted ? `${root.app?.display ?? ""}, muted` : root.app?.display ?? ""
        color: root.muted ? Appearance.colour.alarm : root.sounding ? Appearance.colour.text : Appearance.colour.textFaint
        font.pixelSize: Appearance.font.size.small
        elide: Text.ElideRight
    }

    LevelSlider {
        id: bar

        x: root.iconColumn + root.gap
        anchors.top: label.bottom
        width: root.sliderWidth
        value: root.volume
        to: Math.max(Audio.maxVolume, root.volume)
        step: Config.values.volume.step
        dimmed: root.muted
        peak: root.app && Mixer.watching ? Mixer.peakOf(root.app) : 0
        live: Mixer.watching
        onMoved: v => Mixer.setVolume(root.app, v)
    }

    StyledText {
        anchors.left: bar.right
        anchors.leftMargin: root.gap
        anchors.verticalCenter: bar.verticalCenter
        width: root.valueWidth
        text: Logic.percent(root.volume)
        color: root.muted ? Appearance.colour.textFaint : Appearance.colour.textDim
    }
}
