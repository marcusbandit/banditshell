pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root

    required property var modelData
    required property int index

    property int current: -1
    property real time: 0
    property bool seekable: false

    signal picked(real at)

    readonly property bool gap: !!root.modelData.gap
    readonly property bool opposite: root.modelData.side === "right"
    readonly property real at: root.time + Lyrics.lead

    readonly property bool singing: root.gap ? root.at >= root.modelData.start && root.at < root.modelData.end : root.at >= root.modelData.start - 0.05 && root.at < root.modelData.end + 0.35
    readonly property bool focused: root.index === root.current
    readonly property bool upcoming: root.current < 0 || root.index > root.current
    readonly property int distance: root.current < 0 ? root.index + 1 : Math.abs(root.index - root.current)

    readonly property real padX: Appearance.padding.normal
    readonly property real padY: Appearance.padding.hair

    width: parent?.width ?? 0
    height: root.gap ? opening.value * (dots.height + root.padY * 2) : stack.height + root.padY * 2

    Follow {
        id: focus

        target: root.focused || root.singing ? 1 : root.upcoming ? Math.max(0.2, 0.62 - (root.distance - 1) * 0.12) : Math.max(0.14, 0.4 - (root.distance - 1) * 0.1)
        speed: Appearance.animation.revealSpeed * 0.5
        epsilon: 0.003
    }

    Follow {
        id: opening

        target: root.gap && (root.singing || root.focused) ? 1 : 0
        speed: Appearance.animation.resizeSpeed
        epsilon: 0.003
    }

    opacity: root.gap ? opening.value : focus.value
    visible: opacity > 0.004

    SquircleRect {
        anchors.fill: parent
        radius: Appearance.rounding.small
        color: Appearance.colour.fill
        opacity: pointer.containsMouse && root.seekable && !root.gap ? 1 : 0
    }

    Column {
        id: stack

        x: root.padX
        y: root.padY
        width: root.width - root.padX * 2
        spacing: Appearance.padding.hair
        visible: !root.gap

        LyricBlock {
            width: parent.width
            visible: root.modelData.lead.length > 0
            words: root.modelData.lead
            opposite: root.opposite
            lit: root.singing
            position: root.singing ? Lyrics.progressOf(root.modelData.lead, root.time) : 0
        }

        LyricBlock {
            width: parent.width
            visible: root.modelData.back.length > 0
            words: root.modelData.back
            pixelSize: Appearance.font.size.small
            opposite: root.opposite
            lit: root.singing
            position: root.singing ? Lyrics.progressOf(root.modelData.back, root.time) : 0
            dim: Appearance.colour.textFaint
        }
    }

    QtObject {
        id: breath

        property real t: 0
    }

    NumberAnimation {
        target: breath
        property: "t"
        from: 0
        to: Math.PI * 2
        duration: 2400
        loops: Animation.Infinite
        running: root.gap && root.singing && root.visible && !Appearance.lessMotion
    }

    Row {
        id: dots

        readonly property real fill: root.gap && root.singing ? Lyrics.gapFillAt(root.modelData, root.time) : 0
        readonly property real size: Appearance.padding.normal

        x: root.opposite ? root.width - root.padX - width : root.padX
        y: root.padY
        height: Appearance.font.line.normal
        spacing: Appearance.padding.small
        visible: root.gap
        scale: 1 + 0.08 * Math.sin(breath.t)
        transformOrigin: root.opposite ? Item.Right : Item.Left

        Repeater {
            model: root.gap ? 3 : 0

            SquircleRect {
                required property int index

                readonly property real lit: Math.max(0, Math.min(1, dots.fill * 3 - index))

                y: (dots.height - height) / 2
                width: dots.size
                height: dots.size
                pill: "object"
                color: Appearance.colour.text
                opacity: 0.22 + 0.78 * lit
                scale: 0.75 + 0.3 * lit
            }
        }
    }

    MouseArea {
        id: pointer

        anchors.fill: parent
        hoverEnabled: true
        enabled: root.seekable && !root.gap
        cursorShape: Qt.PointingHandCursor

        onClicked: root.picked(root.modelData.start)
    }
}
