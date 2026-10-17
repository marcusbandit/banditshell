pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import qs.config
import qs.components
import qs.services

Item {
    id: root

    property bool active: true

    property string output: ""

    property int typed: Lock.typed

    property bool opening: Lock.opening

    property bool failed: Lock.failed

    property bool bloom: Lock.seeingThrough

    property bool awake: Lock.awake

    readonly property real rested: 1 - presence.value

    property point cursor: Qt.point(-100000, -100000)

    readonly property string family: Appearance.font.lock

    property string shownStatus: ""

    onStatusChanged: if (root.status !== "")
        root.shownStatus = root.status

    property string status: {
        if (Lock.waiting)
            return `try again in ${Lock.waitSeconds} s`;
        if (root.failed && Lock.message && root.typed === 0)
            return Lock.message;
        if (Keymap.capsLock)
            return "caps lock is on";
        return "";
    }

    readonly property bool warning: Lock.waiting || (root.failed && root.typed === 0)

    readonly property bool hardware: GraphicsInfo.api !== GraphicsInfo.Software

    readonly property real releaseAt: 0.03

    readonly property real contentIn: Math.max(0, (cover.value - 0.55) / 0.45)

    readonly property real veil: root.opening ? 1 : cover.value

    readonly property real digitHeight: Math.max(40, Math.min(160, Math.round(Math.min(root.width, root.height) * Appearance.sizes.lockClockShare)))

    readonly property real overscan: 64

    property real seed: Math.random() * Math.PI * 2

    function send(marks: int): void {
        field.send(marks);
        scattered.target = 0;
        scattered.snap();
        alarmed.target = 0;
        alarmed.snap();
    }

    function place(): void {
        if (root.active && !root.opening && (!root.bloom || Lock.sleeping))
            cover.value = 1;
    }

    function refuse(): void {
        alarmed.target = 1;
        scattered.target = 1;
    }

    onTypedChanged: if (root.typed > 0)
        alarmed.target = 0

    Connections {
        target: Lock

        function onSent(marks: int): void {
            root.send(marks);
        }

        function onRefused(): void {
            root.refuse();
        }

        function onSleepingChanged(): void {
            if (Lock.sleeping)
                Qt.callLater(root.place);
        }
    }

    readonly property real restingY: root.height * 0.46 - field.y - field.height / 2
    readonly property real clearingY: power.y - Appearance.padding.large - (info.y + info.reach)

    Follow {
        id: lift

        target: Math.max(Appearance.padding.huge, Math.min(root.restingY, root.clearingY))
        speed: Appearance.animation.trackSpeed * 0.5
        Component.onCompleted: lift.snap()
    }

    Follow {
        id: telling

        target: root.status !== "" ? 1 : 0
        speed: Appearance.animation.revealSpeed
        epsilon: 0.004
    }

    Follow {
        id: presence

        target: root.awake ? 1 : 0
        speed: root.awake ? Appearance.animation.revealSpeed * 0.5 : Appearance.animation.railSpeed * 0.3
        epsilon: 0.002
    }

    Follow {
        id: cover

        target: root.active && !(root.opening && gathered.value > 0.6) ? 1 : 0
        speed: root.opening ? Appearance.sizes.lockReveal * 1.4 : Appearance.sizes.lockReveal
        epsilon: 0.001
    }

    Follow {
        id: gathered

        target: root.opening ? 1 : 0
        speed: Appearance.animation.trackSpeed
        epsilon: 0.002
    }

    Follow {
        id: scattered

        speed: Appearance.animation.trackSpeed * 0.6
        epsilon: 0.002
    }

    Follow {
        id: alarmed

        speed: Appearance.animation.revealSpeed
        epsilon: 0.002
    }

    readonly property bool sealed: cover.value === 1
    readonly property bool gone: root.opening && cover.value <= root.releaseAt

    onSealedChanged: if (root.sealed)
        Lock.covered()
    onOpeningChanged: if (!root.opening && root.sealed)
        Lock.covered()
    onActiveChanged: root.place()
    onGoneChanged: if (root.gone)
        Lock.opened()

    Component.onCompleted: {
        root.place();
        keys.forceActiveFocus();
        Keymap.refresh();
        Weather.refresh();
    }

    Timer {
        interval: 5 * 60 * 1000
        repeat: true
        running: root.active
        onTriggered: Weather.refresh()
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    Item {
        id: scene

        anchors.fill: parent

        visible: cover.value > 0
        opacity: root.hardware ? 1 : cover.value

        layer.enabled: root.hardware && cover.value < 1
        layer.effect: RevealMask {
            progress: cover.value
            aspect: scene.width / Math.max(1, scene.height)
            origin: Qt.point((stack.x + field.x + field.width / 2) / Math.max(1, scene.width), (stack.y + field.y + field.height / 2) / Math.max(1, scene.height))
            seed: root.seed
            softness: 0.08
        }

        Rectangle {
            anchors.fill: parent
            color: Appearance.colour.ink
        }

        Image {
            id: paper

            anchors.fill: parent
            anchors.margins: -root.overscan

            source: Wallpaper.enabled && root.width > 0 ? Wallpaper.faceOf(Wallpaper.currentOn(root.output)) : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true

            sourceSize.width: Math.round(paper.width * Screen.devicePixelRatio)
            sourceSize.height: Math.round(paper.height * Screen.devicePixelRatio)
            visible: false
        }

        MultiEffect {
            anchors.fill: paper
            source: paper
            visible: paper.status === Image.Ready

            blurEnabled: true
            blurMax: 64
            blur: root.veil * Appearance.sizes.lockBlur
            saturation: -root.veil * Appearance.sizes.lockDesaturate
            autoPaddingEnabled: false
        }

        Rectangle {
            anchors.fill: parent
            color: Appearance.colour.ink
            opacity: root.veil * Math.min(1, Appearance.sizes.lockDim * 0.6 + root.rested * 0.25)
        }

        Column {
            id: stack

            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(lift.value)

            width: Math.max(Appearance.sizes.lockField, time.implicitWidth)

            Item {
                width: parent.width
                height: words.height
                opacity: root.contentIn

                Column {
                    id: words

                    width: parent.width
                    y: (1 - root.contentIn) * Appearance.padding.large
                    spacing: Appearance.padding.normal

                    LockClock {
                        id: time

                        anchors.horizontalCenter: parent.horizontalCenter
                        width: implicitWidth
                        height: implicitHeight

                        hours: TimeFormat.hourPart(clock.date)
                        minutes: TimeFormat.minutePart(clock.date)
                        suffix: TimeFormat.clock24 ? "" : clock.date.getHours() < 12 ? "am" : "pm"
                        stacked: Appearance.sizes.lockClockStacked
                        size: Math.round(root.digitHeight / 0.73)
                        family: root.family
                        weight: 220 + 400 * presence.value
                        opacity: 0.6 + 0.4 * presence.value
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        opacity: 0.6 + 0.4 * presence.value

                        text: TimeFormat.dateText(clock.date, "headline")
                        color: Appearance.colour.textDim
                        font.family: root.family
                        font.pixelSize: Math.round(time.size * 0.2)
                        font.variableAxes: ({ "wght": 300 + 160 * presence.value })
                        renderType: Text.NativeRendering
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: Weather.ready
                        spacing: Appearance.padding.small
                        opacity: 0.6 + 0.4 * presence.value

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: Weather.icon
                            size: Math.round(Appearance.font.size.small * 1.1)
                            fill: 1
                            color: Appearance.colour.textDim
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Weather.temperature
                            color: Appearance.colour.textDim
                            font.family: root.family
                            font.pixelSize: Math.round(Appearance.font.size.small * 0.9)
                            font.variableAxes: ({ "wght": 600 })
                            font.features: ({ "tnum": 1 })
                            renderType: Text.NativeRendering
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Weather.summary.toLowerCase()
                            color: Appearance.colour.textFaint
                            font.family: root.family
                            font.pixelSize: Math.round(Appearance.font.size.small * 0.9)
                            renderType: Text.NativeRendering
                        }
                    }
                }
            }

            Item {
                width: 1
                height: Appearance.padding.huge * 1.5
            }

            LockField {
                id: field

                anchors.horizontalCenter: parent.horizontalCenter
                opacity: 0.45 + 0.55 * presence.value
                width: Appearance.sizes.lockField

                family: root.family
                typed: root.typed
                gather: gathered.value
                scatter: scattered.value
                alarm: alarmed.value
                waiting: Lock.waiting
            }

            Item {
                width: 1
                height: Appearance.padding.normal
            }

            Text {
                width: parent.width
                height: Appearance.font.line.small
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                opacity: root.contentIn * telling.value

                text: root.shownStatus
                color: root.warning ? Appearance.colour.alarm : Appearance.colour.textDim
                font.family: root.family
                font.pixelSize: Math.round(Appearance.font.size.small * 0.9)
                font.variableAxes: ({ "wght": 500 })
                renderType: Text.NativeRendering
            }

            Item {
                width: 1
                height: Appearance.padding.huge
            }

            LockInfo {
                id: info

                anchors.horizontalCenter: parent.horizontalCenter
                family: root.family
                watched: root.sealed
                opacity: root.contentIn * (0.5 + 0.5 * presence.value)
            }
        }

        LockPower {
            id: power

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Appearance.padding.huge * 2

            family: root.family
            open: root.awake && root.cursor.y > root.height - Appearance.padding.huge * 6
            opacity: root.contentIn
        }
    }

    HoverHandler {
        id: hovering

        onPointChanged: {
            Lock.stir();
            root.cursor = hovering.point.position;
        }
    }

    PointHandler {
        id: touching

        onActiveChanged: if (touching.active) {
            Lock.stir();
            root.cursor = touching.point.position;
        }
    }

    WheelHandler {
        onWheel: Lock.stir()
    }

    Item {
        id: keys

        anchors.fill: parent
        focus: true

        readonly property bool surfaceActive: keys.Window.active
        onSurfaceActiveChanged: if (keys.surfaceActive)
            keys.forceActiveFocus()

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                Lock.enter();
            else if (event.key === Qt.Key_Backspace)
                Lock.erase(!!(event.modifiers & Qt.ControlModifier));
            else if (event.key === Qt.Key_Escape)
                Lock.erase(true);
            else if (event.key === Qt.Key_CapsLock)
                Qt.callLater(Keymap.refresh);
            else if (event.text)
                Lock.type(event.text);
            event.accepted = true;
        }
    }
}
