pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "usage-limits.js" as Limits

Singleton {
    id: root

    readonly property string shaderPath: Quickshell.shellPath("assets/shaders/desaturate.frag")

    property int usedMinutes: 0

    property var clock: Limits.beginClock(Date.now())

    property bool greyApplied: false

    property var settledFor: null

    readonly property bool breaksOn: Config.values.usage.breaks

    readonly property bool greyWanted: Config.values.usage.greyAtCap && Limits.overCap(root.usedMinutes, Config.values.usage.capHours)

    function measure(): void {
        root.usedMinutes = Usage.forDay(new Date()).minutes;
        const result = Limits.advanceClock(root.clock, Date.now(), Idle.idle ? Idle.idleSince : null, Config.values.usage.breakEvery, root.breaksOn);
        root.clock = result.clock;
        if (result.nudge)
            Quickshell.execDetached(["notify-send", "-a", "banditshell", "-i", "self_improvement", "Time for a break", Limits.breakNote(result.unbrokenMs)]);
    }

    function syncGrey(): void {
        if (!Hypr.parserKnown || probe.running || root.greyWanted === root.settledFor)
            return;
        probe.running = true;
    }

    function probed(output: string): void {
        const wanted = root.greyWanted;
        const owner = Limits.shaderOwner(output, root.shaderPath);
        root.settledFor = wanted;
        if (owner === "unknown")
            return;
        if (!wanted) {
            if (owner === "ours")
                root.setShader("");
            return;
        }
        if (owner === "foreign")
            console.warn("UsageLimits: another screen shader is set, so the screen stays in colour at the cap");
        else if (owner === "free")
            root.setShader(root.shaderPath);
    }

    function setShader(path: string): void {
        root.greyApplied = path !== "";
        if (Hypr.lua)
            Quickshell.execDetached(["hyprctl", "eval", `hl.config({ decoration = { screen_shader = "${path}" } })`]);
        else
            Quickshell.execDetached(["hyprctl", "keyword", "decoration:screen_shader", path]);
    }

    onGreyWantedChanged: root.syncGrey()

    Component.onCompleted: {
        root.measure();
        root.syncGrey();
    }

    Component.onDestruction: if (root.greyApplied)
        root.setShader("")

    Connections {
        target: Usage

        function onChanged(): void {
            root.measure();
        }
    }

    Connections {
        target: Hypr

        function onParserKnownChanged(): void {
            root.syncGrey();
        }

        function onConfigReloaded(): void {
            root.settledFor = null;
            root.syncGrey();
        }
    }

    Process {
        id: probe

        command: ["hyprctl", "-j", "getoption", "decoration:screen_shader"]

        stdout: StdioCollector {
            id: probeOutput
        }

        onExited: {
            root.probed(probeOutput.text);
            root.syncGrey();
        }
    }
}
