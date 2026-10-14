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

    readonly property bool pressable: ["music", "download", "update", "kernel", "restart", "notifications"].includes(root.kind)

    readonly property var look: {
        const a = root.activity ?? {};
        switch (root.kind) {
        case "launch":
            return {
                app: a.mark,
                text: a.name,
                dim: a.state === "lost",
                trailing: a.state === "waiting" ? "ring" : "icon",
                trailingIcon: a.state === "lost" ? "error" : "check_circle",
                trailingTone: a.state === "lost" ? Appearance.colour.alarm : Appearance.colour.accent
            };
        case "music":
            return {
                art: Media.artUrl,
                icon: "music_note",
                tone: Appearance.colour.accent,
                text: Media.title,
                trailing: "beat"
            };
        case "dictation":
            return {
                icon: "mic",
                tone: Appearance.colour.accent,
                bars: true,
                trailing: Dictation.langTag ? "text" : "",
                trailingText: Dictation.langTag
            };
        case "download":
            return {
                icon: "download_done",
                tone: Appearance.colour.accent,
                text: a.more > 0 ? `${a.name} +${a.more}` : a.name,
                trailing: "icon",
                trailingIcon: "arrow_outward"
            };
        case "update":
            return {
                icon: "system_update_alt",
                tone: Appearance.colour.updateAvailable,
                text: "BanditShell update",
                trailing: a.count > 0 ? "text" : "",
                trailingText: `${a.count}`,
                trailingTone: Appearance.colour.updateAvailable
            };
        case "kernel":
            return {
                glyph: "",
                tone: Appearance.colour.accent,
                text: `Linux ${a.version}`,
                trailing: "icon",
                trailingIcon: a.upgrading ? "hourglass_top" : "download",
                trailingTone: Appearance.colour.accent
            };
        case "restart":
            return {
                icon: "restart_alt",
                tone: Appearance.colour.accent,
                text: `Restart for Linux ${a.version}`,
                trailing: "icon",
                trailingIcon: "power_settings_new"
            };
        case "notifications":
            return {
                icon: "notifications",
                text: `${a.count} notification${a.count === 1 ? "" : "s"}`,
                trailing: "icon",
                trailingIcon: "chevron_right"
            };
        }
        return {
            text: ""
        };
    }

    readonly property int maxChars: 30
    readonly property real textWidth: em.advanceWidth * Math.min(root.maxChars, (root.look.text ?? "").length)
    readonly property real centreWidth: root.look.bars ? bars.implicitWidth : root.textWidth
    readonly property real trailingWidth: root.look.trailing === "text" ? Math.max(root.slot, tail.implicitWidth) : root.look.trailing ? root.slot : 0

    implicitHeight: root.slot + root.inset * 2
    implicitWidth: root.inset * 2 + root.slot + root.gap + root.centreWidth + (root.trailingWidth > 0 ? root.gap + root.trailingWidth : 0)

    TextMetrics {
        id: em

        font.family: Appearance.font.family
        font.pixelSize: Appearance.font.size.small
        text: "0"
    }

    SquircleRect {
        anchors.fill: parent
        radius: height / 2
        color: Appearance.colour.fill
        opacity: root.lights && press.containsMouse ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.animation.fast
            }
        }
    }

    Item {
        id: mark

        x: root.inset
        anchors.verticalCenter: parent.verticalCenter
        width: root.slot
        height: root.slot

        AppMark {
            anchors.centerIn: parent
            visible: !!root.look.app
            spec: root.look.app ?? ""
            fits: AppIcons.fits
            onMeasured: (path, box) => AppIcons.recordFit(path, box)
            size: root.slot
            fallback: Apps.genericIcon
            opacity: root.look.dim ? 0.5 : 1
        }

        Icon {
            anchors.centerIn: parent
            visible: !root.look.app && !cover.ready
            name: root.look.icon ?? ""
            glyph: root.look.glyph ?? ""
            size: root.slot
            fill: 1
            color: root.look.tone ?? Appearance.colour.textDim
        }

        ArtCrossfade {
            id: cover

            anchors.fill: parent
            visible: !!root.look.art
            radius: Appearance.rounding.small
            source: root.look.art ?? ""
        }
    }

    StyledText {
        x: mark.x + mark.width + root.gap
        anchors.verticalCenter: parent.verticalCenter
        width: root.centreWidth
        visible: !root.look.bars
        text: root.look.text ?? ""
        color: root.look.dim ? Appearance.colour.textDim : Appearance.colour.text
        elide: root.kind === "download" ? Text.ElideMiddle : Text.ElideRight
    }

    DictationBars {
        id: bars

        x: mark.x + mark.width + root.gap
        anchors.verticalCenter: parent.verticalCenter
        width: implicitWidth
        height: root.slot
        visible: !!root.look.bars
        live: root.live && !!root.look.bars
    }

    Item {
        x: root.width - root.inset - width
        anchors.verticalCenter: parent.verticalCenter
        width: root.trailingWidth
        height: root.slot
        visible: root.trailingWidth > 0

        ProgressRing {
            anchors.centerIn: parent
            visible: root.look.trailing === "ring"
            size: Math.round(root.slot * 0.75)
            value: root.kind === "launch" && root.activity?.rec ? Launching.progress(root.activity.rec) : 0
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
