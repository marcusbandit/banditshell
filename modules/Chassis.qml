import QtQuick
import Quickshell
import qs.config
import qs.components.blob
import qs.services

Item {
    id: root

    readonly property string screen: QsWindow.window?.screen?.name ?? ""

    readonly property bool bare: Appearance.bare
    readonly property bool sidebar: !root.bare && SidebarState.visibleOn(root.screen)

    readonly property real band: root.bare ? 0 : Appearance.sizes.border
    readonly property real barWidth: root.sidebar ? root.band + Appearance.sizes.sidebarWidth : root.band

    readonly property real holeX: barWidth
    readonly property real holeY: band
    readonly property real holeWidth: width - barWidth - band
    readonly property real holeHeight: height - band * 2

    readonly property real leftFlare: root.sidebar ? Appearance.sizes.sidebarFlare : Appearance.sizes.windowRadius

    property var panels: []

    BlobField {
        anchors.fill: parent

        panels: root.panels

        content: Qt.vector4d(root.holeX, root.holeY, root.holeWidth, root.holeHeight)

        gap: root.bare ? 0 : Appearance.sizes.gap

        baseRadius: root.bare ? Qt.vector4d(0, 0, 0, 0) : Qt.vector4d(Appearance.sizes.windowRadius, Appearance.sizes.windowRadius, Math.max(0, root.leftFlare - Appearance.sizes.gap), Math.max(0, root.leftFlare - Appearance.sizes.gap))

        frameOn: Appearance.sizes.roundOuter && !root.bare ? 1 : 0
    }
}
