pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "compositor-options.js" as Options

Singleton {
    id: root

    property string unanswered: ""

    function refresh(): void {
        if (Compositor.isHyprland)
            hyprctl.running = true;
        else if (Compositor.isNiri)
            niriConfig.reload();
    }

    Component.onCompleted: {
        root.refresh();
        root.pushBorderColours();
    }

    Process {
        id: hyprctl

        command: ["hyprctl", "-j", "--batch", Options.batch()]

        stdout: StdioCollector {
            onStreamFinished: {
                const got = Options.readOptions(text);
                const next = Options.settle(got, {
                    rounding: Config.values.rounding.base,
                    roundingPower: 2,
                    gapsOut: Config.values.edge.border,
                    gapsIn: Compositor.gapsIn,
                    borderSize: Compositor.borderSize,
                    naturalScrollMouse: Compositor.naturalScrollMouse,
                    naturalScrollTouchpad: Compositor.naturalScrollTouchpad
                });
                if (!next)
                    return console.warn("CompositorSync: could not read Hyprland options, keeping config.json values.");

                const missing = Options.missing(got).join(", ");
                if (missing && missing !== root.unanswered)
                    console.warn(`CompositorSync: Hyprland has no ${missing}, so the shell uses its own value for each.`);
                root.unanswered = missing;

                for (const key of Object.keys(next))
                    Compositor[key] = next[key];
                Compositor.available = true;
            }
        }
    }

    FileView {
        id: niriConfig

        path: Quickshell.env("NIRI_CONFIG") || `${Quickshell.env("XDG_CONFIG_HOME") || `${Quickshell.env("HOME")}/.config`}/niri/config.kdl`
        printErrors: false

        onLoaded: {
            const src = text();
            const gaps = src.match(/^\s*gaps\s+(\d+(?:\.\d+)?)/m);
            const radius = src.match(/geometry-corner-radius\s+(\d+(?:\.\d+)?)/);

            if (!gaps && !radius)
                return;

            Compositor.gapsOut = gaps ? parseFloat(gaps[1]) : Compositor.gapsOut;
            Compositor.gapsIn = Compositor.gapsOut;
            Compositor.rounding = radius ? parseFloat(radius[1]) : Compositor.rounding;

            Compositor.roundingPower = 2;
            Compositor.available = true;
        }
    }

    readonly property bool pushBorders: Config.ready && (Config.values.compositor.pushBorders ?? true)

    readonly property color activeBorder: Appearance.colour.accent

    readonly property color inactiveBorder: {
        const line = Appearance.colour.separator;
        const ground = Appearance.colour.surfaceSolid;
        return Appearance.blend(ground, Appearance.withAlpha(line, 1), line.a);
    }

    onActiveBorderChanged: Qt.callLater(root.pushBorderColours)
    onInactiveBorderChanged: Qt.callLater(root.pushBorderColours)

    onPushBordersChanged: Qt.callLater(root.pushBorderColours)

    function channelHex(v: real): string {
        const n = Math.round(v * 255);
        return (n < 16 ? "0" : "") + n.toString(16);
    }

    function pushBorderColours(): void {

        if (!Compositor.isHyprland || !root.pushBorders || !Hypr.parserKnown)
            return;

        const active = root.activeBorder;
        const inactive = root.inactiveBorder;

        if (Hypr.lua) {
            const stop = c => `"0x${root.channelHex(c.a)}${root.channelHex(c.r)}${root.channelHex(c.g)}${root.channelHex(c.b)}"`;
            pusher.exec(["hyprctl", "eval", `hl.config({ general = { col = { active_border = { colors = { ${stop(active)} } }, inactive_border = { colors = { ${stop(inactive)} } } } } })`]);
            return;
        }

        const stop = c => `rgba(${root.channelHex(c.r)}${root.channelHex(c.g)}${root.channelHex(c.b)}${root.channelHex(c.a)})`;
        pusher.exec(["hyprctl", "--batch", `keyword general:col.active_border ${stop(active)} ; keyword general:col.inactive_border ${stop(inactive)}`]);
    }

    function lockXrayCommand(on: bool): var {
        if (!Compositor.isHyprland || !Hypr.parserKnown)
            return [];
        if (Hypr.lua)
            return ["hyprctl", "eval", `hl.config({ misc = { session_lock_xray = ${on} } })`];
        return ["hyprctl", "keyword", "misc:session_lock_xray", on ? "true" : "false"];
    }

    Connections {
        target: Hypr

        function onConfigReloaded(): void {
            root.refresh();
            root.pushBorderColours();
        }

        function onParserKnownChanged(): void {
            root.pushBorderColours();
        }
    }

    Process {
        id: pusher

        stdout: StdioCollector {
            onStreamFinished: {
                const complaints = text.split("\n").map(l => l.trim()).filter(l => l && l !== "ok");
                if (complaints.length > 0)
                    console.warn(`CompositorSync: the compositor refused a border colour: ${complaints.join("; ")}`);
            }
        }
    }
}
