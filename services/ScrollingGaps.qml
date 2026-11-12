pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "scrolling-gaps.js" as Gaps

Singleton {
    id: root

    property var version: null
    property var found: null

    readonly property bool declined: Config.values.compositor.scrollingGapsDeclined === true
    readonly property bool uneven: root.found !== null
    readonly property bool stale: Config.writable && !root.declined && root.uneven
    readonly property string summary: Gaps.describe(root.found)
    readonly property string refusal: root.uneven && HyprConfig.scanned ? HyprConfig.optionRefusal("general:gaps_out", "") : ""

    property bool fixing: false
    property string lastResult: ""

    function refresh(): void {
        if (!Compositor.isHyprland)
            return;
        if (root.version === null)
            versionReader.running = true;
        else
            optionReader.running = true;
    }

    function fix(): void {
        if (!root.found || root.fixing)
            return;
        root.fixing = true;
        root.lastResult = "";
        if (!HyprConfig.setOption("general:gaps_out", root.found.want, ""))
            root.fixing = false;
    }

    function decline(): void {
        if (!root.declined)
            Config.set("compositor.scrollingGapsDeclined", true);
    }

    Process {
        id: versionReader

        command: ["hyprctl", "-j", "version"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.version = Gaps.readVersion(text);
                if (root.version)
                    optionReader.running = true;
            }
        }
    }

    Process {
        id: optionReader

        command: ["hyprctl", "-j", "--batch", Gaps.batch()]

        stdout: StdioCollector {
            onStreamFinished: root.found = Gaps.check(Object.assign({
                    version: root.version
                }, Gaps.readOptions(text)))
        }
    }

    Component.onCompleted: root.refresh()

    Connections {
        target: Hypr

        function onConfigReloaded(): void {
            root.refresh();
        }
    }

    Connections {
        target: HyprConfig

        function onOptionSettled(path: string, device: string, ok: bool, said: string): void {
            if (path !== "general:gaps_out" || !root.fixing)
                return;
            root.fixing = false;
            root.lastResult = ok ? "Fixed. The gaps are even now." : `Could not fix it: ${said}`;
            root.refresh();
        }
    }
}
