import QtQuick
import qs.config
import qs.modules.media
import qs.services
import "../../services/obs.js" as Durations

QtObject {
    id: root

    property var activity: null

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
            return {
                icon: "mic",
                tone: Appearance.colour.accent,
                bars: true,
                trailing: Dictation.langTag ? "text" : "",
                trailingText: Dictation.langTag
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
        case "timer":
            return {
                icon: a.timer?.paused ? "timer_pause" : "timer",
                tone: Appearance.colour.accent,
                text: `${a.timer?.label || "Timer"} ${Durations.duration(Clock.remainingOf(a.timer, Math.max(Clock.tick, Date.now() - Clock.tickMs)))}`,
                dim: !!a.timer?.paused,
                trailing: "icon",
                trailingIcon: a.timer?.paused ? "play_circle" : "pause_circle",
                trailingTone: Appearance.colour.accent
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
            const asking = SystemUpgrade.running && SystemUpgrade.asking && SystemUpgrade.question?.text !== "Proceed with installation?";
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
        case "notifications":
            return {
                icon: "notifications",
                text: `${a.count} notification${a.count === 1 ? "" : "s"}`,
                trailing: "icon",
                trailingIcon: "chevron_right"
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
