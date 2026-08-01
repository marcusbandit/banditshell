pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// What the compositor says about itself.
//
// This lives in config/ rather than services/ because it is a SOURCE OF
// SETTINGS, exactly like config.json: Appearance reads it to answer "how round
// is a corner here". Services are for live state that widgets react to; this is
// read once at startup and on demand.
//
// The point: the shell should not need to be told the rounding twice. If
// Hyprland says `rounding = 15, rounding_power = 4.0, gaps_out = 10`, the shell
// should already agree, and should keep agreeing when those change.
Singleton {
    id: root

    readonly property bool isHyprland: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") !== ""
    readonly property bool isNiri: Quickshell.env("NIRI_SOCKET") !== ""

    readonly property string name: isHyprland ? "hyprland" : isNiri ? "niri" : "unknown"

    // False until we have actually read something, so Appearance can fall back
    // to config.json instead of rendering with zeros for a frame.
    property bool available: false

    property real rounding: 0
    // The superellipse exponent: |x|^p + |y|^p = r^p. p = 2 is a plain circular
    // arc; higher is squarer and smoother.
    property real roundingPower: 2
    property real gapsOut: 0
    property real gapsIn: 0
    property real borderSize: 0

    // Superellipse exponent -> our G2 smoothing factor.
    //
    // They describe the same idea in different parameters: p = 2 is a circular
    // corner (no smoothing), and an iOS-style squircle sits near p = 5, which is
    // also where our 0.6 smoothing sits. So the map is linear through those two.
    readonly property real smoothing: Math.max(0, Math.min(1, (roundingPower - 2) / 5))

    function refresh(): void {
        if (isHyprland)
            hyprctl.running = true;
        else if (isNiri)
            niriConfig.reload();
    }

    Component.onCompleted: refresh()

    // Hyprland ------------------------------------------------------------
    //
    // One call for all five options: spawning five processes to read five
    // integers would be silly, and `getoption` only takes one option at a time,
    // so this is `--batch`. Each answer puts its value under a key named after
    // its type, and gaps are a "custom" string of up to four numbers, so take
    // the first.
    Process {
        id: hyprctl

        command: ["hyprctl", "-j", "--batch", "getoption decoration:rounding ; getoption decoration:rounding_power ; getoption general:gaps_out ; getoption general:gaps_in ; getoption general:border_size"]

        stdout: StdioCollector {
            onStreamFinished: {
                const nums = text.split("\n").filter(l => l.trim().startsWith("{")).map(line => {
                    try {
                        const o = JSON.parse(line);
                        if (o.custom !== undefined)
                            return parseFloat(o.custom.trim().split(/\s+/)[0]);
                        return o.float ?? o.int ?? 0;
                    } catch (e) {
                        return null;
                    }
                }).filter(v => v !== null);

                if (nums.length < 5)
                    return console.warn("Compositor: could not read Hyprland options, keeping config.json values.");

                root.rounding = nums[0];
                root.roundingPower = nums[1];
                root.gapsOut = nums[2];
                root.gapsIn = nums[3];
                root.borderSize = nums[4];
                root.available = true;
            }
        }
    }

    // niri ----------------------------------------------------------------
    //
    // niri has no IPC call for layout settings, so the config file is the only
    // source. Scraped rather than parsed: KDL is a real grammar and this only
    // needs two numbers. If the scrape misses, `available` stays false and
    // config.json wins, which is the correct failure.
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

            root.gapsOut = gaps ? parseFloat(gaps[1]) : root.gapsOut;
            root.gapsIn = root.gapsOut;
            root.rounding = radius ? parseFloat(radius[1]) : root.rounding;
            // niri draws plain circular corners, so no smoothing to inherit.
            root.roundingPower = 2;
            root.available = true;
        }
    }
}
