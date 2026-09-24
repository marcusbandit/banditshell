pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.config

// Segmented buttons. One row, one choice taken.
//
// Wraps components/Segments.qml, which the hotkey sheet and the clipboard
// already use - this page is where its look gets argued with away from both.
// The "taken" knob is the one to play with: it writes the same property a
// click would, and the thumb GLIDES there rather than stepping, because the
// thumb's travel is a Follow and the distance is whatever it happens to be.
// A knob that stepped would be lying about the control.
Item {
    id: page

    property bool drawn: true

    // The values the knobs write. `taken` is the choice as a word, mapped to
    // an index here; the demo's own clicks write it too, so knob and demo
    // are two hands on one state and cannot disagree.
    property string members: "three"
    property string taken: "first"

    readonly property var knobs: [
        {
            kind: "choice",
            prop: "members",
            label: "members",
            options: ["two", "three", "four"],
            initial: "three"
        },
        {
            kind: "choice",
            prop: "taken",
            label: "taken",
            options: ["first", "second", "third", "fourth"],
            initial: "first"
        }
    ]

    // One semantic set, scaled by the members knob: the same four moments
    // shorter or longer, because a control whose options change MEANING when
    // their count changes is a lie about state.
    readonly property var all: ["Hour", "Day", "Week", "Month"]
    readonly property int count: ["two", "three", "four"].indexOf(members) + 2
    readonly property var options: all.slice(0, count)
    readonly property int takenIndex: Math.min(["first", "second", "third", "fourth"].indexOf(taken), count - 1)

    Column {
        anchors.centerIn: parent
        spacing: Appearance.padding.normal

        Segments {
            anchors.horizontalCenter: parent.horizontalCenter
            options: page.options
            current: page.takenIndex
            onPicked: index => page.taken = ["first", "second", "third", "fourth"][index]
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: `taken: ${page.options[page.takenIndex]}`
            color: Appearance.colour.textFaint
        }
    }
}
