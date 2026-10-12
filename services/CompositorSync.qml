pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

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

        command: ["hyprctl", "-j", "--batch", "getoption decoration:rounding ; getoption decoration:rounding_power ; getoption general:gaps_out ; getoption general:gaps_in ; getoption general:border_size ; getoption input:natural_scroll ; getoption input:touchpad:natural_scroll"]

        stdout: StdioCollector {
            onStreamFinished: {
                const nums = text.split("\n").filter(l => l.trim().startsWith("{")).map(line => {
                    try {
                        const o = JSON.parse(line);
                        const many = o.custom ?? o.css;
                        if (many !== undefined)
                            return parseFloat(String(many).trim().split(/\s+/)[0]);

                        if (o.bool !== undefined)
                            return o.bool ? 1 : 0;
                        return o.float ?? o.int ?? null;
                    } catch (e) {
                        return null;
                    }
                }).filter(v => v !== null);

                if (nums.length < 5)
                    return console.warn("CompositorSync: could not read Hyprland options, keeping config.json values.");

                Compositor.rounding = nums[0];
                Compositor.roundingPower = nums[1];
                Compositor.gapsOut = nums[2];
                Compositor.gapsIn = nums[3];
                Compositor.borderSize = nums[4];
                Compositor.available = true;

                if (nums.length > 5)
                    Compositor.naturalScrollMouse = nums[5] !== 0;
                if (nums.length > 6)
                    Compositor.naturalScrollTouchpad = nums[6] !== 0;
            }
        }
    }

    FileView {
        id: niriConfig

        path: `${Quickshell.env("HOME")}/.config/niri/config.kdl`
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

    readonly property bool pushBorders: Config.values.compositor.pushBorders ?? true

    readonly property color activeBorder: Appearance.colour.accent

    readonly property color inactiveBorder: {
        const line = Appearance.colour.separator;
        const ground = Appearance.colour.surfaceSolid;
        const over = (a, b, t) => a + (b - a) * t;
        return Qt.rgba(over(ground.r, line.r, line.a), over(ground.g, line.g, line.a), over(ground.b, line.b, line.a), 1);
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
