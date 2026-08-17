pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell.Wayland
import qs.config
import qs.components

// A WINDOW'S OWN CONTENT, cut to the shell's corner.
//
// The gesture used to draw a proxy: a card with the application's mark and title
// on it, on the argument that a screenshot would be a better lie. That was the
// wrong way round. What is in your hand IS the window, and the one thing that
// says so without a caption is the window itself, so this captures the real
// buffer and puts it on the card.
//
// The capture is of the TOPLEVEL, not of the screen, so it holds the window's
// own pixels and nothing the shell is drawing over them: the card can be dragged
// across the very area it is a picture of without recursing.
//
// MASKED THE WAY EVERY OTHER PICTURE IN THIS SHELL IS. A capture is a texture,
// not a path, so it keeps its own square corners inside a rounded plate, which
// is the most visible way there is to get a G2 corner wrong. G2Image's exact
// construction: render the picture to a layer, render a G2Rect of the same size
// as a mask, let the mask eat it. See components/G2Image.qml, which is this with
// a file behind it instead of a compositor.
Item {
    id: root

    // The window, as the model hands it over. The capture wants the wayland
    // handle hanging off it; taking the whole object rather than the handle
    // keeps every caller from having to know that.
    property var window: null

    property real radius: Appearance.sizes.windowRadius

    // WHETHER IT KEEPS UPDATING.
    //
    // One frame is enough for a target sitting still, and a still is also what
    // every phone shows in its own switcher. The window actually in the hand is
    // the exception: a video that freezes the instant you touch it says the
    // shell has taken a photograph of your window, where one that goes on
    // playing says you are holding the window.
    property bool live: false

    // Whether there is a frame yet. A capture is a round trip through the
    // compositor, so there is always at least one moment where there is not,
    // and the caller has to have something to draw in it.
    readonly property bool ready: view.hasContent

    ScreencopyView {
        id: view

        anchors.fill: parent

        captureSource: root.window?.wayland ?? null
        live: root.live
        // The pointer belongs to the screen, not to the window: a card in your
        // hand with somebody else's cursor frozen on it is a picture of a moment
        // rather than a picture of a window.
        paintCursor: false

        // Rendered to a texture for the mask to eat, never to the scene.
        layer.enabled: true
        visible: false
    }

    G2Rect {
        id: mask

        anchors.fill: parent
        radius: root.radius
        // Only the alpha matters; the colour is what makes it opaque.
        color: "white"
        layer.enabled: true
        visible: false
    }

    MultiEffect {
        anchors.fill: parent

        source: view
        maskEnabled: true
        maskSource: mask
        visible: root.ready
    }
}
