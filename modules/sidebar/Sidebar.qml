import QtQuick
import qs.config
import qs.components

// The left panel. Flush against the screen edge: square where it meets the edge,
// G2-rounded where it meets the desktop, so it reads as a slab pushed out of the
// frame rather than a floating card. Same idiom as the top clock pill.
//
// Always visible for now; it will become summonable later.
G2Rect {
    id: root

    implicitWidth: Appearance.sizes.sidebarWidth

    topLeftRadius: 0
    bottomLeftRadius: 0
    topRightRadius: Appearance.rounding.large
    bottomRightRadius: Appearance.rounding.large

    color: Appearance.colour.surface

    Workspaces {
        anchors.centerIn: parent
    }

    Clock {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Appearance.padding.huge
        anchors.horizontalCenter: parent.horizontalCenter
    }
}
