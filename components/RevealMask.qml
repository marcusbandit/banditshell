import QtQuick
import qs.config

// The circle that a new wallpaper opens through.
//
// A `layer.effect`, which is a specific contract rather than a general shader:
// Qt renders the item this is attached to into a texture, hands that texture in
// as `source`, and draws what comes back in the item's place. So this never has
// to know what it is masking, which is the whole point, because what it is
// masking is a photograph or an SVG or a video and the mask has no opinion.
//
// Everything about the shape is in components/reveal.frag. This is the QML side
// of its uniform block, and the only rule here is that every member of that
// block has a property of the same name: Qt matches them by name and refuses
// the shader outright if one is missing, which is a blank screen rather than an
// error message.
ShaderEffect {
    id: root

    // Qt fills this in itself when the effect is used as a `layer.effect`; it is
    // declared so the pairing is visible from this side rather than being a
    // convention you have to already know.
    property var source

    property real progress: 1
    property real aspect: 1

    // Feathered by a fraction of the screen rather than a number of pixels, so
    // the edge is the same softness on a laptop panel and on a 4K monitor.
    // Wide enough that the boundary reads as the two pictures bleeding into
    // each other rather than as one being cut out of the other, which is the
    // difference between an arrival and a wipe.
    property real softness: 0.14

    // How far from a circle. A third is a decidedly lumpy blob and still closes
    // over every corner; past about a half the lobes start reading as spikes.
    property real wobble: 0.32

    // Which blob. Rerolled per transition by whatever drives this, so no two
    // changes arrive in the same shape.
    property real seed: 0

    // `point` on the QML side, vec2 in the block. Qt converts.
    property point origin: Qt.point(0.5, 0.5)

    fragmentShader: Qt.resolvedUrl("reveal.frag.qsb")
}
