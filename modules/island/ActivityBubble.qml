import QtQuick
import Quickshell.Services.Notifications
import qs.config
import qs.components
import qs.services

Item {
    id: root

    property var group: null
    property real size: Appearance.font.line.small + Appearance.padding.small * 2
    property bool live: true
    property real markOpacity: 1
    property real stateShown: 1

    readonly property var items: root.group?.items ?? []
    readonly property var front: root.items[0] ?? null
    readonly property string kind: root.group?.kind ?? ""
    readonly property int count: root.kind === "notification" ? (root.front?.count ?? root.items.length) : root.items.length
    readonly property real full: Appearance.font.line.small + Appearance.padding.small * 2
    readonly property real thickness: Math.max(2, Math.round(root.size / 14))

    readonly property string ring: {
        const a = root.front ?? {};
        switch (root.kind) {
        case "launch":
            return a.state === "waiting" ? "progress" : "";
        case "dictation":
            return Dictation.cancelled ? "" : Dictation.phase === "listening" ? "voice" : "spin";
        case "music":
            return "track";
        case "kernel":
            return a.upgrading ? "spin" : "";
        case "notification":
            return a.entry?.urgency === NotificationUrgency.Critical ? "alarm" : "";
        case "external":
            return a.state === "ended" || a.style ? "" : a.progress < 0 ? "spin" : "measure";
        case "timer":
            return "measure";
        case "alarm":
            return "alarm";
        }
        return "";
    }

    readonly property real measured: {
        const a = root.front ?? {};
        return Math.max(0, Math.min(1, a.progress ?? 0));
    }

    readonly property var badge: {
        const a = root.front ?? {};
        if (root.kind === "launch" && a.state === "here")
            return {
                icon: "check",
                tone: Appearance.colour.accent
            };
        if (root.kind === "launch" && a.state === "lost")
            return {
                icon: "priority_high",
                tone: Appearance.colour.alarm
            };
        if (root.kind === "notification" && root.count > 1)
            return {
                text: `${root.count}`
            };
        if (root.kind === "dictation" && Dictation.cancelled)
            return {
                icon: "close",
                tone: Appearance.colour.textFaint
            };
        if (root.kind === "external" && a.state === "ended")
            return {
                icon: a.outcome === "failed" ? "priority_high" : a.outcome === "cancelled" ? "close" : "check",
                tone: a.outcome === "failed" ? Appearance.colour.alarm : a.outcome === "cancelled" ? Appearance.colour.textFaint : Appearance.colour.accent
            };
        if (root.kind === "timer")
            return {
                text: a.clock,
                tone: a.ending ? Appearance.colour.alarm : Appearance.colour.text
            };
        if ((root.kind === "external" || root.kind === "timer" || root.kind === "alarm" || root.kind === "privacy") && root.items.length > 1)
            return {
                text: `${root.items.length}`
            };
        if (root.kind === "download" && a.more > 0)
            return {
                text: `+${a.more}`
            };
        if (root.kind === "update" && a.count > 0)
            return {
                text: `${a.count}`,
                tone: Appearance.colour.updateAvailable
            };
        return null;
    }

    readonly property string label: {
        const a = root.front ?? {};
        switch (root.kind) {
        case "dictation":
            return Dictation.cancelled ? "Dictation cancelled" : Dictation.phase === "listening" ? "Dictating" : "Turning speech into text";
        case "launch":
            if (root.items.length > 1)
                return `${root.items.map(i => i.name).join(", ")} opening`;
            return a.state === "waiting" ? `Opening ${a.name}` : a.state === "here" ? `${a.name} opened` : `${a.name} did not open`;
        case "notification":
            if (root.count > 1)
                return `${root.count} notifications`;
            return [a.entry?.appName, a.entry?.summary].filter(t => t).join(": ") || "A notification";
        case "external":
            return root.items.length > 1 ? `${root.items.length} activities` : [a.text, a.detail].filter(t => t).join(": ");
        case "timer":
            return root.items.length > 1 ? `${root.items.length} timers` : `${a.text}, ${a.clock} left`;
        case "alarm":
            return a.text;
        case "privacy":
            return root.items.map(i => i.text).join(", ");
        }
        return "";
    }

    property var shownBadge: null
    property string shownRing: ""

    onBadgeChanged: if (root.badge)
        root.shownBadge = root.badge
    onRingChanged: if (root.ring)
        root.shownRing = root.ring

    property real trackProgress: 0

    Follow {
        id: measure

        speed: Appearance.animation.revealSpeed
        epsilon: 0.002
        target: root.measured
    }

    Follow {
        id: badgeIn

        speed: Appearance.animation.revealSpeed
        epsilon: 0.004
        target: root.badge ? 1 : 0
    }

    Follow {
        id: ringIn

        speed: Appearance.animation.revealSpeed
        epsilon: 0.004
        target: root.ring ? 1 : 0
    }

    Component.onCompleted: {
        root.shownBadge = root.badge;
        root.shownRing = root.ring;
        badgeIn.snap();
        ringIn.snap();
    }

    width: root.size
    height: root.size

    ActivityLook {
        id: shape

        activity: root.front
    }

    Follow {
        id: voice

        speed: Appearance.animation.revealSpeed * 2
        epsilon: 0.01
        target: root.ring === "voice" ? (Dictation.levels[Dictation.levels.length - 1] ?? 0) : 0
    }

    Timer {
        interval: 500
        repeat: true
        triggeredOnStart: true
        running: root.live && root.ring === "track"
        onTriggered: root.trackProgress = Media.length > 0 ? Media.now() / Media.length : 0
    }

    ActivityMark {
        anchors.centerIn: parent
        size: Math.round(Appearance.font.line.small * Math.min(1, root.size / root.full))
        look: shape.look
        round: true
        opacity: root.markOpacity
    }

    Item {
        anchors.fill: parent
        opacity: root.stateShown * root.markOpacity * ringIn.value
        visible: opacity > 0.01 && root.shownRing !== ""

        ProgressRing {
            anchors.centerIn: parent
            visible: root.shownRing === "progress" || root.shownRing === "track"
            size: root.size - root.thickness
            thickness: root.thickness
            track: "transparent"
            colour: root.shownRing === "track" && !Media.playing ? Appearance.colour.textFaint : Appearance.colour.accent
            value: root.shownRing === "progress" && root.front?.rec ? Launching.progress(root.front.rec) : root.trackProgress
        }

        ProgressRing {
            anchors.centerIn: parent
            visible: root.shownRing === "measure"
            size: root.size - root.thickness
            thickness: root.thickness
            track: Appearance.colour.fillStrong
            colour: root.front?.ending ? Appearance.colour.alarm : Appearance.colour.accent
            value: measure.value
        }

        ProgressRing {
            anchors.centerIn: parent
            visible: root.shownRing === "voice" || root.shownRing === "alarm"
            size: root.size - root.thickness
            thickness: root.thickness
            track: "transparent"
            colour: root.shownRing === "alarm" ? Appearance.colour.alarm : Appearance.colour.accent
            opacity: root.shownRing === "voice" ? 0.3 + 0.7 * Math.min(1, voice.value * 1.6) : 1
            value: 1
        }

        ProgressRing {
            anchors.centerIn: parent
            visible: root.shownRing === "spin"
            size: root.size - root.thickness
            thickness: root.thickness
            track: "transparent"
            value: 0.3

            RotationAnimation on rotation {
                running: root.live && root.shownRing === "spin" && !Appearance.lessMotion
                from: 0
                to: 360
                duration: 1100
                loops: Animation.Infinite
            }
        }
    }

    Item {
        readonly property real across: Math.round(Appearance.font.line.small * 0.85)

        x: root.width - width * 0.7
        y: -height * 0.3
        width: Math.max(across, label.implicitWidth + Appearance.padding.small)
        height: across
        opacity: root.stateShown * root.markOpacity * badgeIn.value
        visible: !!root.shownBadge && opacity > 0.01

        SquircleRect {
            anchors.fill: parent
            anchors.margins: -Math.max(1, Math.round(root.thickness / 2))
            pill: "object"
            color: Appearance.colour.island
        }

        SquircleRect {
            anchors.fill: parent
            pill: "object"
            color: root.shownBadge?.icon ? (root.shownBadge.tone ?? Appearance.colour.accent) : Appearance.colour.fillStrong
        }

        Icon {
            anchors.centerIn: parent
            visible: !!root.shownBadge?.icon
            name: root.shownBadge?.icon ?? ""
            size: Math.round(parent.height * 0.75)
            fill: 1
            color: Appearance.colour.ink
        }

        StyledText {
            id: label

            anchors.centerIn: parent
            visible: !!root.shownBadge?.text
            text: root.shownBadge?.text ?? ""
            color: root.shownBadge?.tone ?? Appearance.colour.text
        }
    }
}
