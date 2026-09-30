pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.config

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
