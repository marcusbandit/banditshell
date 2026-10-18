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

    readonly property string kind: root.activity?.kind ?? ""

    readonly property real slot: Appearance.font.line.small
    readonly property real inset: Appearance.padding.small
    readonly property real gap: Appearance.padding.normal

    readonly property bool pressable: ["music", "download", "update", "kernel", "restart", "upgrade", "notifications", "notification", "recording", "timer"].includes(root.kind) || (root.lights && (root.kind === "dictation" || (root.kind === "launch" && root.activity?.state === "here")))

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
    }

    readonly property int maxChars: 30
    readonly property real textWidth: em.advanceWidth * Math.min(root.maxChars, (root.look.text ?? "").length)
    readonly property real centreWidth: root.look.bars ? bars.implicitWidth : root.textWidth
    readonly property real trailingWidth: root.look.trailing === "text" ? Math.max(root.slot, tail.implicitWidth) : root.look.trailing ? root.slot : 0
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

    Follow {
        id: glow

        speed: Appearance.animation.revealSpeed * 1.5
        epsilon: 0.005
        target: root.lights && root.hovered ? 1 : 0
    }

    SquircleRect {
        anchors.fill: parent
        radius: height / 2
        cornerPower: 2
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
        visible: !root.look.bars
        text: root.look.text ?? ""
        color: root.look.dim ? Appearance.colour.textDim : Appearance.colour.text
        elide: root.kind === "download" ? Text.ElideMiddle : Text.ElideRight
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
        x: root.width - root.inset - width + (root.look.trailing === "icon" ? Appearance.padding.small / 2 * glow.value : 0)
        anchors.verticalCenter: parent.verticalCenter
        width: root.trailingWidth
        height: root.slot
        visible: root.trailingWidth > 0

        ProgressRing {
            anchors.centerIn: parent
            visible: root.look.trailing === "ring"
            size: Math.round(root.slot * 0.75)
            value: root.look.progress !== undefined ? root.look.progress : root.kind === "launch" && root.activity?.rec ? Launching.progress(root.activity.rec) : 0
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
    }

    MouseArea {
        id: press

        anchors.fill: parent
        enabled: root.pressable
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: root.chosen()
    }
}
