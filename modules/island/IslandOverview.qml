pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

Item {
    id: root

    property var activities: []
    property bool watched: false

    signal chosen(var activity)

    readonly property real pad: Appearance.padding.card

    implicitHeight: root.pad * 2 + column.implicitHeight

    SystemClock {
        id: clock

        precision: SystemClock.Seconds
        enabled: root.watched
    }

    Column {
        id: column

        x: root.pad
        y: root.pad
        width: root.width - root.pad * 2
        spacing: Appearance.padding.normal

        Item {
            width: parent.width
            height: time.implicitHeight

            StyledText {
                id: time

                anchors.left: parent.left
                anchors.leftMargin: Appearance.padding.small
                text: Qt.formatDateTime(clock.date, "HH:mm")
                font.pixelSize: Appearance.font.size.large
            }

            StyledText {
                anchors.left: time.right
                anchors.baseline: time.baseline
                text: Qt.formatDateTime(clock.date, ":ss")
                color: Appearance.colour.textFaint
            }

            StyledText {
                anchors.right: parent.right
                anchors.rightMargin: Appearance.padding.small
                anchors.baseline: time.baseline
                text: Qt.formatDateTime(clock.date, "ddd d MMM").toLowerCase()
                color: Appearance.colour.textDim
            }
        }

        IslandMedia {
            width: parent.width
            visible: Media.hasTrack
            watched: root.watched && Media.hasTrack

            onExpand: root.chosen({
                kind: "music"
            })
        }

        Repeater {
            model: root.activities

            ActivityRow {
                required property var modelData

                width: column.width
                activity: modelData
                lights: true
                live: root.watched

                onChosen: root.chosen(modelData)
            }
        }
    }
}
