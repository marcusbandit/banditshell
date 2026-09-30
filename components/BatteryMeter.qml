import QtQuick
import QtQuick.Shapes
import qs.config

Item {
    id: root

    property real level: 0
    property bool charging: false

    property bool low: false

    property color colour: Appearance.colour.text

    property color trackColour: Appearance.colour.fillStronger

    readonly property color well: root.low ? Qt.rgba(root.colour.r, root.colour.g, root.colour.b, 0.18 + 0.34 * root.throb) : root.trackColour

    property color boltColour: Appearance.colour.accent

    readonly property real unit: Appearance.font.iconSize

    readonly property real capWidth: Math.max(2, Math.round(unit * 0.09))
    readonly property real inset: Math.max(1, Math.round(unit * 0.08))

    implicitWidth: Math.round(unit)
    implicitHeight: Math.round(unit * 0.55)

    Follow {
        id: charge

        target: Math.max(0, Math.min(1, root.level))
        speed: Appearance.anim.trackSpeed
        epsilon: 0.001
    }

    readonly property var boltPoints: [[0.62, 0.00], [0.00, 0.58], [0.38, 0.58], [0.30, 1.00], [1.00, 0.40], [0.55, 0.40]]

    readonly property real boltHeight: 0.86
    readonly property real boltAspect: 0.62

    function bolt(w: real, h: real): string {
        const bh = h * root.boltHeight;
        const bw = bh * root.boltAspect;
        const x = (w - bw) / 2;
        const y = (h - bh) / 2;
        return root.boltPoints.map((p, i) => `${i === 0 ? "M" : "L"} ${x + p[0] * bw} ${y + p[1] * bh}`).join(" ") + " Z";
    }

    property real sweep: 0

    NumberAnimation on sweep {
        running: root.charging && charge.value < 1
        loops: Animation.Infinite
        from: 0
        to: 1
        duration: Appearance.anim.slow * 6
    }

    property real throb: 0

    SequentialAnimation on throb {
        running: root.low
        loops: Animation.Infinite

        NumberAnimation {
            from: 0
            to: 1
            duration: Appearance.anim.slow * 4
            easing.type: Easing.InOutSine
        }

        NumberAnimation {
            from: 1
            to: 0
            duration: Appearance.anim.slow * 4
            easing.type: Easing.InOutSine
        }
    }

    SquircleRect {
        id: track

        width: root.width - root.capWidth
        height: root.height
        radius: root.height / 3
        color: root.well

        readonly property real span: width - root.inset * 2

        SquircleRect {
            x: root.inset
            y: root.inset
            width: track.span * charge.value
            height: track.height - root.inset * 2
            radius: height / 3
            color: root.colour
        }

        SquircleRect {
            visible: root.charging
            x: root.inset + track.span * charge.value
            y: root.inset
            width: track.span * (1 - charge.value) * root.sweep
            height: track.height - root.inset * 2
            radius: height / 3
            color: root.colour
            opacity: 0.7 * (1 - root.sweep * root.sweep * root.sweep)
        }

        Shape {
            anchors.fill: parent
            visible: root.charging
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: root.boltColour
                strokeColor: root.well
                strokeWidth: Math.max(1, Math.round(root.height * 0.1))

                PathSvg {
                    path: root.bolt(track.width, track.height)
                }
            }
        }
    }

    SquircleRect {
        x: root.width - root.capWidth
        y: (root.height - height) / 2
        width: root.capWidth
        height: Math.round(root.height * 0.45)
        radius: width / 3
        color: root.well
    }
}
