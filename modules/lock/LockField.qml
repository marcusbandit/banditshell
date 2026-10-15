pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root

    property int typed: 0

    property real gather: 0

    property real scatter: 0

    property real alarm: 0

    property bool waiting: false

    property string placeholder: "password"

    property string family: Appearance.font.lock

    readonly property int capacity: 40

    readonly property real dot: Math.round(Appearance.font.size.small / 2)
    readonly property real caretWidth: 2
    readonly property real roomy: root.dot * 2
    readonly property real tagRoom: Keymap.several ? tag.width + Appearance.padding.normal : 0
    readonly property real usable: root.width - Appearance.padding.large * 2 - root.tagRoom * 2

    readonly property int shown: Math.min(root.typed, root.capacity)

    readonly property real pitch: Math.min(root.roomy, root.usable / (root.shown + 1))
    readonly property real start: (root.width - root.shown * root.pitch - root.caretWidth) / 2

    property int sentMarks: 0
    property real sentPitch: root.roomy
    property real sentStart: 0

    property bool lit: true

    readonly property bool prompting: root.typed === 0 && !root.waiting && !(root.sentMarks > 0 && root.scatter < 0.95)

    function send(marks: int): void {
        root.sentPitch = spacing.value;
        root.sentStart = from.value;
        root.sentMarks = Math.min(marks, root.capacity);
        for (let i = 0; i < root.capacity; i++) {
            sent.itemAt(i)?.place(i < root.sentMarks);
            live.itemAt(i)?.place(false);
        }
    }

    function centre(index: int, first: real, pitch: real): real {
        return first + pitch / 2 + index * pitch;
    }

    implicitWidth: Appearance.sizes.lockField
    implicitHeight: Appearance.sizes.lockFieldHeight

    onTypedChanged: {
        root.lit = true;
        blinker.restart();
        if (present.value < 0.01)
            Qt.callLater(caretAt.snap);
    }

    Timer {
        id: blinker

        interval: 530
        repeat: true
        running: root.visible && !root.waiting && !Appearance.lessMotion
        onTriggered: root.lit = !root.lit
    }

    Follow {
        id: spacing

        target: root.pitch
        speed: Appearance.animation.trackSpeed
    }

    Follow {
        id: from

        target: root.start
        speed: Appearance.animation.trackSpeed
    }

    Follow {
        id: caretAt

        target: root.shown > 0 ? root.start + root.shown * root.pitch : (root.width - root.caretWidth) / 2
        speed: Appearance.animation.trackSpeed
    }

    Follow {
        id: present

        target: root.shown > 0 ? 1 : 0
        speed: Appearance.animation.revealSpeed
        epsilon: 0.01
    }

    Follow {
        id: blink

        target: root.lit ? 1 : 0
        speed: Appearance.animation.revealSpeed
        epsilon: 0.01
    }

    Follow {
        id: hint

        target: root.prompting ? 1 : 0
        speed: Appearance.animation.revealSpeed
        epsilon: 0.01
    }

    SquircleRect {
        anchors.fill: parent

        radius: Appearance.rounding.small
        color: Appearance.veil(0.07)
        stroke: Appearance.blend(Appearance.veil(0.14), Appearance.colour.alarm, root.alarm * 0.7)
        strokeWidth: 1
    }

    Item {
        anchors.fill: parent
        clip: true

        Text {
            id: prompt

            x: (root.width - prompt.implicitWidth) / 2
            anchors.verticalCenter: parent.verticalCenter

            text: root.placeholder
            color: Appearance.colour.textDim
            opacity: hint.value
            font.family: root.family
            font.pixelSize: Math.round(Appearance.font.size.small * 0.9)
            renderType: Text.NativeRendering
        }

        Repeater {
            id: sent

            model: root.capacity

            delegate: SquircleRect {
                id: held

                required property int index

                readonly property real fall: Math.max(0, Math.min(1, (root.scatter - held.index / Math.max(1, root.sentMarks) * 0.4) / 0.6))
                readonly property real home: root.centre(held.index, root.sentStart, root.sentPitch)

                function place(on: bool): void {
                    there.value = on ? 1 : 0;
                }

                x: held.home + (root.width / 2 - held.home) * root.gather - width / 2
                y: (root.height - height) / 2 + held.fall * root.dot * 1.6
                width: root.dot
                height: root.dot
                radius: root.dot / 2
                cornerPower: 2

                visible: there.value > 0.01 && held.fall < 1
                opacity: there.value * (1 - held.fall)
                scale: 1 - root.gather * 0.3
                color: Appearance.blend(Appearance.colour.text, Appearance.colour.alarm, root.alarm)

                Follow {
                    id: there

                    target: held.index < root.sentMarks ? 1 : 0
                    speed: Appearance.animation.revealSpeed
                    epsilon: 0.01
                }
            }
        }

        Repeater {
            id: live

            model: root.capacity

            delegate: SquircleRect {
                id: bead

                required property int index

                readonly property real home: root.centre(bead.index, from.value, spacing.value)

                function place(on: bool): void {
                    grow.value = on ? 1 : 0;
                }

                x: bead.home + (root.width / 2 - bead.home) * root.gather - width / 2
                y: (root.height - height) / 2 + (1 - grow.value) * root.dot * 0.6
                width: root.dot
                height: root.dot
                radius: root.dot / 2
                cornerPower: 2

                visible: grow.value > 0.01
                opacity: grow.value
                scale: (0.4 + grow.value * 0.6) * (1 - root.gather * 0.3)
                color: Appearance.colour.text

                Follow {
                    id: grow

                    target: bead.index < root.shown ? 1 : 0
                    speed: Appearance.animation.revealSpeed
                    epsilon: 0.01
                }
            }
        }

        SquircleRect {
            x: caretAt.value
            anchors.verticalCenter: parent.verticalCenter

            width: root.caretWidth
            height: Math.round(Appearance.font.size.small * 1.1)
            radius: 1

            visible: !root.waiting && present.value > 0.01
            color: Appearance.colour.accent
            opacity: blink.value * present.value * (1 - root.gather)
        }
    }

    Item {
        id: tag

        anchors.right: parent.right
        anchors.rightMargin: Appearance.padding.small
        anchors.verticalCenter: parent.verticalCenter
        width: code.implicitWidth + Appearance.padding.normal * 2
        height: Math.round(root.height * 0.6)

        visible: Keymap.several

        SquircleRect {
            anchors.fill: parent
            radius: Appearance.rounding.small
            color: flip.containsMouse ? Appearance.veil(0.14) : Appearance.veil(0.07)
        }

        Text {
            id: code

            anchors.centerIn: parent
            text: Keymap.layout
            color: flip.containsMouse ? Appearance.colour.text : Appearance.colour.textDim
            font.family: root.family
            font.pixelSize: Math.round(Appearance.font.size.small * 0.72)
            font.variableAxes: ({ "wght": 600 })
            renderType: Text.NativeRendering
        }

        MouseArea {
            id: flip

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Keymap.next()
        }
    }
}
