import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root

    property bool live: true

    readonly property int barCount: 29
    readonly property real barWidth: Math.max(2, Math.round(Appearance.font.size.small / 6))
    readonly property real barGap: root.barWidth
    readonly property real barMin: root.barWidth

    readonly property string phase: Dictation.phase
    readonly property var levels: Dictation.levels.slice(-root.barCount)

    implicitWidth: root.barCount * root.barWidth + (root.barCount - 1) * root.barGap
    implicitHeight: Appearance.font.line.small

    function barFraction(i: int): real {
        if (root.phase === "listening")
            return root.levels[i] ?? 0;

        if (root.phase === "processing") {
            const p = i / (root.barCount - 1);
            const t = flow.t;
            const wave = 0.30 * Math.sin(2 * Math.PI * (1.3 * p - t)) + 0.17 * Math.sin(2 * Math.PI * (2.7 * p + t) + 1.1) + 0.09 * Math.sin(2 * Math.PI * (4.1 * p - 2 * t) + 2.3);
            const swell = 0.46 + 0.10 * Math.sin(2 * Math.PI * t);
            return Math.min(1, Math.max(0.04, (swell + wave) * fill.value));
        }

        const caret = writer.position * (root.barCount - 1);
        if (i > caret + 0.5)
            return 0.05;
        if (i > caret - 0.9)
            return 1;
        return 0.34;
    }

    QtObject {
        id: flow

        property real t: 0
    }

    NumberAnimation {
        target: flow
        property: "t"
        running: root.live && root.phase === "processing"
        from: 0
        to: 1
        duration: Appearance.animation.slow * 9
        loops: Animation.Infinite
    }

    Follow {
        id: fill

        speed: Appearance.animation.resizeSpeed
        target: root.phase === "processing" ? 1 : 0
        epsilon: 0.004
    }

    QtObject {
        id: writer

        property real position: 0
    }

    NumberAnimation {
        target: writer
        property: "position"
        running: root.live && root.phase === "typing"
        from: 0
        to: 1
        duration: Appearance.animation.slow * 2
        loops: Animation.Infinite
    }

    Row {
        anchors.fill: parent
        spacing: root.barGap

        Repeater {
            model: root.barCount

            Rectangle {
                required property int index

                readonly property real fraction: {
                    root.levels;
                    root.phase;
                    flow.t;
                    fill.value;
                    writer.position;
                    return root.barFraction(index);
                }

                width: root.barWidth
                height: root.barMin + (root.height - root.barMin) * fraction
                radius: width / 2
                color: Appearance.colour.accent

                y: root.phase === "processing" ? root.height - height : (root.height - height) / 2
            }
        }
    }
}
