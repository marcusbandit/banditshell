import QtQuick
import qs.config
import "colour-drift.js" as Drift

Item {
    id: root

    property var colours: []
    property real radius: 0
    property real power: Appearance.rounding.power
    property bool moving: true

    property real drift: 0

    readonly property var picked: root.colours.slice(0, 4)

    function colourAt(i: int): color {
        return root.picked[i]?.colour ?? root.picked[0]?.colour ?? Appearance.colour.ink;
    }

    function shareAt(i: int): real {
        return root.picked[i]?.share ?? 0;
    }

    readonly property int period: 40000

    FrameAnimation {
        running: root.moving && root.visible && !Appearance.lessMotion
        onTriggered: root.drift = Drift.phaseAt(Date.now(), root.period)
    }

    readonly property real fadeSpeed: Appearance.animation.settleSpeed * 0.5

    FollowColour {
        id: tone0

        target: root.colourAt(0)
        speed: root.fadeSpeed
    }

    FollowColour {
        id: tone1

        target: root.colourAt(1)
        speed: root.fadeSpeed
    }

    FollowColour {
        id: tone2

        target: root.colourAt(2)
        speed: root.fadeSpeed
    }

    FollowColour {
        id: tone3

        target: root.colourAt(3)
        speed: root.fadeSpeed
    }

    Follow {
        id: share0

        target: Math.max(0.01, root.shareAt(0))
        speed: root.fadeSpeed
        epsilon: Appearance.animation.fadeEpsilon
        startsAtTarget: true
    }

    Follow {
        id: share1

        target: root.shareAt(1)
        speed: root.fadeSpeed
        epsilon: Appearance.animation.fadeEpsilon
        startsAtTarget: true
    }

    Follow {
        id: share2

        target: root.shareAt(2)
        speed: root.fadeSpeed
        epsilon: Appearance.animation.fadeEpsilon
        startsAtTarget: true
    }

    Follow {
        id: share3

        target: root.shareAt(3)
        speed: root.fadeSpeed
        epsilon: Appearance.animation.fadeEpsilon
        startsAtTarget: true
    }

    ShaderEffect {
        anchors.fill: parent

        property color first: tone0.value
        property color second: tone1.value
        property color third: tone2.value
        property color fourth: tone3.value
        property real w0: share0.value
        property real w1: share1.value
        property real w2: share2.value
        property real w3: share3.value

        readonly property vector4d size: Qt.vector4d(width, height, root.drift, root.radius)
        readonly property color c0: first
        readonly property color c1: second
        readonly property color c2: third
        readonly property color c3: fourth
        readonly property vector4d shares: Qt.vector4d(w0, w1, w2, w3)
        readonly property vector4d look: Qt.vector4d(root.power, 0, 0, 0)

        fragmentShader: Qt.resolvedUrl("colourfield.frag.qsb")
    }
}
