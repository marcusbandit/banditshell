import QtQuick
import qs.config
import qs.components
import qs.modules.media
import qs.services

Item {
    id: root

    required property var activity

    property bool lights: false
    property bool live: true

    signal chosen
    signal acted(string name)

    readonly property string kind: root.activity?.kind ?? ""

    readonly property real slot: Appearance.font.line.small
    readonly property real inset: Appearance.padding.small
    readonly property real gap: Appearance.padding.normal

    readonly property bool pressable: ["music", "download", "update", "kernel", "restart", "upgrade", "notifications", "held", "notification", "recording", "timer"].includes(root.kind) || ((root.kind === "external" || root.kind === "privacy") && !!root.activity?.pressable && root.activity?.state !== "ended") || (root.lights && (root.kind === "dictation" || (root.kind === "launch" && root.activity?.state === "here")))

    readonly property bool hovered: press.containsMouse

    function parts(into: Item): var {
        const box = item => item.visible ? item.mapToItem(into, 0, 0, item.width, item.height) : null;
        return {
            cover: box(mark),
            title: box(words),
            titleSize: Appearance.font.size.small,
            beat: box(beat)
        };
    }

    readonly property var look: shape.look

    property real markOpacity: 1

    ActivityLook {
        id: shape

        activity: root.activity
        lit: root.lights
    }

    readonly property int maxChars: 30
    readonly property string spoken: root.lights && root.look.detail ? `${root.look.text}  ${root.look.detail}` : (root.look.text ?? "")
    readonly property bool metered: (root.look.meter ?? -1) >= 0
    readonly property real textWidth: em.advanceWidth * Math.min(root.maxChars, (root.look.text ?? "").length)
    readonly property real meterWidth: root.slot * 5
    readonly property real centreWidth: root.look.bars ? bars.implicitWidth : root.metered ? root.meterWidth : root.textWidth
    readonly property var actions: root.look.trailing === "actions" ? (root.look.actions ?? []) : []
    readonly property real pillGap: Appearance.padding.small
    readonly property string actionsTag: root.actions.length > 0 ? (root.look.trailingText ?? "") : ""
    readonly property real actionsWidth: {
        let total = root.actionsTag ? em.advanceWidth * root.actionsTag.length + root.pillGap : 0;
        for (const a of root.actions)
            total += em.advanceWidth * a.label.length + root.gap * 2 + root.pillGap;
        return Math.max(0, total - root.pillGap);
    }
    readonly property real tailWidth: root.look.trailingSample ? Math.max(root.slot, sample.advanceWidth) : Math.max(root.slot, tail.implicitWidth)
    readonly property real trailingWidth: root.look.trailing === "text" ? root.tailWidth : root.look.trailing === "actions" ? root.actionsWidth : root.look.trailing ? root.slot : 0
    readonly property real ends: root.inset * 2 + root.slot + root.gap + (root.trailingWidth > 0 ? root.gap + root.trailingWidth : 0)
    readonly property real middle: Math.max(0, root.width - root.ends)

    implicitHeight: root.slot + root.inset * 2
    implicitWidth: root.ends + root.centreWidth

    TextMetrics {
        id: em

        font.family: Appearance.font.family
        font.pixelSize: Appearance.font.size.small
        text: "0"
    }

    TextMetrics {
        id: sample

        font.family: Appearance.font.family
        font.pixelSize: Appearance.font.size.small
        text: root.look.trailingSample ?? ""
    }

    Follow {
        id: ringShown

        speed: Appearance.animation.revealSpeed
        epsilon: 0.002
        target: root.look.ringValue ?? 0
    }

    Follow {
        id: meterShown

        speed: Appearance.animation.revealSpeed * 2
        epsilon: 0.002
        target: Math.max(0, root.look.meter ?? 0)
    }

    Follow {
        id: glow

        speed: Appearance.animation.snapSpeed
        epsilon: 0.005
        target: root.lights && root.hovered ? 1 : 0
    }

    SquircleRect {
        anchors.fill: parent
        pill: "place"
        color: press.pressed ? Appearance.colour.fillStrong : Appearance.colour.fill
        opacity: glow.value
        visible: glow.value > 0.01
    }

    ActivityMark {
        id: mark

        x: root.inset
        anchors.verticalCenter: parent.verticalCenter
        size: root.slot
        look: root.look
        scale: 1 + 0.1 * glow.value
        opacity: root.markOpacity
    }

    StyledText {
        id: words

        x: mark.x + mark.width + root.gap
        anchors.verticalCenter: parent.verticalCenter
        width: root.middle
        visible: !root.look.bars && !root.metered
        text: root.spoken
        color: root.look.dim ? Appearance.colour.textDim : Appearance.colour.text
        elide: root.kind === "download" ? Text.ElideMiddle : Text.ElideRight
    }

    Item {
        id: meter

        x: mark.x + mark.width + root.gap
        anchors.verticalCenter: parent.verticalCenter
        width: root.middle
        height: Math.max(2, Math.round(root.slot / 4))
        visible: root.metered

        SquircleRect {
            anchors.fill: parent
            pill: "place"
            color: Appearance.colour.fillStrong
        }

        SquircleRect {
            width: Math.max(parent.height, parent.width * meterShown.value)
            height: parent.height
            pill: "place"
            color: root.look.tone ?? Appearance.colour.accent
        }
    }

    DictationWave {
        id: bars

        x: mark.x + mark.width + root.gap
        anchors.verticalCenter: parent.verticalCenter
        width: root.middle
        height: root.slot
        visible: !!root.look.bars
        live: root.live && !!root.look.bars
    }

    Item {
        x: root.width - root.inset - width + (root.look.trailing === "icon" ? Appearance.padding.hair * glow.value : 0)
        anchors.verticalCenter: parent.verticalCenter
        width: root.trailingWidth
        height: root.slot
        visible: root.trailingWidth > 0

        ProgressRing {
            anchors.centerIn: parent
            visible: root.look.trailing === "ring"
            size: Math.round(root.slot * 0.75)
            value: root.look.progress !== undefined ? root.look.progress : root.kind === "launch" ? (root.activity?.rec ? Launching.progress(root.activity.rec) : 0) : ringShown.value
        }

        ProgressRing {
            anchors.centerIn: parent
            visible: root.look.trailing === "spin"
            size: Math.round(root.slot * 0.75)
            value: 0.3

            RotationAnimation on rotation {
                running: root.live && root.look.trailing === "spin" && !Appearance.lessMotion
                from: 0
                to: 360
                duration: 1100
                loops: Animation.Infinite
            }
        }

        Icon {
            anchors.centerIn: parent
            visible: root.look.trailing === "icon"
            name: root.look.trailingIcon ?? ""
            size: Math.round(root.slot * 0.85)
            fill: 1
            color: root.look.trailingTone ?? Appearance.colour.textFaint
        }

        Equalizer {
            id: beat

            anchors.centerIn: parent
            visible: root.look.trailing === "beat"
            playing: Media.playing
            color: Appearance.colour.accent
        }

        StyledText {
            id: tail

            anchors.centerIn: parent
            visible: root.look.trailing === "text"
            text: root.look.trailingText ?? ""
            color: root.look.trailingTone ?? Appearance.colour.textFaint
        }

        Row {
            spacing: root.pillGap
            visible: root.actions.length > 0

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                visible: !!root.actionsTag
                text: root.actionsTag
                color: root.look.trailingTone ?? Appearance.colour.textFaint
            }

            Repeater {
                model: root.actions

                Item {
                    id: pill

                    required property var modelData
                    required property int index

                    readonly property bool primary: pill.index === root.actions.length - 1

                    width: em.advanceWidth * pill.modelData.label.length + root.gap * 2
                    height: root.slot

                    Follow {
                        id: lift

                        speed: Appearance.animation.snapSpeed
                        epsilon: 0.004
                        target: pillPress.containsMouse ? 1 : 0
                    }

                    SquircleRect {
                        anchors.fill: parent
                        pill: "object"
                        color: pill.primary ? Appearance.colour.alarm : (pillPress.pressed ? Appearance.colour.fillStrong : Appearance.colour.fill)
                        scale: 1 + 0.06 * lift.value
                    }

                    StyledText {
                        anchors.centerIn: parent
                        text: pill.modelData.label
                        color: pill.primary ? Appearance.colour.ink : Appearance.colour.text
                    }

                    MouseArea {
                        id: pillPress

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: root.acted(pill.modelData.name)
                    }
                }
            }
        }
    }

    MouseArea {
        id: press

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.width - (root.actions.length > 0 ? root.actionsWidth + root.inset + root.gap : 0)
        enabled: root.pressable
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: root.chosen()
    }
}
