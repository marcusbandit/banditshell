import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root

    property bool live: true

    readonly property int restingCount: 29
    readonly property real pitch: Math.max(2, Math.round(Appearance.font.size.small / 6)) * 2

    readonly property string phase: Dictation.phase

    readonly property real flowPeriod: Appearance.animation.fade.slow * 9
    readonly property real writePeriod: Appearance.animation.fade.slow * 2

    property double now: Date.now()

    implicitWidth: root.restingCount * root.pitch
    implicitHeight: Appearance.font.line.small

    onPhaseChanged: if (root.phase === "listening")
        wave.reset()

    FrameAnimation {
        running: root.live && (root.phase === "processing" || root.phase === "typing")

        onTriggered: root.now = Date.now()
    }

    Follow {
        id: fill

        speed: Appearance.animation.resizeSpeed
        target: root.phase === "processing" ? 1 : 0
        epsilon: 0.004
    }

    Waveform {
        id: wave

        anchors.fill: parent
        levels: Dictation.levels
        running: root.live && root.phase === "listening"
        pitch: root.pitch
        mode: root.phase === "processing" ? 1 : root.phase === "listening" ? 0 : 2
        flow: (root.now % root.flowPeriod) / root.flowPeriod
        caret: (root.now % root.writePeriod) / root.writePeriod
        fill: fill.value
    }
}
