import QtQuick
import qs.config
import qs.modules.media
import qs.services

QtObject {
    id: root

    property var activity: null
    property bool lit: false

    readonly property string kind: root.activity?.kind ?? ""

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
            if (Dictation.cancelled)
                return {
                    icon: "mic_off",
                    tone: Appearance.colour.textFaint,
                    text: Dictation.outcome,
                    dim: true
                };
            return {
                icon: "mic",
                tone: Appearance.colour.accent,
                bars: true,
                trailing: root.lit && Dictation.cancellable ? "actions" : Dictation.langTag ? "text" : "",
                trailingText: Dictation.langTag,
                actions: [
                    {
                        name: "cancel",
                        label: "Discard"
                    }
                ]
            };
        case "recording":
            return {
                icon: "fiber_manual_record",
                tone: Appearance.colour.alarm,
                text: ScreenRecorder.stopping ? "Saving the recording" : `Recording ${ScreenRecorder.clock}`,
                trailing: "icon",
                trailingIcon: "stop_circle",
                trailingTone: Appearance.colour.alarm
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
        case "upgrade": {
            const state = SystemUpgrade.state;
            const failed = state === "failed";
            const asking = SystemUpgrade.running && SystemUpgrade.needsAnswer;
            return {
                glyph: SystemUpgrade.kernelTo ? "\u{f31a}" : "",
                icon: SystemUpgrade.kernelTo ? "" : "system_update_alt",
                tone: failed ? Appearance.colour.alarm : Appearance.colour.accent,
                text: SystemUpgrade.running ? (asking ? "The update has a question" : SystemUpgrade.brief) : SystemUpgrade.headline,
                trailing: SystemUpgrade.running && !asking ? "ring" : "icon",
                progress: SystemUpgrade.progress,
                trailingIcon: asking ? "help" : SystemUpgrade.good ? "check_circle" : failed ? "error" : "cancel",
                trailingTone: failed ? Appearance.colour.alarm : state === "cancelled" ? Appearance.colour.textFaint : Appearance.colour.accent
            };
        }
        case "restart":
            return {
                icon: "restart_alt",
                tone: Appearance.colour.accent,
                text: `Restart for Linux ${a.version}`,
                trailing: "icon",
                trailingIcon: "power_settings_new"
            };
        case "external": {
            const ended = a.state === "ended";
            if (a.style === "screenshot")
                return {
                    art: a.data?.picture,
                    icon: a.icon,
                    tone: Appearance.colour.accent,
                    text: ended ? "Done" : a.text,
                    detail: a.detail,
                    trailing: ended ? "icon" : "actions",
                    trailingIcon: "check_circle",
                    trailingTone: Appearance.colour.accent,
                    actions: a.actions ?? []
                };
            if (a.style === "copied")
                return {
                    icon: a.data?.secret ? "visibility_off" : a.icon,
                    tone: a.data?.secret ? Appearance.colour.textDim : Appearance.colour.accent,
                    text: a.text
                };
            if (a.style === "wifi")
                return {
                    icon: a.icon,
                    tone: Appearance.colour.alarm,
                    text: a.text,
                    trailing: ended ? "" : "actions",
                    actions: a.actions ?? []
                };
            if (a.style === "undo")
                return {
                    entry: a.data?.entry ?? null,
                    icon: a.icon,
                    tone: Appearance.colour.textDim,
                    text: a.text,
                    trailing: ended ? "" : "actions",
                    actions: a.actions ?? [],
                    actionTone: Appearance.colour.accent
                };
            if (a.style === "bluetooth") {
                const battery = a.data?.battery ?? -1;
                return {
                    icon: a.icon,
                    tone: Appearance.colour.accent,
                    text: a.text,
                    detail: a.detail,
                    trailing: battery >= 0 ? "text" : "",
                    trailingText: `${battery}%`,
                    trailingSample: "100%",
                    trailingTone: Appearance.colour.textDim
                };
            }
            const tone = !ended ? Appearance.colour.accent : a.outcome === "failed" ? Appearance.colour.alarm : a.outcome === "cancelled" ? Appearance.colour.textFaint : Appearance.colour.accent;
            return {
                app: a.mark,
                icon: a.icon || "bolt",
                tone: tone,
                text: a.text,
                detail: a.detail,
                dim: ended && a.outcome === "cancelled",
                trailing: ended ? "icon" : a.progress < 0 ? "spin" : "ring",
                trailingIcon: a.outcome === "failed" ? "error" : a.outcome === "cancelled" ? "cancel" : "check_circle",
                trailingTone: tone,
                ringValue: Math.max(0, a.progress)
            };
        }
        case "privacy":
            return {
                icon: a.icon,
                tone: Appearance.colour.alarm,
                text: a.text,
                detail: a.detail,
                trailing: "icon",
                trailingIcon: "fiber_manual_record",
                trailingTone: Appearance.colour.alarm
            };
        case "timer":
            return {
                icon: a.paused ? "pause" : "timer",
                tone: a.ending ? Appearance.colour.alarm : Appearance.colour.accent,
                text: a.text,
                markRing: a.progress,
                trailing: "text",
                trailingText: a.clock,
                trailingSample: a.sample,
                trailingTone: a.ending ? Appearance.colour.alarm : a.paused ? Appearance.colour.textFaint : Appearance.colour.textDim
            };
        case "alarm":
            return {
                icon: "alarm",
                tone: Appearance.colour.alarm,
                text: a.text,
                trailing: "actions",
                actions: a.actions ?? []
            };
        case "level":
            return {
                icon: a.icon,
                tone: a.muted ? Appearance.colour.textFaint : Appearance.colour.accent,
                text: a.text,
                meter: a.meter,
                trailing: a.readout ? "text" : "",
                trailingText: a.readout,
                trailingSample: "100%",
                trailingTone: Appearance.colour.textDim
            };
        case "notifications":
            return {
                icon: "notifications",
                text: `${a.count}${a.more ? " more" : ""} notification${a.count === 1 ? "" : "s"}`,
                trailing: "icon",
                trailingIcon: "chevron_right"
            };
        case "held":
            return {
                icon: "notifications_paused",
                text: `${a.count} held while quiet`,
                trailing: "icon",
                trailingIcon: "chevron_right"
            };
        case "quiet":
            return {
                icon: "do_not_disturb_on",
                text: a.text
            };
        case "notification":
            return {
                entry: a.entry,
                text: a.entry?.summary || a.entry?.appName || "",
                trailing: a.count > 1 ? "text" : "",
                trailingText: `${a.count}`
            };
        }
        return {
            text: ""
        };
    }
}
