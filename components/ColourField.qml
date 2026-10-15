import QtQuick
import qs.config

Item {
    id: root

    property var colours: []
    property real radius: 0
    property real power: Appearance.rounding.power
    property bool moving: true
    property int fade: Appearance.animation.fade.slow * 3

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
        running: root.moving && root.visible
        onTriggered: root.drift = (Date.now() % root.period) / root.period
    }

    ShaderEffect {
        anchors.fill: parent

        property color first: root.colourAt(0)
        property color second: root.colourAt(1)
        property color third: root.colourAt(2)
        property color fourth: root.colourAt(3)
        property real w0: Math.max(0.01, root.shareAt(0))
        property real w1: root.shareAt(1)
        property real w2: root.shareAt(2)
        property real w3: root.shareAt(3)

        Behavior on first {
            ColorAnimation {
                duration: root.fade
            }
        }
        Behavior on second {
            ColorAnimation {
                duration: root.fade
            }
        }
        Behavior on third {
            ColorAnimation {
                duration: root.fade
            }
        }
        Behavior on fourth {
            ColorAnimation {
                duration: root.fade
            }
        }
        Behavior on w0 {
            NumberAnimation {
                duration: root.fade
            }
        }
        Behavior on w1 {
            NumberAnimation {
                duration: root.fade
            }
        }
        Behavior on w2 {
            NumberAnimation {
                duration: root.fade
            }
        }
        Behavior on w3 {
            NumberAnimation {
                duration: root.fade
            }
        }

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
