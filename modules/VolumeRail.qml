import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root

    required property real border

    readonly property real grab: Appearance.sizes.touchEdges ? Math.max(root.border, Appearance.sizes.minTarget) : root.border

    readonly property real swellBy: Math.max(1, Appearance.sizes.gap - 1)

    readonly property real step: Appearance.sizes.volumeStep

    readonly property real ceiling: Audio.maxVolume
    readonly property real warnAbove: 1

    readonly property bool muted: Audio.muted
    readonly property real volume: Audio.volume

    readonly property color lit: root.muted ? Appearance.colour.textFaint : root.volume > root.warnAbove ? Appearance.colour.accent : Appearance.colour.text

    readonly property bool active: rail.containsMouse || rail.pressed || panelZone.containsMouse || linger.running

    readonly property bool held: rail.containsMouse || rail.pressed || panelZone.containsMouse

    readonly property Item maskItem: panelZone

    readonly property Item grabItem: rail

    readonly property real meterLength: glyph.implicitHeight * Appearance.sizes.volumeMeterGlyphs

    readonly property real contentWidth: Math.max(Appearance.sizes.volumeRailWidth, Appearance.font.iconSize)
    readonly property real contentHeight: root.meterLength + Appearance.padding.normal + glyph.implicitHeight

    readonly property real panelWidth: root.border + root.contentWidth + Appearance.padding.large * 2
    readonly property real panelHeight: root.contentHeight + Appearance.padding.large * 2

    readonly property real bodyHeight: root.panelHeight + swell.value * 2

    readonly property var blobs: [
        {
            x: root.width - root.panelWidth + (root.panelWidth + Appearance.sizes.melt) * (1 - reveal.value),
            y: (root.height - root.bodyHeight) / 2,
            w: root.panelWidth,
            h: root.bodyHeight,
            radius: Appearance.rounding.large,
            smooth: Math.min(Appearance.sizes.melt, Math.min(root.panelWidth, root.panelHeight) / 2)
        }
    ]

    function nudge(wheel: var): void {
        const touchpad = wheel.pixelDelta.x !== 0 || wheel.pixelDelta.y !== 0;
        const natural = wheel.inverted || (touchpad ? Compositor.naturalScrollTouchpad : Compositor.naturalScrollMouse);
        const notches = wheel.angleDelta.y / 120 * (natural ? -1 : 1);
        Audio.setVolume(Audio.volume + notches * root.step);
    }

    readonly property real perPixel: root.ceiling / Math.max(1, rail.height)

    Follow {
        id: reveal
        speed: Appearance.anim.revealSpeed
        target: root.active ? 1 : 0
        epsilon: 0.005
    }

    Follow {
        id: swell

        target: root.held && reveal.settled ? root.swellBy : 0
        speed: Appearance.anim.revealSpeed

        epsilon: 0.2
    }

    Follow {
        id: level
        speed: Appearance.anim.trackSpeed
        target: root.volume
        epsilon: 0.001
    }

    Timer {
        id: linger
        interval: Appearance.sizes.volumeLinger
    }

    Connections {
        target: Audio

        function onVolumeChanged(): void {
            linger.restart();
        }

        function onMutedChanged(): void {
            linger.restart();
        }
    }

    MouseArea {
        id: panelZone

        anchors.right: parent.right
        y: (parent.height - height) / 2
        width: Math.max(root.border, root.panelWidth - (root.panelWidth + Appearance.sizes.melt) * (1 - reveal.value))
        height: root.bodyHeight

        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        enabled: reveal.value > 0.01

        onWheel: wheel => root.nudge(wheel)

        Item {
            id: content

            x: Appearance.padding.large
            anchors.verticalCenter: parent.verticalCenter
            width: root.contentWidth
            height: root.contentHeight
            opacity: reveal.value

            G2Rect {
                id: track

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                width: Appearance.sizes.volumeRailWidth
                height: root.meterLength
                radius: width / 2
                color: Appearance.colour.fillStronger

                G2Rect {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: Math.max(0, Math.min(1, level.value / root.ceiling)) * parent.height
                    radius: width / 2
                    color: root.lit
                }

                Rectangle {
                    x: 0
                    y: parent.height * (1 - root.warnAbove / root.ceiling) - height / 2
                    width: parent.width
                    height: Appearance.font.stem
                    color: Appearance.colour.surface
                }
            }

            Icon {
                id: glyph

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom

                name: Audio.icon(root.volume, root.muted)
                color: root.muted ? Appearance.colour.textFaint : Appearance.colour.textDim
            }
        }
    }

    MouseArea {
        id: rail

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: root.grab
        height: parent.height * Appearance.sizes.volumeGrabFraction

        property real fromY: 0
        property real fromVolume: 0

        hoverEnabled: true

        acceptedButtons: Qt.LeftButton

        onPressed: mouse => {
            rail.fromY = mouse.y;
            rail.fromVolume = Audio.volume;
        }

        onPositionChanged: mouse => {
            if (rail.pressed)
                Audio.setVolume(rail.fromVolume + (rail.fromY - mouse.y) * root.perPixel);
        }

        onWheel: wheel => root.nudge(wheel)
    }
}
