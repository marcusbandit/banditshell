pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    property int kelvin: 3000

    readonly property int warmest: Appearance.sizes.screenWarmest
    readonly property int neutral: Appearance.sizes.screenNeutral
    readonly property bool warm: root.kelvin > 0

    property var displays: []

    readonly property bool brightnessReady: root.displays.length > 0

    property real level: -1

    readonly property bool levelKnown: root.level >= 0

    property var queue: []

    property string currentKind: ""

    readonly property string stateDir: `${Quickshell.env("XDG_STATE_HOME") || `${Quickshell.env("HOME")}/.local/state`}/banditshell`
    readonly property string warmthPath: `${root.stateDir}/warmth`

    Component.onCompleted: {
        root.kelvin = Config.get("screen.warmth") ?? root.kelvin;
        root.level = (Config.get("screen.level") ?? 100) / 100;
        gammaDebounce.restart();
    }

    Connections {
        target: Config

        function onValuesChanged(): void {
            const want = Config.get("screen.warmth");
            if (want !== undefined && want !== null && want !== root.kelvin)
                root.kelvin = want;
        }
    }

    Connections {
        target: Monitors

        function onOutputsChanged(): void {
            root.enqueue("detect", ["ddcutil", "detect", "--brief"]);
        }
    }

    function setWarmth(k: int): void {
        const v = Math.max(0, Math.min(root.neutral, Math.round(k)));
        if (v === root.kelvin)
            return;
        root.kelvin = v;
        gammaDebounce.restart();
    }

    function toggleWarm(): void {
        root.setWarmth(root.warm ? 0 : root.lastWarm);
    }

    property int lastWarm: 3000

    function setLevel(v: real): void {
        const f = Math.max(0, Math.min(1, v));
        if (root.levelKnown && Math.abs(f - root.level) < 0.001)
            return;
        root.level = f;
        levelDebounce.restart();
    }

    function nudgeLevel(sign: int, notches: real): void {
        if (!root.levelKnown)
            return;
        root.setLevel(root.level + sign * notches * 0.04);
    }

    function enqueue(kind: string, command: var): void {
        root.queue = [...root.queue, {
                kind,
                command
            }];
        if (!runner.running)
            step();
    }

    function step(): void {
        const next = root.queue[0] ?? null;
        if (!next) {
            root.currentKind = "";
            return;
        }
        root.queue = root.queue.slice(1);
        root.currentKind = next.kind;
        runner.command = next.command;
        runner.running = true;
    }

    function takeDetect(text: string): void {
        const found = [];
        let current = null;

        for (const raw of text.split("\n")) {
            const line = raw.trim();

            let m = /^Display (\d+)/.exec(line);
            if (m) {
                current = {
                    index: m[1],
                    name: "",
                    model: "",
                    max: 100
                };
                found.push(current);
                continue;
            }

            if (!current)
                continue;

            m = /^DRM connector:\s*\S+-(.+)$/.exec(line);
            if (m) {
                current.name = m[1];
                continue;
            }

            m = /^Monitor:\s*(.+)$/.exec(line);
            if (m) {
                const parts = m[1].split(":");
                current.model = parts.length > 1 ? parts[1] : m[1];
            }
        }

        root.displays = found.filter(d => d.name);
        root.writeLevel();
    }

    function writeLevel(): void {
        if (!root.brightnessReady || !root.levelKnown)
            return;
        root.enqueue("write", ["sh", "-c", root.displays.map(d => `ddcutil --display ${d.index} setvcp 10 ${Math.round(root.level * d.max)} --noverify 2>/dev/null`).join("; ")]);
    }

    function commitWarmth(): void {
        Config.set("screen.warmth", root.kelvin);
        if (root.warm)
            root.lastWarm = root.kelvin;
        fileWrite.command = ["sh", "-c", `printf '${root.kelvin}\\n' > '${root.warmthPath}.tmp' && mv '${root.warmthPath}.tmp' '${root.warmthPath}'`];
        fileWrite.running = false;
        fileWrite.running = true;
    }

    Process {
        id: fileWrite
    }

    Timer {
        id: gammaDebounce

        interval: 200
        onTriggered: root.commitWarmth()
    }

    Timer {
        id: levelDebounce

        interval: 300
        onTriggered: {
            Config.set("screen.level", Math.round(root.level * 100));
            root.writeLevel();
        }
    }

    Process {
        id: runner

        stdout: StdioCollector {
            onStreamFinished: {
                root.currentKind = "";
                pump.restart();
            }
        }
    }

    Timer {
        id: pump

        interval: 50
        onTriggered: runner.running ? pump.restart() : root.step()
    }

    Process {
        id: gamma

        running: true
        command: ["sh", "-c", `mkdir -p '${root.stateDir}'; pgrep -x bs-gamma >/dev/null || exec '${Quickshell.shellPath("bin/bs-gamma")}'`]

        stdout: SplitParser {
            onRead: line => {
                if (!line.startsWith("set ") && !line.startsWith("failed "))
                    console.warn(`Display: gamma said ${line}`);
            }
        }

        stderr: SplitParser {
            onRead: line => console.warn(`Display: ${line}`)
        }

        onExited: code => retry.restart()
    }

    Timer {
        id: retry

        interval: 4000
        onTriggered: gamma.running = true
    }
}
