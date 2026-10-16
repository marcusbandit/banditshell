import QtQuick
import qs.config
import qs.modules.media
import qs.services

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
