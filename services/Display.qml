pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "ddcutil.js" as Ddcutil
import "nightlight.js" as Nightlight

Singleton {
    id: root

    property int kelvin: 3000

    readonly property int warmest: Config.values.screen.warmest
    readonly property int neutral: Config.values.screen.neutral
    readonly property bool warm: root.kelvin > 0

    property int lastWarm: 3000

    property bool adopted: false

    property var displays: []

    readonly property bool brightnessReady: root.displays.length > 0

    property real level: -1

    readonly property bool levelKnown: root.level >= 0

    property bool unwritten: false

    property var queue: []

    property string detectedFor: ""

    property bool ddcutilMissing: false

    property var displayLevels: ({})

    property var limits: ({})

    property var pending: ({})

    property var touchedAt: ({})

    property var failures: ({})

    property var unlanded: ({})

    property var rest: ({})

    property var restUntil: ({})

    readonly property int settleMs: 8000

    readonly property int maxFailures: 5

    readonly property string warmthPath: `${Config.stateDir}/warmth`

    readonly property string gammaPath: Quickshell.shellPath("bin/bs-gamma")

    property bool gammaLaunched: false

    property bool gammaGivenUp: false

    readonly property string scheduleMode: Config.values.screen.schedule
    readonly property string warmFrom: Config.values.screen.warmFrom
    readonly property string warmTo: Config.values.screen.warmTo
    readonly property int easeMs: Config.values.screen.easeMinutes * 60000

    readonly property int scheduleTick: 20000

    property var warmWindow: null

    property double heldUntil: 0

    property real appliedFraction: -1

    property bool easing: false

    function status(): string {
        const own = root.displays.filter(d => root.displayLevels[d.index] !== undefined);
        const brightness = !root.brightnessReady ? "none" : own.length ? root.displays.map(d => `${d.name}:${Math.round(root.levelOf(d) * 100)}%`).join(",") : root.levelKnown ? `${Math.round(root.level * 100)}%` : "unknown";
        const names = root.displays.map(d => d.name).join(",") || "none";
        return `brightness=${brightness} displays=${names} warmth=${root.warm ? `${root.kelvin}K` : "off"}`;
    }

    Component.onCompleted: {
        if (Config.ready && !root.adopted)
            root.adoptConfig();
        root.detect();
        root.ensureGamma();
        gammaCheck.restart();
    }

    Connections {
        target: Config

        function onReadyChanged(): void {
            if (Config.ready && !root.adopted)
                root.adoptConfig();
        }
    }

    Connections {
        target: Config.values

        function onScreenChanged(): void {
            if (Config.ready && !gammaDebounce.running)
                root.followWarmth(false);
        }
    }

    Connections {
        target: ToolInstaller

        function onInstalled(tool: string): void {
            if (tool === "ddcutil")
                root.retryDetect();
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
        root.adopted = true;
        root.followWarmth(true);

        const saved = Number(Config.values.screen.level);
        if (!root.levelKnown && isFinite(saved))
            root.level = Math.max(0, Math.min(1, saved / 100));
    }

    function showScreenWarmth(text: string): void {
        const k = Nightlight.warmthOf(text, root.neutral);
        if (root.adopted || k < 0)
            return;
        root.kelvin = k;
        if (root.warm)
            root.lastWarm = k;
    }

    function followWarmth(always: bool): void {
        const want = Number(Config.values.screen.warmth);
        const next = isFinite(want) ? Math.max(0, Math.min(root.neutral, Math.round(want))) : root.kelvin;
        if (next === root.kelvin && !always)
            return;
        root.kelvin = next;
        if (root.warm && !root.easing)
            root.lastWarm = root.kelvin;
        root.writeWarmth();
    }

    function setWarmth(k: int): void {
        root.holdSchedule();
        root.moveWarmth(k);
    }

    function moveWarmth(k: int): void {
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
        if (root.levelKnown && Math.abs(f - root.level) < 0.001 && !Object.keys(root.displayLevels).length)
            return;
        root.level = f;
        root.displayLevels = ({});
        root.writeLevel();
        levelDebounce.restart();
    }

    function levelOf(display: var): real {
        const own = root.displayLevels[display?.index];
        return own !== undefined ? own : root.level;
    }

    function setDisplayLevel(display: var, v: real): void {
        if (!display?.index)
            return;
        const levels = Object.assign({}, root.displayLevels);
        levels[display.index] = Math.max(0, Math.min(1, v));
        root.displayLevels = levels;
        root.markPending([display.index]);
    }

    function markPending(indexes: var): void {
        const pending = Object.assign({}, root.pending);
        const touched = Object.assign({}, root.touchedAt);
        const unlanded = Object.assign({}, root.unlanded);
        const failures = Object.assign({}, root.failures);
        const now = Date.now();
        for (const index of indexes) {
            pending[index] = true;
            touched[index] = now;
            unlanded[index] = true;
            delete failures[index];
        }
        root.pending = pending;
        root.touchedAt = touched;
        root.unlanded = unlanded;
        root.failures = failures;
        if (!displayDebounce.running)
            displayDebounce.start();
    }

    function writeCommand(index: string): var {
        const display = root.displays.find(d => d.index === index);
        const top = root.limits[index];
        return display && top !== undefined ? ["ddcutil", ...Ddcutil.target(display), "setvcp", "10", `${Ddcutil.rawLevel(root.levelOf(display), top)}`, "--noverify"] : null;
    }

    function queued(kind: string): bool {
        return root.queue.some(job => job.kind === kind);
    }

    function readCommand(display: var): var {
        return ["ddcutil", ...Ddcutil.target(display), "getvcp", "10", "--brief"];
    }

    function sendDisplayLevels(): void {
        const now = Date.now();
        const left = {};
        let wait = Infinity;
        for (const index of Object.keys(root.pending)) {
            const display = root.displays.find(d => d.index === index);
            if (!display)
                continue;
            if (now < (root.restUntil[index] ?? 0)) {
                left[index] = true;
                wait = Math.min(wait, root.restUntil[index] - now);
                continue;
            }
            if (root.limits[index] === undefined) {
                left[index] = true;
                if (!root.queued(`read:${index}`) && runner.kind !== `read:${index}`)
                    root.enqueue(`read:${index}`, root.readCommand(display));
                continue;
            }
            if (!root.queued(`write:${index}`))
                root.enqueue(`write:${index}`, () => root.writeCommand(index));
        }
        root.pending = left;
        if (isFinite(wait)) {
            restTimer.interval = Math.max(50, Math.ceil(wait));
            restTimer.restart();
        }
    }

    function failed(index: string): void {
        const failures = Object.assign({}, root.failures);
        failures[index] = (failures[index] ?? 0) + 1;
        root.failures = failures;
        const rest = Object.assign({}, root.rest);
        rest[index] = Ddcutil.restAfter(rest[index], 2500, 12000);
        root.rest = rest;
        root.restUntil = Object.assign({}, root.restUntil, {
            [index]: Date.now() + rest[index]
        });
        if (failures[index] > root.maxFailures) {
            const pending = Object.assign({}, root.pending);
            delete pending[index];
            root.pending = pending;
            const unlanded = Object.assign({}, root.unlanded);
            delete unlanded[index];
            root.unlanded = unlanded;
            console.warn(`Display: display ${index} stopped answering, so its brightness was left as it is`);
            return;
        }
        if (!root.unlanded[index])
            return;
        root.pending = Object.assign({}, root.pending, {
            [index]: true
        });
        if (!displayDebounce.running)
            displayDebounce.start();
    }

    function succeeded(index: string, wrote: bool): void {
        if (root.failures[index])
            root.failures = Object.assign({}, root.failures, {
                [index]: 0
            });
        if (!wrote)
            return;
        if (root.pending[index] === undefined && !root.queued(`write:${index}`)) {
            const unlanded = Object.assign({}, root.unlanded);
            delete unlanded[index];
            root.unlanded = unlanded;
        }
        if (!root.rest[index])
            return;
        root.restUntil = Object.assign({}, root.restUntil, {
            [index]: Date.now() + root.rest[index]
        });
        root.rest = Object.assign({}, root.rest, {
            [index]: Ddcutil.restEased(root.rest[index], 1000)
        });
    }

    property var levelsReadAt: ({})

    function readLevels(): void {
        if (root.ddcutilMissing)
            return;
        const now = Date.now();
        const stamps = Object.assign({}, root.levelsReadAt);
        for (const display of Ddcutil.staleDisplays(root.displays, root.levelsReadAt, now, 30000).filter(d => now >= (root.restUntil[d.index] ?? 0))) {
            stamps[display.index] = now;
            if (!root.queue.some(job => job.kind === `read:${display.index}`))
                root.enqueue(`read:${display.index}`, root.readCommand(display));
        }
        root.levelsReadAt = stamps;
    }

    function retryDetect(): void {
        root.ddcutilMissing = false;
        root.detect();
    }

    function outputKey(): string {
        return Monitors.active.map(o => o.name).sort().join(",");
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
        const writing = next.kind.startsWith("write:") ? next.kind.slice(6) : "";
        if (writing && Date.now() < (root.restUntil[writing] ?? 0)) {
            root.pending = Object.assign({}, root.pending, {
                [writing]: true
            });
            Qt.callLater(root.sendDisplayLevels);
            Qt.callLater(root.step);
            return;
        }
        const command = typeof next.command === "function" ? next.command() : next.command;
        if (!command) {
            if (next.kind.startsWith("write:"))
                root.markPending([next.kind.slice(6)]);
            Qt.callLater(root.step);
            return;
        }
        runner.kind = next.kind;
        runner.command = command;
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
            root.levelsReadAt = ({});
            root.limits = ({});
            root.rest = ({});
            root.restUntil = ({});
            root.failures = ({});
            if (root.unwritten)
                root.writeLevel();
        } else if (kind.startsWith("read:")) {
            const index = kind.slice(5);
            const read = code === 0 ? Ddcutil.parseVcp(output) : null;
            if (!read) {
                root.failed(index);
            } else {
                root.succeeded(index, false);
                root.limits = Object.assign({}, root.limits, {
                    [index]: read.max
                });
                const quiet = root.pending[index] === undefined && !root.queued(`write:${index}`) && Date.now() - (root.touchedAt[index] ?? 0) > root.settleMs;
                if (quiet) {
                    const levels = Object.assign({}, root.displayLevels);
                    levels[index] = Math.max(0, Math.min(1, read.current / read.max));
                    root.displayLevels = levels;
                } else if (root.pending[index] !== undefined) {
                    Qt.callLater(root.sendDisplayLevels);
                }
            }
        } else if (kind.startsWith("write:")) {
            const index = kind.slice(6);
            if (code === 0)
                root.succeeded(index, true);
            else
                root.failed(index);
        }
        runner.kind = "";
        Qt.callLater(root.step);
    }

    function writeLevel(): void {
        root.unwritten = root.levelKnown && !root.brightnessReady;
        if (root.unwritten || !root.levelKnown)
            return;
        root.markPending(root.displays.map(d => d.index));
    }

    function minutesOf(text: string): int {
        return Math.max(0, Nightlight.minutesOf(text));
    }

    function clockOf(minutes: int): string {
        return Nightlight.clockOf(Math.max(0, Math.min(1439, Math.round(minutes))));
    }

    function currentWindow(now: double): var {
        return Nightlight.windowFor(root.scheduleMode, now, {
            place: Localisation.sunPlace,
            from: root.warmFrom,
            to: root.warmTo
        });
    }

    function nightAt(now: double): var {
        return Nightlight.nightAt(root.scheduleMode, now, {
            place: Localisation.sunPlace,
            from: root.warmFrom,
            to: root.warmTo
        });
    }

    function holdSchedule(): void {
        if (root.scheduleMode === "off")
            return;
        root.easing = false;
        const now = Date.now();
        root.heldUntil = Nightlight.nextEdge(now, root.currentWindow(now));
    }

    function restartSchedule(): void {
        root.heldUntil = 0;
        root.appliedFraction = -1;
        root.evaluateSchedule();
    }

    function evaluateSchedule(): void {
        if (root.scheduleMode === "off") {
            root.warmWindow = null;
            root.appliedFraction = -1;
            root.easing = false;
            return;
        }
        const now = Date.now();
        root.warmWindow = root.currentWindow(now);
        if (now < root.heldUntil)
            return;
        const fraction = Nightlight.fractionAt(now, root.warmWindow, root.easeMs);
        if (fraction === root.appliedFraction)
            return;
        const before = root.appliedFraction;
        root.appliedFraction = fraction;
        if (before < 0 && fraction === 0)
            return;
        root.stepSchedule(fraction, fraction > Math.max(0, before));
    }

    function stepSchedule(fraction: real, rising: bool): void {
        root.easing = fraction > 0 && fraction < 1;
        if (fraction <= 0)
            return root.moveWarmth(0);
        const next = Nightlight.warmKelvin(fraction, root.neutral, root.lastWarm);
        if (rising ? root.warm && root.kelvin < next : !root.warm)
            return;
        root.moveWarmth(next);
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
            return console.warn(`Display: ${root.gammaPath} is missing, so warmth is off until \`banditshell dev build\``);
        if (code !== 1)
            return console.warn(`Display: could not look for a running bs-gamma (exit ${code}), so warmth is off`);
        if (root.gammaGivenUp)
            return console.warn("Display: bs-gamma stopped right after it started, so warmth is off");
        root.gammaLaunched = true;
        Quickshell.execDetached([root.gammaPath]);
        gammaCheck.restart();
    }

    function commitWarmth(): void {
        if (!root.easing)
            Config.set("screen.warmth", root.kelvin);
        if (root.warm && !root.easing)
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

    FileView {
        path: root.warmthPath
        watchChanges: false
        printErrors: false

        onLoaded: root.showScreenWarmth(text())
    }

    onScheduleModeChanged: root.restartSchedule()
    onWarmFromChanged: root.restartSchedule()
    onWarmToChanged: root.restartSchedule()
    onEaseMsChanged: root.restartSchedule()

    Connections {
        target: Localisation

        function onSunPlaceChanged(): void {
            root.restartSchedule();
        }
    }

    Timer {
        interval: root.scheduleTick
        repeat: true
        running: root.scheduleMode !== "off"
        onTriggered: root.evaluateSchedule()
    }

    Timer {
        id: gammaDebounce

        interval: 200
        onTriggered: root.commitWarmth()
    }

    Timer {
        id: displayDebounce

        interval: 250
        onTriggered: root.sendDisplayLevels()
    }

    Timer {
        id: restTimer

        onTriggered: root.sendDisplayLevels()
    }

    Timer {
        id: levelDebounce

        interval: 300
        onTriggered: Config.set("screen.level", Math.round(root.level * 100))
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
