pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.config

// Sliders. A bead on a rail.
//
// Wraps components/Slider.qml, the volume rail's control, on its own page so
// its look can be argued with away from PipeWire. The slider does not own its
// value and neither does this page pretend to: the knob writes `value`, the
// page hands it to the slider, and a drag on the demo beads back through the
// same property - the two ends of one number, which is the whole reason the
// control works the way it does.
//
// The range deliberately runs past 100%: amplification is where the detent
// and the warning fill live, and a gallery that only showed the polite half
// of the rail would hide the interesting part.
Item {
    id: page

    property bool drawn: true

    property real value: 0.4
    property bool dimmed: false

    readonly property var knobs: [
        {
            kind: "value",
            prop: "value",
            label: "value",
            from: 0,
            to: 1.5,
            step: 0.05,
            initial: 0.4,
            format: v => `${Math.round(v * 100)}%`
        },
        {
            kind: "toggle",
            prop: "dimmed",
            label: "muted",
            initial: false
        }
    ]

    Column {
        anchors.centerIn: parent
        spacing: Appearance.padding.normal

        Slider {
            width: 320
            from: 0
            to: 1.5
            step: 0.05
            value: page.value
            dimmed: page.dimmed
            onMoved: value => page.value = value
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: `${Math.round(page.value * 100)}%`
            color: Appearance.colour.textFaint
        }
    }
}
