import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.components.blob

PanelWindow {
    id: win

    required property Chassis chassis

    property bool covering: false

    property bool hosting: false
    property bool taking: false
    property var hostedBlobs: []

    readonly property Item stage: stage

    readonly property real progress: settle.value
    readonly property bool yielded: settle.value > 0.01

    readonly property real ring: Appearance.sizes.seam
    readonly property real reach: win.chassis.gap + Appearance.sizes.band
    readonly property real corner: Appearance.sizes.roundOuter ? Appearance.sizes.windowRadius : 0

    function toward(rest: real, edge: real): real {
        return rest + (edge - rest) * win.progress;
    }

    onCoveringChanged: if (win.covering)
        fade.value = 1

    visible: win.hosting || !win.chassis.bare && (win.covering || win.yielded || fade.value > 0)

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
    WlrLayershell.keyboardFocus: win.taking ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "banditshell-fullscreen"

    mask: Region {
        item: win.taking ? stage : null
    }

    Follow {
        id: settle

        target: win.covering ? 1 : 0
        speed: Appearance.animation.revealSpeed
        epsilon: 0.001
        longestFrame: 0.05
    }

    Follow {
        id: fade

        target: win.covering || win.yielded ? 1 : 0
        speed: Appearance.animation.revealSpeed
        epsilon: 0.01
        longestFrame: 0.05
    }

    BlobField {
        anchors.fill: parent

        visible: !win.chassis.bare
        opacity: fade.value

        colour: Appearance.blend(Appearance.colour.surface, Appearance.colour.surfaceSolid, win.progress)

        content: Qt.vector4d(win.toward(win.chassis.holeX, win.ring), win.toward(win.chassis.holeY, win.ring), win.toward(win.chassis.holeWidth, width - win.ring * 2), win.toward(win.chassis.holeHeight, height - win.ring * 2))
        gap: win.toward(win.chassis.gap, win.reach - win.ring)
        band: win.toward(Appearance.sizes.band, win.ring)
        baseRadius: Qt.vector4d(win.toward(win.chassis.corners.x, win.corner), win.toward(win.chassis.corners.y, win.corner), win.toward(win.chassis.corners.z, win.corner), win.toward(win.chassis.corners.w, win.corner))
    }

    Item {
        id: stage

        anchors.fill: parent
        visible: win.hosting

        BlobField {
            anchors.fill: parent

            panels: win.hostedBlobs
            colour: Appearance.colour.surfaceSolid
            content: Qt.vector4d(-width, -height, width * 3, height * 3)
            gap: 0
            band: 0
            frameOn: 0
        }
    }
}
