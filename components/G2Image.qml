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

    // THE MASK FOLLOWS THE PICTURE, not the box it was given.
    //
    // Filling is the easy case: the picture covers the whole item, so a mask the
    // size of the item is the picture's own outline. Fitting is not. A wide
    // picture in a square box touches the sides and leaves the top and bottom
    // empty, so a full-size mask rounds four corners of nothing and lets the
    // picture keep its own square ones, which is the exact failure this
    // component exists to prevent, arrived at from the other direction.
    //
    // The aspect is read off the loaded image rather than being asked for. That
    // is safe only because `sourceSize` below is driven by the ITEM's size: were
    // the item sized from this in turn, the decode would depend on the thing it
    // decides and Qt would pick an order.
    readonly property real aspect: image.implicitHeight > 0 ? image.implicitWidth / image.implicitHeight : 1
    readonly property bool fitted: root.fillMode === Image.PreserveAspectFit
    readonly property real drawnWidth: root.fitted ? Math.min(root.width, root.height * root.aspect) : root.width
    readonly property real drawnHeight: root.fitted ? Math.min(root.height, root.width / root.aspect) : root.height

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

        anchors.centerIn: parent
        width: root.drawnWidth
        height: root.drawnHeight
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
