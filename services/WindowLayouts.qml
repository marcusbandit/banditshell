pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../modules/launcher/search.js" as Search

Singleton {
    id: root

    property string current: ""

    property bool scrolling: false

    property var plugins: []

    readonly property var configured: Search.luaLayouts(Object.values(HyprConfig.texts))

    readonly property var available: ["dwindle", "master", ...(root.scrolling ? ["scrolling"] : []), ...(root.plugins.some(p => /hy3/i.test(p)) ? ["hy3"] : []), ...root.configured, ...WorkshopLayouts.names.filter(name => !root.configured.includes(name))]

    function use(name: string): void {
        root.current = name;
        const bare = name.replace(/^lua:/, "");
        Quickshell.execDetached(Hypr.lua ? ["hyprctl", "eval", `hl.config({ general = { layout = "${name}" } }) if apply_layout_binds then apply_layout_binds("${bare}") end`] : ["hyprctl", "keyword", "general:layout", name]);
        reread.restart();
    }

    function probe(): void {
        if (!prober.running)
            prober.running = true;
    }

    Component.onCompleted: root.probe()

    Connections {
        target: Hypr

        function onConfigReloaded(): void {
            root.probe();
        }
    }

    Timer {
        id: reread

        interval: 400
        onTriggered: root.probe()
    }

    Process {
        id: prober

        command: ["sh", "-c", "hyprctl -j getoption general:layout; echo; hyprctl -j getoption scrolling:column_width; echo; hyprctl plugin list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                for (const line of lines) {
                    if (!line.trim().startsWith("{"))
                        continue;
                    try {
                        const o = JSON.parse(line);
                        if (o.option === "general:layout")
                            root.current = o.str ?? "";
                        else if (o.option === "scrolling:column_width")
                            root.scrolling = true;
                    } catch (e) {}
                }
                root.plugins = lines.map(line => /^\s*Plugin\s+(.+?)\s+by\s/.exec(line)?.[1]).filter(Boolean);
            }
        }
    }
}
