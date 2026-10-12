pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "ddcutil.js" as Ddcutil

Singleton {
    id: root

    property int kelvin: 3000

    readonly property int warmest: Appearance.sizes.screenWarmest
    readonly property int neutral: Appearance.sizes.screenNeutral
    readonly property bool warm: root.kelvin > 0

    property int lastWarm: 3000

    property var displays: []

    readonly property bool brightnessReady: root.displays.length > 0

    property real level: -1

    readonly property bool levelKnown: root.level >= 0

    property bool unwritten: false

    property var queue: []

    property string detectedFor: ""

    property bool ddcutilMissing: false

    readonly property string stateDir: `${Quickshell.env("XDG_STATE_HOME") || `${Quickshell.env("HOME")}/.local/state`}/banditshell`
    readonly property string warmthPath: `${root.stateDir}/warmth`

    readonly property string gammaPath: Quickshell.shellPath("bin/bs-gamma")

    property bool gammaLaunched: false

    property bool gammaGivenUp: false

    function status(): string {
        const brightness = !root.brightnessReady ? "none" : root.levelKnown ? `${Math.round(root.level * 100)}%` : "unknown";
        const names = root.displays.map(d => d.name).join(",") || "none";
        return `brightness=${brightness} displays=${names} warmth=${root.warm ? `${root.kelvin}K` : "off"}`;
    }

    Component.onCompleted: {
        if (Config.loaded)
            root.adoptConfig();
        root.detect();
        root.ensureGamma();
        gammaCheck.restart();
    }

    Connections {
        target: Config

        function onLoadedChanged(): void {
            if (Config.loaded)
                root.adoptConfig();
        }

        function onValuesChanged(): void {
            if (Config.loaded && !gammaDebounce.running)
                root.followWarmth(false);
        }
    }

    Connections {
        target: Monitors

        function onOutputsChanged(): void {
            if (root.outputKey() !== root.detectedFor)
                root.detect();
        }
    }

    function adoptConfig(): void {
        root.followWarmth(true);

        const saved = Number(Config.values.screen.level);
        if (!root.levelKnown && isFinite(saved))
            root.level = Math.max(0, Math.min(1, saved / 100));
    }

    function followWarmth(always: bool): void {
        const want = Number(Config.values.screen.warmth);
        const next = isFinite(want) ? Math.max(0, Math.min(root.neutral, Math.round(want))) : root.kelvin;
        if (next === root.kelvin && !always)
            return;
        root.kelvin = next;
        if (root.warm)
            root.lastWarm = root.kelvin;
        root.writeWarmth();
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

    function setLevel(v: real): void {
        const f = Math.max(0, Math.min(1, v));
        if (root.levelKnown && Math.abs(f - root.level) < 0.001)
            return;
        root.level = f;
        levelDebounce.restart();
    }

    function outputKey(): string {
        return Monitors.outputs.map(o => o.name).sort().join(",");
    }

    function detect(): void {
        root.detectedFor = root.outputKey();
        if (root.ddcutilMissing || root.queue.some(job => job.kind === "detect"))
            return;
        root.enqueue("detect", ["sh", "-c", "exec ddcutil detect --brief 2>/dev/null"]);
    }

    function enqueue(kind: string, command: var): void {
        root.queue = [...root.queue, {
                kind,
                command
            }];
        root.step();
    }

    function step(): void {
        if (runner.running || root.queue.length === 0)
            return;
        const next = root.queue[0];
        root.queue = root.queue.slice(1);
        runner.kind = next.kind;
        runner.command = next.command;
        runner.running = true;
    }

    function finish(kind: string, code: int, output: string): void {
        if (kind === "detect") {
            if (code === 127) {
                root.ddcutilMissing = true;
                console.warn("Display: ddcutil is not installed, so brightness stays hidden");
            } else if (code !== 0) {
                console.warn(`Display: ddcutil detect exited ${code}`);
            }
            root.displays = code === 0 ? Ddcutil.parseDetect(output) : [];
            if (root.unwritten)
                root.writeLevel();
        }
        Qt.callLater(root.step);
    }

    function writeLevel(): void {
        root.unwritten = root.levelKnown && !root.brightnessReady;
        if (root.unwritten || !root.levelKnown)
            return;
        root.queue = root.queue.filter(job => job.kind !== "write");
        root.enqueue("write", ["sh", "-c", root.displays.map(d => `ddcutil --display ${d.index} setvcp 10 ${Math.round(root.level * d.max)} --noverify 2>/dev/null`).join("; ")]);
    }

    function writeWarmth(): void {
        warmthFile.setText(`${root.kelvin}\n`);
        root.ensureGamma();
    }

    function ensureGamma(): void {
        if (root.gammaGivenUp || gammaGuard.running)
            return;
        gammaGuard.running = true;
    }

    function gammaChecked(code: int): void {
        if (code === 0) {
            root.gammaLaunched = false;
            return;
        }
        root.gammaGivenUp = code !== 1 || root.gammaLaunched;
        if (code === 10)
            return console.warn(`Display: ${root.gammaPath} is missing, so warmth is off until \`banditshell build\``);
        if (code !== 1)
            return console.warn(`Display: could not look for a running bs-gamma (exit ${code}), so warmth is off`);
        if (root.gammaGivenUp)
            return console.warn("Display: bs-gamma stopped right after it started, so warmth is off");
        root.gammaLaunched = true;
        Quickshell.execDetached([root.gammaPath]);
        gammaCheck.restart();
    }

    function commitWarmth(): void {
        Config.set("screen.warmth", root.kelvin);
        if (root.warm)
            root.lastWarm = root.kelvin;
        root.writeWarmth();
    }

    FileView {
        id: warmthFile

        path: root.warmthPath
        preload: false
        watchChanges: false

        onSaveFailed: err => console.warn(`Display: could not write ${root.warmthPath} (${FileViewError.toString(err)})`)
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

        property string kind: ""

        stdout: StdioCollector {
            id: runnerOutput
        }

        onExited: code => root.finish(runner.kind, code, runnerOutput.text)
    }

    Process {
        id: gammaGuard

        command: ["sh", "-c", "[ -x \"$1\" ] || exit 10; pgrep -u \"$(id -u)\" -x bs-gamma >/dev/null", "sh", root.gammaPath]

        onExited: code => root.gammaChecked(code)
    }

    Timer {
        id: gammaCheck

        interval: 2000
        onTriggered: root.ensureGamma()
    }
}
