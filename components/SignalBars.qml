import QtQuick
import qs.config

Item {
    id: root

    property real strength: 0
    property int steps: ControlTuning.signalBands
    property color activeColour: Appearance.colour.text

    property color inactiveColour: Appearance.colour.fillStronger

    readonly property int lit: Math.max(0, Math.min(steps, Math.ceil(strength / (100 / steps))))

    readonly property real barWidth: Math.max(2, Math.round(Appearance.font.iconSize / 7))
    readonly property real gap: Math.max(1, Math.round(barWidth / 2))

    implicitWidth: steps * barWidth + (steps - 1) * gap
    implicitHeight: Appearance.icon.small

    Repeater {
        model: root.steps

        delegate: SquircleRect {
            id: bar

            required property int index

            width: root.barWidth
            height: root.height * (1 / 3 + (2 / 3) * ((index + 1) / root.steps))
            pill: "object"

            x: index * (root.barWidth + root.gap)
            y: root.height - height

            color: tone.value

            FollowColour {
                id: tone

                target: bar.index < root.lit ? root.activeColour : root.inactiveColour
                speed: Appearance.animation.revealSpeed
            }
        }
    }
}
