import QtQuick
import QtQuick.Effects
import qs.config

// A picture, cut to the shell's corner.
//
// Every rounded shape here goes through G2Rect, and an image is the one thing
// that cannot: it is a texture, not a path, so a picture dropped inside a
// rounded plate keeps its own SQUARE corners over the plate's curve. It is the
// most visible way there is to get a G2 corner wrong, because the eye is
// comparing two corners a pixel apart rather than judging one on its own.
//
// So the picture is rendered to a texture, a G2Rect of the same size is rendered
// as a mask, and the mask eats the texture. The shape still comes from the one
// primitive; only the way it is applied is different. Cropped to fill by
// default, because anything not square would otherwise letterbox and sit in a
// band of whatever is behind it.
//
// The plate under it is a separate G2Rect, and should be hidden while this is
// ready: a step of fill showing at the corners reads as the image not fitting.
Item {
    id: root

    property string source: ""
    property real radius: Appearance.rounding.normal
    property int fillMode: Image.PreserveAspectCrop

    readonly property bool ready: image.status === Image.Ready

    Image {
        id: image

        anchors.fill: parent
        source: root.source
        fillMode: root.fillMode
        asynchronous: true
        smooth: true
        sourceSize.width: root.width * Screen.devicePixelRatio
        sourceSize.height: root.height * Screen.devicePixelRatio
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
        source: image
        maskEnabled: true
        maskSource: mask
        visible: root.ready
    }
}
