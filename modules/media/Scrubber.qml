pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root

    property bool watched: true

    property color ink: Appearance.colour.text

    property string family: Appearance.font.family

    readonly property real stroke: Appearance.sizes.scrubStroke
    readonly property real gap: Appearance.padding.small

    readonly property bool timed: Media.length > 0

    readonly property real band: Appearance.padding.hair * 2 + root.stroke * 3
    readonly property real centre: root.band / 2

    readonly property real travel: Math.max(1, width - root.stroke)
    readonly property real pipX: root.shown * root.travel
    readonly property real playedEnd: root.timed ? Math.max(0, root.pipX - root.gap) : width

    readonly property bool active: pointer.pressed || pointer.containsMouse

    property real dragged: 0
    property real hoverX: 0
    readonly property real shown: pointer.pressed ? root.dragged : glide.value

    property real live: 0
    property real untimed: 0

    Timer {
        interval: 1000
        repeat: true
        triggeredOnStart: true
        running: root.watched && root.visible && Media.playing && !root.timed
        onTriggered: root.untimed = Media.now()
    }

    implicitWidth: Appearance.sizes.menuWidth / 2
    implicitHeight: root.band + Appearance.padding.small + elapsed.implicitHeight

    FrameAnimation {
        running: root.watched && root.visible && Media.playing && root.timed

        onTriggered: root.live = Media.progressNow()
    }

    function catchUp(): void {
        root.live = Media.progressNow();
        glide.snap();
    }

    onWatchedChanged: if (root.watched)
        root.catchUp()

    Component.onCompleted: root.catchUp()

    Connections {
        target: Media
        enabled: root.watched

        function onPositionChanged(): void {
            if (!Media.playing)
                root.live = Media.progress;
        }

        function onTrackKeyChanged(): void {
            root.live = Media.progressNow();
        }
    }

    Follow {
        id: glide

        target: root.live
        speed: Appearance.animation.trackSpeed
        epsilon: 0.0005
    }

    FollowColour {
        id: playedTone

        target: Media.playing ? root.ink : Appearance.colour.textDim
        speed: Appearance.animation.revealSpeed
    }

    component Stretch: Item {
        id: stretch

        property color tone

        readonly property real cap: Math.min(stretch.height, stretch.width) / 2

        SquircleRect {
            width: stretch.cap
            height: stretch.height
            topLeftRadius: stretch.cap
            bottomLeftRadius: stretch.cap
            topRightRadius: 0
            bottomRightRadius: 0
            color: stretch.tone
        }

        Rectangle {
            x: stretch.cap
            width: Math.max(0, stretch.width - stretch.cap * 2)
            height: stretch.height
            color: stretch.tone
        }

        SquircleRect {
            x: stretch.width - stretch.cap
            width: stretch.cap
            height: stretch.height
            topLeftRadius: 0
            bottomLeftRadius: 0
            topRightRadius: stretch.cap
            bottomRightRadius: stretch.cap
            color: stretch.tone
        }
    }

    Stretch {
        y: root.centre - height / 2
        width: root.playedEnd
        height: root.stroke
        visible: width > 0
        tone: playedTone.value
    }

    SquircleRect {
        x: root.pipX
        y: 0
        width: root.stroke
        height: root.band
        pill: "object"
        color: root.ink
        visible: root.timed

        scale: pipScale.value

        Follow {
            id: pipScale

            target: pointer.pressed ? Appearance.press.lift : root.active ? Appearance.press.grab : 1
            speed: Appearance.animation.revealSpeed
            epsilon: Appearance.animation.fadeEpsilon
            startsAtTarget: true
        }
    }

    Stretch {
        x: root.pipX + root.stroke + root.gap
        y: root.centre - height / 2
        width: Math.max(0, root.width - x)
        height: root.stroke
        visible: root.timed && width > 0
        tone: Appearance.colour.fillStrong
    }

    TextMetrics {
        id: elapsedInk

        font: elapsed.font
        text: elapsed.text
    }

    TextMetrics {
        id: lengthInk

        font: total.font
        text: total.text
    }

    StyledText {
        id: elapsed

        anchors.left: parent.left
        anchors.leftMargin: -elapsedInk.tightBoundingRect.x
        anchors.bottom: parent.bottom
        text: Media.timeLabel(root.timed ? root.shown * Media.length : Media.playing ? root.untimed : Media.position)
        color: Appearance.colour.textDim
        font.family: root.family
    }

    StyledText {
        id: total

        anchors.right: parent.right
        anchors.rightMargin: -(lengthInk.advanceWidth - lengthInk.tightBoundingRect.x - lengthInk.tightBoundingRect.width)
        anchors.bottom: parent.bottom
        text: Media.timeLabel(Media.length)
        color: Appearance.colour.textDim
        font.family: root.family
        visible: root.timed
    }

    Item {
        id: peek

        readonly property real at: Math.max(0, Math.min(1, (root.hoverX - root.stroke / 2) / root.travel))

        visible: root.timed && pointer.containsMouse && !pointer.pressed && Media.canSeek
        x: Math.max(0, Math.min(root.width - width, root.hoverX - width / 2))
        y: -height - Appearance.padding.small
        width: peekText.implicitWidth + Appearance.padding.normal * 2
        height: peekText.implicitHeight + Appearance.padding.small

        SquircleRect {
            anchors.fill: parent
            radius: Appearance.rounding.small
            color: Appearance.colour.surfaceSolid
        }

        StyledText {
            id: peekText

            anchors.centerIn: parent
            text: Media.timeLabel(peek.at * Media.length)
            font.family: root.family
        }
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
            root.hoverX = pointer.mapToItem(root, mouse.x, 0).x;
            if (pressed)
                place(mouse.x);
        }

        onReleased: {
            glide.value = root.dragged;
            root.live = root.dragged;
            Media.seekTo(root.dragged * Media.length);
        }

        onWheel: wheel => Media.seekBy(wheel.angleDelta.y / 120 * Config.values.media.wheelSeek)
    }
}
