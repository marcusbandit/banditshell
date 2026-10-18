import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.components.blob

PanelWindow {
    id: win

    required property Chassis chassis

    property bool covering: false
    property var window: null
    property var held: null

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

    readonly property bool tinting: !win.chassis.bare && (win.covering || win.yielded) && win.held !== null

    onCoveringChanged: if (win.covering)
        fade.value = 1
    onWindowChanged: if (win.window)
        win.held = win.window

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

    Follow {
        id: tint

        target: win.tinting && picture.hasContent ? 1 : 0
        speed: Appearance.animation.revealSpeed
        epsilon: 0.01
        longestFrame: 0.05
    }

    ScreencopyView {
        id: picture

        anchors.fill: parent
        captureSource: win.tinting ? win.held?.wayland ?? null : null
        paintCursor: false
        visible: false
    }

    Timer {
        interval: 125
        repeat: true
        running: picture.captureSource !== null && win.covering
        onTriggered: picture.captureFrame()
    }

    Item {
        id: swatch

        width: 32
        height: Math.max(1, Math.round(32 * win.height / Math.max(1, win.width)))
        visible: false
        layer.enabled: win.tinting
        layer.smooth: true

        ShaderEffectSource {
            anchors.fill: parent
            sourceItem: win.tinting ? picture : null
            mipmap: true
            smooth: true
        }
    }

    BlobField {
        id: edge

        anchors.fill: parent

        visible: !win.chassis.bare
        opacity: fade.value * (1 - win.progress * tint.value)

        colour: Appearance.blend(Appearance.colour.surface, Appearance.colour.surfaceSolid, win.progress)

        content: Qt.vector4d(win.toward(win.chassis.holeX, win.ring), win.toward(win.chassis.holeY, win.ring), win.toward(win.chassis.holeWidth, width - win.ring * 2), win.toward(win.chassis.holeHeight, height - win.ring * 2))
        gap: win.toward(win.chassis.gap, win.reach - win.ring)
        band: win.toward(Appearance.sizes.band, win.ring)
        baseRadius: Qt.vector4d(win.toward(win.chassis.corners.x, win.corner), win.toward(win.chassis.corners.y, win.corner), win.toward(win.chassis.corners.z, win.corner), win.toward(win.chassis.corners.w, win.corner))
    }

    BlobField {
        id: edgeShape

        anchors.fill: parent
        visible: false
        layer.enabled: win.tinting

        colour: "white"
        frameColour: "transparent"
        sheenColour: "white"
        content: edge.content
        gap: edge.gap
        band: edge.band
        baseRadius: edge.baseRadius
    }

    BlobField {
        anchors.fill: parent

        visible: win.tinting && tint.value > 0
        opacity: fade.value * win.progress * tint.value

        colour: "transparent"
        sheenColour: "transparent"
        content: edge.content
        gap: edge.gap
        band: edge.band
        baseRadius: edge.baseRadius
    }

    MultiEffect {
        anchors.fill: parent

        visible: win.tinting && tint.value > 0
        opacity: fade.value * win.progress * tint.value

        source: swatch
        brightness: -0.4
        maskEnabled: true
        maskSource: edgeShape
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
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
