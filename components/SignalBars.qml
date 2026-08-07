import QtQuick
import qs.config

// A signal strength meter, drawn rather than set in the icon font.
//
// Material Symbols' wifi-bar glyphs are outlined wedges whose filled portion is
// invisible at icon size, so in a list every network looked identical. A meter
// is also simply faster to read down a column than four near-identical glyphs:
// the eye compares heights without having to identify anything.
//
// Bars come from the step count, so changing `steps` changes the meter and
// nothing else has to agree with it (~/.claude/rules/math-over-hardcoding.md).
Item {
    id: root

    // 0..100, as NetworkManager reports it.
    property real strength: 0
    property int steps: Appearance.sizes.signalBands
    property color activeColour: Appearance.colour.text
        // Much fainter than the faintest LABEL tier. An unlit bar has to lose
    // against a lit one at a glance and at 13px; one opacity step apart, every
    // meter in a list read as full.
    property color inactiveColour: Appearance.colour.fillStronger

    readonly property int lit: Math.max(0, Math.min(steps, Math.ceil(strength / (100 / steps))))

    readonly property real barWidth: Math.max(2, Math.round(Appearance.font.iconSize / 7))
    readonly property real gap: Math.max(1, Math.round(barWidth / 2))

    implicitWidth: steps * barWidth + (steps - 1) * gap
    implicitHeight: Math.round(Appearance.font.iconSize * 0.75)

    Repeater {
        model: root.steps

        delegate: G2Rect {
            required property int index

            // Rising staircase, shortest first. The shortest is a third of the
            // tallest rather than a sliver, so a one-bar signal still reads as a
            // bar rather than as a speck.
            width: root.barWidth
            height: root.height * (1 / 3 + (2 / 3) * ((index + 1) / root.steps))
            radius: width / 2

            x: index * (root.barWidth + root.gap)
            y: root.height - height

            color: index < root.lit ? root.activeColour : root.inactiveColour

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }
    }
}
