pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.config

// Switch. One thing, on or off.
//
// Wraps components/Toggle.qml, which exists and is used - this page is where
// its look is argued with, not where it is invented. The knob on the right
// writes `checked` from outside, which is exactly the contract Toggle asks
// for: it never owns its state, and flips only when told.
Item {
    id: page

    property bool drawn: true

    property bool checked: true

    readonly property var knobs: [
        {
            kind: "toggle",
            prop: "checked",
            label: "checked",
            initial: true
        }
    ]

    Toggle {
        id: ctl

        anchors.centerIn: parent
        checked: page.checked
        onToggled: page.checked = !page.checked
    }

    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: ctl.bottom
        anchors.topMargin: Appearance.padding.normal
        text: page.checked ? "on" : "off"
        color: Appearance.colour.textFaint
    }
}
