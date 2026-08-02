import QtQuick
import Quickshell
import qs.config
import qs.components

// Vertical clock for the sidebar: hours over minutes, date underneath.
//
// A narrow column can't hold "HH:MM:SS", so the time stacks. Both halves are the
// primary label so the two lines read as one block rather than as a value and a
// caption; the date drops to the tertiary tier and gets air above it.
//
// The date stacks for the same reason the time does, which it did not have to
// before. At the old 9px tier "2 AUG" fitted this 52px bar on one line; the
// small tier is 18px now, which puts those five characters at 60px and hangs
// them off both edges. Day over month is 36px at its widest and fits.
Column {
    id: root

    property alias precision: clock.precision

    spacing: 0

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatDateTime(clock.date, "HH")
        font.pixelSize: Appearance.font.size.normal
    }

    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatDateTime(clock.date, "mm")
        font.pixelSize: Appearance.font.size.normal
    }

    Item {
        width: 1
        height: Appearance.padding.normal
    }

    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatDateTime(clock.date, "d")
        font.pixelSize: Appearance.font.size.small
        color: Appearance.colour.textFaint
    }

    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatDateTime(clock.date, "MMM").toUpperCase()
        font.pixelSize: Appearance.font.size.small
        color: Appearance.colour.textFaint
    }
}
