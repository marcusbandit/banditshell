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
    readonly property real railOpen: root.rail ? 0 : 1
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
    property Item backdrop: null
    property bool readable: false

    Follow {
        id: readableShown

        target: root.readable ? 1 : 0
        speed: Appearance.animation.revealSpeed
        epsilon: 0.002
    }

    Follow {
        id: reach

        target: root.streamed ? Appearance.sizes.streamHeight : 0
        speed: Appearance.animation.revealSpeed
    }

    readonly property real deepest: root.panels.reduce((most, p) => p ? Math.max(most, Math.max(0, Math.min(p.x + p.w, root.holeX + root.holeWidth) - Math.max(p.x, root.holeX)) * Math.max(0, Math.min(p.y + p.h, root.holeY + root.holeHeight) - Math.max(p.y, root.holeY))) : most, 0)
    readonly property bool reachesIn: root.deepest > Math.pow(Appearance.padding.huge * 4, 2)

    BlobField {
        anchors.fill: parent

        panels: root.panels

        backdrop: root.backdrop
        restRaise: Math.max(root.rail ? 0 : (root.sidebar ? 1 : 0), readableShown.value)

        colour: Appearance.blend(Appearance.colour.surface, Appearance.colour.readableSurface, readableShown.value)

        content: Qt.vector4d(root.holeX, root.holeY, root.holeWidth, root.holeHeight)

        gap: root.gap

        baseRadius: root.corners

        frameOn: Appearance.sizes.roundOuter && !root.bare ? 1 : 0
    }
}
