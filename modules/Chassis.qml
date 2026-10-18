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
    readonly property bool rail: root.sidebar && Appearance.sizes.sidebarRail
    property bool railWanted: false

    readonly property real railOpen: root.rail ? railGrowth.value : 1
    readonly property real sidebarSpan: Appearance.sizes.railWidth + (Appearance.sizes.sidebarWidth - Appearance.sizes.railWidth) * root.railOpen

    readonly property real fullBarWidth: root.sidebar ? root.band + Appearance.sizes.sidebarWidth : root.band
    readonly property real barWidth: root.sidebar ? root.band + (root.rail ? root.sidebarSpan : Appearance.sizes.sidebarWidth) : root.band

    readonly property real streamReach: reach.value
    readonly property real topBand: Math.max(root.band, root.streamReach)

    readonly property real holeX: barWidth
    readonly property real holeY: topBand
    readonly property real holeWidth: width - barWidth - band
    readonly property real holeHeight: height - topBand - band

    readonly property real leftFlare: root.sidebar ? Appearance.sizes.sidebarFlare : Appearance.sizes.windowRadius

    readonly property real gap: root.bare ? 0 : Appearance.sizes.gap
    readonly property vector4d corners: root.bare ? Qt.vector4d(0, root.streamFlare, 0, root.streamFlare) : Qt.vector4d(Appearance.sizes.windowRadius, Appearance.sizes.windowRadius, Math.max(0, root.leftFlare - Appearance.sizes.gap), Math.max(0, root.leftFlare - Appearance.sizes.gap))
    readonly property real streamFlare: Math.min(Appearance.sizes.gap, root.streamReach)

    property var panels: []

    Follow {
        id: railGrowth

        target: root.rail && root.railWanted ? 1 : 0
        speed: Appearance.animation.resizeSpeed
        epsilon: 0.002
    }

    Follow {
        id: reach

        target: root.streamed ? Appearance.sizes.streamHeight : 0
        speed: Appearance.animation.revealSpeed
    }

    BlobField {
        anchors.fill: parent

        panels: root.panels

        content: Qt.vector4d(root.holeX, root.holeY, root.holeWidth, root.holeHeight)

        gap: root.gap

        baseRadius: root.corners

        frameOn: Appearance.sizes.roundOuter && !root.bare ? 1 : 0
    }
}
