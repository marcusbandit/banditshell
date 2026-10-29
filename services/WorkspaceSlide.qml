pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    readonly property int longest: 250

    readonly property int ms: Appearance.lessMotion ? 0 : Math.max(0, Math.min(root.longest, Number(Config.values.anim.workspaceSlide ?? 200) || 0))

    readonly property bool ready: Config.ready && Compositor.isHyprland

    property string bezier: ""
    property string style: ""
    property bool owed: false

    onMsChanged: root.apply()
    onReadyChanged: root.apply()

    Connections {
        target: Hypr

        function onConfigReloaded(): void {
            root.bezier = "";
            root.style = "";
            root.apply();
        }
    }

    function apply(): void {
        if (!root.ready)
            return;
        if (reader.running || writer.running) {
            root.owed = true;
            return;
        }
        if (!root.bezier) {
            reader.running = true;
            return;
        }
        const legacy = HyprConfig.configPath.endsWith(".conf");
        const speed = (root.ms / 100).toFixed(2);
        const on = root.ms > 0;
        if (legacy)
            writer.command = ["hyprctl", "keyword", "animation", `workspaces,${on ? 1 : 0},${on ? speed : 1},${root.bezier},${root.style}`];
        else
            writer.command = ["hyprctl", "eval", `hl.animation({ leaf = "workspaces", enabled = ${on}, speed = ${on ? speed : 1}, bezier = "${root.bezier}", style = "${root.style}" })`];
        writer.running = true;
    }

    Process {
        id: reader

        command: ["hyprctl", "-j", "animations"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const groups = JSON.parse(text);
                    for (const group of groups)
                        for (const entry of [].concat(group))
                            if (entry?.name === "workspaces") {
                                root.style = entry.style || "slide";
                                root.bezier = entry.bezier || "default";
                            }
                } catch (e) {
                    console.warn(`WorkspaceSlide: could not read Hyprland's animations (${e}).`);
                }
                if (!root.bezier) {
                    root.bezier = "default";
                    root.style = "slide";
                }
                root.apply();
            }
        }
    }

    Process {
        id: writer

        onExited: if (root.owed) {
            root.owed = false;
            root.apply();
        }

        stdout: StdioCollector {
            onStreamFinished: {
                const answer = text.trim();
                if (answer && answer !== "ok")
                    console.warn(`WorkspaceSlide: Hyprland answered "${answer}".`);
            }
        }
    }
}
