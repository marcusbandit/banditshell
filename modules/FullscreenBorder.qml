import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components.blob
import qs.services

PanelWindow {
    id: win

    readonly property string screenName: win.screen?.name ?? ""

    readonly property real ring: Appearance.sizes.seam
    readonly property real reach: Appearance.sizes.gap + Appearance.sizes.band
    readonly property real corner: Appearance.sizes.roundOuter ? Appearance.sizes.windowRadius : 0

    visible: Hypr.fullscreenOn(win.screenName) && !Appearance.bare && !StreamState.floats(win.screenName)

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    exclusiveZone: 0

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "banditshell-fullscreen"

    mask: Region {}

    BlobField {
        anchors.fill: parent

        colour: Appearance.colour.surfaceSolid

        content: Qt.vector4d(win.ring, win.ring, width - win.ring * 2, height - win.ring * 2)
        gap: win.reach - win.ring
        band: win.ring
        baseRadius: Qt.vector4d(win.corner, win.corner, win.corner, win.corner)
    }
}
