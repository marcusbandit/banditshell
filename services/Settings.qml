pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    readonly property int homeWidth: Appearance.sizes.settingsWidth
    readonly property int homeHeight: Appearance.sizes.settingsHeight

    property bool open: false

    property string screenName: ""

    property string page: ""

    readonly property var pages: [
        {
            key: "wifi",
            title: "Wi-Fi",
            icon: "wifi",
            group: "Network",
            blurb: "networks, the adapter, sharing"
        },
        {
            key: "bluetooth",
            title: "Bluetooth",
            icon: "bluetooth",
            group: "Network",
            blurb: "paired devices and pairing"
        },
        {
            key: "sound",
            title: "Sound",
            icon: "volume_up",
            group: "Sound and display",
            blurb: "output, input, each app"
        },

        {
            key: "monitors",
            title: "Monitors",
            icon: "monitor",
            group: "Sound and display",
            blurb: "displays and their workspace bands"
        },

        {
            key: "wallpaper",
            title: "Wallpaper",
            icon: "wallpaper",
            parent: "appearance",
            blurb: "the picture behind everything"
        },
        {
            key: "appearance",
            title: "Appearance",
            icon: "palette",
            group: "Sound and display",
            blurb: "palette, font, the compositor"
        },
        {
            key: "font",
            title: "Font",
            icon: "text_fields",
            parent: "appearance",
            blurb: "the face every word is set in"
        },
        {
            key: "general",
            title: "General",
            icon: "tune",
            group: "System",
            blurb: "touch, windows, the fold, network rules"
        },
        {
            key: "battery",
            title: "Battery",
            icon: "battery_full",
            group: "System",
            blurb: "charge, health, the log"
        },
        {
            key: "device",
            title: "Device",
            icon: "computer",
            group: "System",
            blurb: "the hardware, and how it is doing"
        },
        {
            key: "keybinds",
            title: "Keybinds",
            icon: "keyboard",
            group: "System",
            blurb: "every Hyprland bind: record a chord, edit the command"
        },
        {
            key: "developer",
            title: "Developer",
            icon: "code",
            group: "System",
            blurb: "reload, files, what the shell knows"
        },

        {
            key: "cli",
            title: "Terminal",
            icon: "terminal",
            group: "System",
            blurb: "the command, its completion, the keyring"
        },
        {
            key: "about",
            title: "About",
            icon: "info",
            group: "About",
            blurb: "what it is, and why it is like this"
        }
    ].filter(p => p.key !== "battery" || Battery.available);

    readonly property var groups: root.pages.map(p => p.group).filter((g, i, all) => g && all.indexOf(g) === i)

    function entry(key: string): var {
        return root.pages.find(p => p.key === key) ?? null;
    }

    function sectionOf(key: string): string {
        const e = root.entry(key);
        return e?.parent ?? key;
    }

    function setPage(key: string): void {
        if (root.pages.some(p => p.key === key))
            root.page = key;
    }

    function back(): void {
        root.page = root.entry(root.page)?.parent ?? "";
    }

    readonly property string windowTitle: "banditshell-settings"

    function show(on: var, which: var): void {
        if (typeof which === "string")
            root.setPage(which);
        if (root.open)
            return;
        root.screenName = (typeof on === "string" && on) || Hypr.focusedScreen || Quickshell.screens[0]?.name || "";
        root.open = true;
    }

    function hide(): void {
        root.open = false;
    }

    function toggle(on: var, which: var): void {
        if (root.open)
            root.hide();
        else
            root.show(on, which);
    }

    readonly property var rules: [
        {
            lua: "float = true",
            legacy: "float on"
        },
        {
            lua: `size = { ${root.homeWidth}, ${root.homeHeight} }`,
            legacy: `size ${root.homeWidth} ${root.homeHeight}`
        },
        {
            lua: "no_anim = true",
            legacy: "no_anim on"
        }
    ]

    function installRules(): void {

        if (!Compositor.isHyprland || !Hypr.parserKnown)
            return;

        const title = `^(${root.windowTitle})$`;

        if (Hypr.lua) {

            ruler.exec(["hyprctl", "eval", `hl.window_rule({ name = "${root.windowTitle}", match = { title = "${title}" }, ${root.rules.map(r => r.lua).join(", ")} })`]);
            return;
        }

        ruler.exec(["hyprctl", "--batch", root.rules.map(r => `keyword windowrule ${r.legacy}, match:title ${title}`).join(" ; ")]);
    }

    Process {
        id: ruler

        stdout: StdioCollector {
            onStreamFinished: {
                const complaints = text.split("\n").map(l => l.trim()).filter(l => l && l !== "ok");
                if (complaints.length > 0)
                    console.warn(`Settings: the compositor refused a window rule: ${complaints.join("; ")}`);
            }
        }
    }

    Connections {
        target: Hypr

        function onConfigReloaded(): void {
            root.installRules();
        }

        function onParserKnownChanged(): void {
            root.installRules();
        }
    }

    Component.onCompleted: root.installRules()
}
