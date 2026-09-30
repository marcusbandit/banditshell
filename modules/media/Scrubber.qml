pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.config
import qs.components
import qs.services
import "../../components/wave.js" as Wave

Item {
    id: root

    property bool watched: true

    readonly property real stroke: Appearance.sizes.scrubStroke
    readonly property real amp: Appearance.sizes.scrubWaveAmplitude
    readonly property real wavelength: Appearance.sizes.scrubWaveLength
    readonly property real gap: Appearance.padding.small

    readonly property bool timed: Media.length > 0

    readonly property real band: root.amp * 2 + root.stroke * 3
    readonly property real centre: root.band / 2

    readonly property real travel: Math.max(1, width - root.stroke)
    readonly property real pipX: root.shown * root.travel
    readonly property real waveEnd: root.timed ? Math.max(0, root.pipX - root.gap) : width

    readonly property bool active: pointer.pressed || pointer.containsMouse

    property real dragged: 0
    readonly property real shown: pointer.pressed ? root.dragged : glide.value

    implicitWidth: Appearance.sizes.menuWidth / 2
    implicitHeight: root.band + Appearance.padding.small + elapsed.implicitHeight

    Follow {
        id: glide

        target: Media.progress
        speed: Appearance.anim.trackSpeed
        epsilon: 0.001
    }

    Follow {
        id: swell

        target: Media.playing ? 1 : 0
        speed: Appearance.anim.resizeSpeed
        epsilon: 0.004
    }

    QtObject {
        id: clock

        property real t: 0
    }

    NumberAnimation {
        target: clock
        property: "t"
        from: 0
        to: 1
        duration: Math.round(root.wavelength / Appearance.sizes.scrubWaveSpeed * 1000)
        loops: Animation.Infinite

        running: root.watched && root.visible && Media.playing && swell.value > 0
    }

    Shape {
        id: wave

        x: 0
        y: root.centre - height / 2
        width: root.waveEnd

        height: root.amp * 2 + root.stroke
        visible: root.waveEnd > 0
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: Appearance.colour.text
            strokeWidth: root.stroke
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathPolyline {

                path: Wave.points(wave.width, root.amp * swell.value, root.wavelength, 2 * Math.PI * clock.t, Math.max(1, root.stroke / 2)).map(p => Qt.point(p[0], wave.height / 2 + p[1]))
            }
        }
    }

    G2Rect {
        x: root.pipX
        y: 0
        width: root.stroke
        height: root.band
        radius: width / 2
        color: Appearance.colour.text
        visible: root.timed

        scale: pointer.pressed ? 1.15 : root.active ? 1.3 : 1

        Behavior on scale {
            NumberAnimation {
                duration: Appearance.anim.fast
                easing.type: Easing.OutBack
            }
        }
    }

    G2Rect {
        x: root.pipX + root.stroke + root.gap
        y: root.centre - height / 2
        width: Math.max(0, root.width - x)
        height: root.stroke
        radius: height / 2
        visible: root.timed && width > 0
        color: Appearance.colour.fillStrong
    }

    StyledText {
        id: elapsed

        anchors.left: parent.left
        anchors.bottom: parent.bottom
        text: Media.timeLabel(root.timed ? (pointer.pressed ? root.dragged : root.shown) * Media.length : Media.position)
        color: Appearance.colour.textDim
    }

    StyledText {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        text: Media.timeLabel(Media.length)
        color: Appearance.colour.textDim
        visible: root.timed
    }

    MouseArea {
        id: pointer

        readonly property real grow: Math.max(0, (Appearance.sizes.minTarget - root.band) / 2)

        x: -Appearance.padding.small
        y: -grow
        width: root.width + Appearance.padding.small * 2
        height: root.band + grow * 2
        hoverEnabled: true

        preventStealing: true

        enabled: Media.canSeek && root.timed
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor

        function place(mx: real): void {
            const f = (pointer.mapToItem(root, mx, 0).x - root.stroke / 2) / root.travel;
            root.dragged = Math.max(0, Math.min(1, f));
        }

        onPressed: mouse => place(mouse.x)
        onPositionChanged: mouse => {
            if (pressed)
                place(mouse.x);
        }

        onReleased: {
            glide.value = root.dragged;
            Media.seekTo(root.dragged * Media.length);
        }

        onWheel: wheel => Media.seekBy(wheel.angleDelta.y / 120 * Appearance.sizes.scrubWheelSeek)
    }
}
