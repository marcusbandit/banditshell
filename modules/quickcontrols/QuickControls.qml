pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root

    required property real border

    readonly property real grab: Config.values.control.touchEdges ? Math.max(root.border, Appearance.sizes.minTarget) : root.border

    readonly property real step: Config.values.volume.step

    readonly property real iconColumn: Appearance.font.iconSize

    readonly property real columnGap: Appearance.padding.small

    readonly property real rowGap: Appearance.padding.normal

    readonly property real sliderWidth: Appearance.sizes.screenSliderWidth

    readonly property real valueWidth: Appearance.sizes.screenValueWidth

    readonly property real contentWidth: root.iconColumn + root.columnGap + root.sliderWidth + root.columnGap + root.valueWidth

    readonly property real panelWidth: root.border + root.contentWidth + Appearance.padding.large * 2

    readonly property real panelHeight: root.contentHeight + Appearance.padding.large * 2

    readonly property real contentHeight: root.rowHeight * 3 + root.rowGap * 2

    readonly property real rowHeight: Math.max(root.iconColumn, Appearance.sizes.sliderHeight * 2.2 * 1.35)

    readonly property bool active: rail.containsMouse || rail.pressed || cardZone.containsMouse || root.pinned || linger.running

    readonly property bool held: rail.containsMouse || rail.pressed || cardZone.containsMouse

    readonly property Item maskItem: root.pinned ? catcher : cardZone

    readonly property Item grabItem: rail

    property bool pinned: false

    readonly property var blobs: [
        {
            x: root.width - root.panelWidth + (root.panelWidth + Appearance.sizes.melt) * (1 - reveal.value),
            y: (root.height - root.panelHeight) / 2,
            w: root.panelWidth,
            h: root.panelHeight,
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

    function warmthHue(k: int): color {
        if (k <= 0)
            return Appearance.colour.textFaint;

        const t = k / 100.0;
        let r, g, b;
        if (t <= 66) {
            r = 255;
            g = 99.4708025861 * Math.log(t) - 161.1195681661;
        } else {
            r = 329.698727446 * Math.pow(t - 60, -0.1332047592);
            g = 288.1221695283 * Math.pow(t - 60, -0.0755148492);
        }
        if (t >= 66)
            b = 255;
        else if (t <= 19)
            b = 0;
        else
            b = 138.5177312231 * Math.log(t - 10) - 305.0447927307;
        const m = Math.max(r, g, b);
        return Qt.rgba(r / m * 0.7 + 0.3, g / m * 0.7 + 0.3, b / m * 0.7 + 0.3, 1);
    }

    Follow {
        id: reveal

        speed: Appearance.animation.revealSpeed
        target: root.active ? 1 : 0
        epsilon: 0.005
    }

    Timer {
        id: linger

        interval: Config.values.screen.linger
    }

    Connections {
        target: Audio

        function onVolumeChanged(): void {
            linger.restart();
        }
    }

    Connections {
        target: Display

        function onLevelChanged(): void {
            linger.restart();
        }

        function onKelvinChanged(): void {
            linger.restart();
        }
    }

    MouseArea {
        id: catcher

        anchors.fill: parent
        enabled: root.pinned
        visible: root.pinned

        onClicked: mouse => {
            if (!cardZone.contains(catcher.mapToItem(cardZone, mouse.x, mouse.y)))
                root.pinned = false;
        }
    }

    MouseArea {
        id: cardZone

        anchors.right: parent.right
        y: (parent.height - height) / 2
        width: Math.max(root.border, root.panelWidth - (root.panelWidth + Appearance.sizes.melt) * (1 - reveal.value))
        height: root.panelHeight

        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        enabled: reveal.value > 0.01

        onWheel: wheel => root.nudge(wheel)

        Column {
            id: rows

            x: Appearance.padding.large
            anchors.verticalCenter: parent.verticalCenter
            width: root.contentWidth
            spacing: root.rowGap
            opacity: reveal.value

            Item {
                id: soundRow

                width: parent.width
                height: Math.max(root.iconColumn, soundSlider.height)

                Icon {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.iconColumn

                    name: Audio.icon(Audio.volume, Audio.muted)
                    color: Audio.muted ? Appearance.colour.textFaint : Appearance.colour.textDim

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -Appearance.padding.small
                        cursorShape: Qt.PointingHandCursor

                        onClicked: Audio.toggleMute()
                    }
                }

                Slider {
                    id: soundSlider

                    anchors.left: parent.left
                    anchors.leftMargin: root.iconColumn + root.columnGap
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.sliderWidth

                    value: Audio.volume
                    from: 0
                    to: Audio.maxVolume
                    warnAbove: 1
                    step: root.step
                    dimmed: Audio.muted

                    onMoved: value => Audio.setVolume(value)
                }

                StyledText {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.valueWidth

                    text: `${Math.round(Audio.volume * 100)}%`
                    color: Appearance.colour.textDim
                }
            }

            Item {
                id: brightRow

                width: parent.width
                height: Math.max(root.iconColumn, brightSlider.height)
                visible: Display.brightnessReady

                Icon {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.iconColumn

                    name: "brightness_6"
                    color: Display.levelKnown ? Appearance.colour.textDim : Appearance.colour.textFaint
                }

                Slider {
                    id: brightSlider

                    anchors.left: parent.left
                    anchors.leftMargin: root.iconColumn + root.columnGap
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.sliderWidth

                    value: Display.levelKnown ? Display.level : 0
                    from: 0
                    to: 1
                    dimmed: !Display.levelKnown

                    onMoved: value => Display.setLevel(value)
                }

                StyledText {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.valueWidth

                    text: Display.levelKnown ? `${Math.round(Display.level * 100)}%` : "..."
                    color: Appearance.colour.textDim
                }
            }

            Item {
                id: warmRow

                width: parent.width
                height: Math.max(root.iconColumn, warmSlider.height)

                Icon {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.iconColumn

                    name: "nightlight"
                    color: Display.warm ? root.warmthHue(Display.kelvin) : Appearance.colour.textFaint

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -Appearance.padding.small
                        cursorShape: Qt.PointingHandCursor

                        onClicked: Display.toggleWarm()
                    }
                }

                Slider {
                    id: warmSlider

                    anchors.left: parent.left
                    anchors.leftMargin: root.iconColumn + root.columnGap
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.sliderWidth

                    value: Display.kelvin > 0 ? Display.kelvin : Display.lastWarm
                    from: Display.warmest
                    to: Display.neutral
                    dimmed: !Display.warm
                    litOverride: root.warmthHue(Display.kelvin > 0 ? Display.kelvin : Display.lastWarm)

                    onMoved: value => Display.setWarmth(Math.round(value))
                }

                StyledText {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.valueWidth

                    text: Display.kelvin > 0 ? `${Display.kelvin}K` : "off"
                    color: Appearance.colour.textDim
                }
            }
        }
    }

    MouseArea {
        id: rail

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: root.grab
        height: parent.height * Config.values.screen.grabFraction

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

    readonly property real perPixel: Audio.maxVolume / Math.max(1, rail.height)
}
