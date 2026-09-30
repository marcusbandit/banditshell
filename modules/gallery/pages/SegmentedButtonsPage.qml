pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.config

Item {
    id: page

    property bool drawn: true

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
