import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.components.blob
import qs.services

Item {
    id: root

    readonly property string screen: QsWindow.window?.screen?.name ?? ""

    readonly property bool bare: Appearance.bare || StreamState.floats(root.screen)
    readonly property bool sidebar: !root.bare && SidebarState.visibleOn(root.screen)

    property bool streamed: StreamState.shows(root.screen)

    readonly property real band: root.bare ? 0 : Appearance.sizes.border
    readonly property real barWidth: root.sidebar ? root.band + Appearance.sizes.sidebarWidth : root.band

    readonly property real streamReach: reach.value
    readonly property real topBand: Math.max(root.band, root.streamReach)

    readonly property real holeX: barWidth
    readonly property real holeY: topBand
    readonly property real holeWidth: width - barWidth - band
    readonly property real holeHeight: height - topBand - band

    readonly property real leftFlare: root.sidebar ? Appearance.sizes.sidebarFlare : Appearance.sizes.windowRadius
    readonly property real streamFlare: Math.min(Appearance.sizes.gap, root.streamReach)

    property var panels: []

    Follow {
        id: reach

        target: root.streamed ? Appearance.sizes.streamHeight : 0
        speed: Appearance.anim.revealSpeed
    }

    BlobField {
        anchors.fill: parent

        panels: root.panels

        content: Qt.vector4d(root.holeX, root.holeY, root.holeWidth, root.holeHeight)

        gap: root.bare ? 0 : Appearance.sizes.gap

        baseRadius: root.bare ? Qt.vector4d(0, root.streamFlare, 0, root.streamFlare) : Qt.vector4d(Appearance.sizes.windowRadius, Appearance.sizes.windowRadius, Math.max(0, root.leftFlare - Appearance.sizes.gap), Math.max(0, root.leftFlare - Appearance.sizes.gap))

        frameOn: Appearance.sizes.roundOuter && !root.bare ? 1 : 0
    }
}
