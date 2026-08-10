pragma ComponentBehavior: Bound

import QtQuick
import qs.config

// A BAR THAT SAYS HOW MUCH OF SOMETHING IS LEFT, with an optional notch showing
// where it used to be.
//
// The shell already has two meters and this is neither of them: Slider is a
// value you can change, SignalBars is a quantised count of steps. This is the
// plain read-only proportion, and it knows nothing about what it is measuring
// (DESIGN.md 8).
//
// The notch is the reason this exists rather than a bare G2Rect. A number that
// only moves over months is unreadable as a number; the same number next to a
// mark of where it started is readable at a glance, and that comparison is the
// whole point of drawing it at all.
Item {
    id: root

    // 0..1.
    property real value: 0

    // Where the value was when something started watching, 0..1. NEGATIVE
    // HIDES IT, which is how "nothing to compare against yet" is said: a fresh
    // log has one reading, and one reading is not a history.
    property real mark: -1

    property color fill: Appearance.colour.accent
    property color track: Appearance.colour.fillStronger
    property color notch: Appearance.colour.text

    // A padding tier rather than a number, so the bar rescales with everything
    // else. The ends are fully round at this height, which is what makes it
    // read as a bar rather than as a rectangle that happens to be short.
    implicitHeight: Appearance.padding.small

    readonly property real fraction: Math.max(0, Math.min(1, root.value))

    G2Rect {
        anchors.fill: parent
        radius: root.height / 2
        color: root.track
    }

    G2Rect {
        // Floored at its own height, so a value near zero is still a dot you
        // can see rather than a sliver a pixel wide.
        width: Math.max(root.height, root.width * root.fraction)
        height: root.height
        radius: root.height / 2
        color: root.fill
    }

    Rectangle {
        visible: root.mark >= 0 && root.mark <= 1

        // Kept off both rounded ends, so the notch never hangs half outside the
        // shape it is marking a position in.
        readonly property real span: root.width - root.height
        x: root.height / 2 + span * Math.max(0, Math.min(1, root.mark)) - width / 2

        width: Math.max(1, Math.round(root.height / 3))
        height: root.height
        color: root.notch
    }
}
