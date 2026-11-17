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
    readonly property var written: Config.values.compositor.scrollingGapsFix
    readonly property bool uneven: root.found !== null
    readonly property bool stale: Config.writable && !root.declined && root.uneven
    readonly property string summary: Gaps.describe(root.found)
    readonly property string refusal: root.uneven && HyprConfig.scanned ? HyprConfig.optionRefusal("general:gaps_out", "") : ""

    property bool fixing: false
    property var fixed: null
    property string failure: ""
    property bool again: false

    function refresh(): void {
        if (!Compositor.isHyprland || root.declined)
            return;
        if (versionReader.running || optionReader.running)
            root.again = true;
        else if (root.version === null)
            versionReader.running = true;
        else
            optionReader.running = true;
    }

    function settled(): void {
        if (!root.again)
            return;
        root.again = false;
        root.refresh();
    }

    function fix(): void {
        if (!root.found || root.fixing)
            return;
        root.fixing = true;
        root.failure = "";
        root.fixed = root.found;
        if (!HyprConfig.setOption("general:gaps_out", root.found.want, ""))
            root.fixing = false;
    }

    function dismiss(): void {
        root.failure = "";
    }

    function decline(): void {
        if (!root.declined)
            Config.set("compositor.scrollingGapsDeclined", true);
    }

    onDeclinedChanged: if (!root.declined)
        root.refresh()

    Process {
        id: versionReader

        command: ["hyprctl", "-j", "version"]

        stdout: StdioCollector {
            onStreamFinished: root.version = Gaps.readVersion(text)
        }

        onExited: {
            if (root.version) {
                root.again = false;
                optionReader.running = true;
            } else {
                root.settled();
            }
        }
    }

    Process {
        id: optionReader

        command: ["hyprctl", "-j", "--batch", Gaps.batch()]

        stdout: StdioCollector {
            onStreamFinished: {
                const next = Gaps.check(Object.assign({
                        version: root.version,
                        fix: root.written
                    }, Gaps.readOptions(text)));
                if (JSON.stringify(next) !== JSON.stringify(root.found))
                    root.failure = "";
                root.found = next;
            }
        }

        onExited: root.settled()
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
            if (ok)
                Config.set("compositor.scrollingGapsFix", Gaps.remembered(root.fixed));
            else
                root.failure = said;
            root.refresh();
        }
    }
}
