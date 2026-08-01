import QtQuick
import Quickshell
import qs.config
import qs.components

// Vertical clock for the sidebar: hours over minutes, date underneath.
// A narrow column can't hold "HH:MM:SS", so the time stacks instead, and the
// hierarchy comes from colour rather than from extra font sizes.
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
        font.pixelSize: Appearance.font.size.large
    }

    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatDateTime(clock.date, "mm")
        font.pixelSize: Appearance.font.size.large
        color: Appearance.colour.textDim
    }

    Item {
        width: 1
        height: Appearance.padding.normal
    }

    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatDateTime(clock.date, "dd")
        font.pixelSize: Appearance.font.size.small
        color: Appearance.colour.textDim
    }

    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatDateTime(clock.date, "MMM").toUpperCase()
        font.pixelSize: Appearance.font.size.small
        color: Appearance.colour.textFaint
    }
}
