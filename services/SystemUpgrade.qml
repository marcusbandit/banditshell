pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "system-upgrade.js" as Upgrade

Singleton {
    id: root

    readonly property string runner: `${Quickshell.shellDir}/scripts/system-upgrade.sh`
    readonly property string dir: `${Quickshell.env("XDG_RUNTIME_DIR") ? `${Quickshell.env("XDG_RUNTIME_DIR")}/banditshell` : `${Config.cacheDir}/run`}/upgrade`

    property string state: "idle"
    readonly property bool running: root.state === "running"
    readonly property bool finished: ["done", "current", "cancelled", "failed"].includes(root.state)
    readonly property bool shown: root.state !== "idle"
    readonly property bool good: root.state === "done" || root.state === "current"

    property string tool: Pacman.tool || "pacman"
    readonly property string program: root.tool === "apt" ? "apt-get" : root.tool

    property var work: Upgrade.create(root.tool)
    property bool dirty: false

    property string phase: "auth"
    property real progress: 0
    property var fills: [0, 0, 0, 0]
    readonly property var stageNames: ["Download", "Verify", "Install", "Finish"]
    property int stage: 0
    property string detail: ""
    property string brief: ""
    property var question: null
    property int answered: 0
    property int total: 0
    property string downloadSize: ""
    property var warnings: []
    property var errors: []
    property bool cancellable: false
    property bool cancelling: false
    property string reason: ""
    property int code: -1
    property string kernelTo: ""
    property real startedAt: 0

    readonly property int expected: Pacman.updates.length
    readonly property string headline: Upgrade.headline(root.work, root.state)
    readonly property bool asking: !!root.question && root.question.id !== root.answered
    readonly property bool needsAnswer: root.asking && !Upgrade.proceeds(root.question)

    property bool glanced: false
    readonly property bool quiet: root.running && root.glanced && root.phase !== "auth" && !root.needsAnswer

    readonly property var plan: Upgrade.plan(Config.values.packages.upgrade, Pacman.tool || "pacman")

    property int watchers: 0
    readonly property bool watched: root.watchers > 0
    readonly property int lingerMs: Math.max(1, Config.values.island.glanceSeconds) * 1000

    function start(): bool {
        if (root.running || root.mocked)
            return true;
        if (!Quickshell.env("BANDITSHELL_UPGRADE_COMMAND") && (!Polkit.serving || !root.plan.plain))
            return false;
        root.tool = Pacman.tool || "pacman";
        root.reset();
        root.state = "running";
        root.startedAt = Date.now();
        root.kernelTo = Pacman.kernelUpdate ? Pacman.pretty(Pacman.kernelUpdate.to) : "";
        Polkit.expect("Update the system", root.program);
        starter.command = [root.runner, "start", root.dir, ...(root.plan.noconfirm ? ["--noconfirm"] : [])];
        starter.running = true;
        return true;
    }

    property bool mocked: false

    function mock(text: string, code: int, kernel: string): void {
        root.tool = "pacman";
        root.reset();
        root.mocked = true;
        root.state = "running";
        root.kernelTo = kernel;
        Upgrade.feed(root.work, text);
        if (code === -2)
            root.publish();
        else
            root.finish(code);
    }

    function unmock(): void {
        if (!root.mocked)
            return;
        root.reset();
        root.state = "idle";
        root.attach();
    }

    function reset(): void {
        if (follower.running) {
            root.dropExit = true;
            follower.running = false;
        }
        root.pendingCode = -2;
        root.mocked = false;
        root.followed = false;
        proceed.stop();
        proceed.id = 0;
        root.work = Upgrade.create(root.tool);
        root.answered = 0;
        root.glanced = false;
        root.cancelling = false;
        root.reason = "";
        root.code = -1;
        root.publish();
    }

    function cancel(): void {
        if (!root.running || !root.cancellable)
            return;
        root.cancelling = true;
        if (root.mocked)
            return;
        if (root.phase === "auth" && Polkit.ours && Polkit.active) {
            Polkit.refuse();
            return;
        }
        canceller.running = true;
    }

    function answer(text: string): void {
        if (!root.question)
            return;
        root.answered = root.question.id;
        if (root.question.kind === "yesno" && text === "n")
            root.work.declined = true;
        if (!root.mocked)
            Quickshell.execDetached([root.runner, "answer", root.dir, text]);
    }

    function openTerminal(): void {
        if (root.mocked)
            return;
        Quickshell.execDetached([`${Quickshell.shellDir}/scripts/in-terminal.sh`, `'${root.runner}' watch '${root.dir}'`]);
    }

    function runInTerminal(): void {
        if (root.mocked)
            return;
        root.acknowledge();
        Pacman.upgrade();
    }

    function acknowledge(): void {
        if (!root.finished)
            return;
        if (!root.mocked)
            Quickshell.execDetached([root.runner, "seen", root.dir]);
        root.state = "idle";
    }

    function attach(): void {
        prober.running = true;
    }

    property bool followed: false

    function follow(pid: int): void {
        root.followed = true;
        root.work = Upgrade.create(root.tool);
        follower.command = pid > 0 ? ["tail", "-c", "+1", "-f", `--pid=${pid}`, "-s", "0.5", "--", `${root.dir}/log`] : ["cat", "--", `${root.dir}/log`];
        follower.running = true;
    }

    function finish(code: int): void {
        Upgrade.feed(root.work, "\n");
        root.code = code;
        const result = Upgrade.outcome(root.work, code);
        root.reason = result === "failed" || result === "cancelled" ? Upgrade.explain(root.work, code) : "";
        root.cancelling = false;
        root.state = result;
        root.publish();
        root.release();
        if (!root.mocked) {
            Pacman.probe(false);
            Pacman.probe(true);
        }
    }

    function release(): void {
        if (Polkit.expected?.program === root.program)
            Polkit.forget();
    }

    function same(a: var, b: var): bool {
        return JSON.stringify(a) === JSON.stringify(b);
    }

    function publish(): void {
        const w = root.work;
        const done = root.state === "done" || root.state === "current";
        root.dirty = false;
        root.phase = w.phase;
        root.progress = Upgrade.fraction(w, done);
        const fills = Upgrade.stages(w, done).map(s => s.fill);
        if (!root.same(fills, root.fills))
            root.fills = fills;
        root.stage = done ? 3 : Upgrade.stageIndex(w);
        root.detail = Upgrade.describe(w);
        root.brief = Upgrade.brief(w);
        root.total = w.total;
        root.downloadSize = w.sizes.download;
        root.cancellable = root.running && Upgrade.cancellable(w);
        if (!root.same(w.question, root.question))
            root.question = w.question ? Object.assign({}, w.question) : null;
        if (!root.same(w.warnings, root.warnings))
            root.warnings = w.warnings.slice();
        if (!root.same(w.errors, root.errors))
            root.errors = w.errors.slice();
        if (w.phase !== "auth")
            root.release();
        if (root.running && !root.mocked && root.asking && Upgrade.proceeds(root.question) && proceed.id !== root.question.id) {
            proceed.id = root.question.id;
            proceed.restart();
        }
    }

    onNeedsAnswerChanged: if (root.needsAnswer)
        root.glanced = false

    Component.onCompleted: root.attach()

    Timer {
        id: proceed

        property int id: 0

        interval: 400
        onTriggered: if (root.running && root.asking && root.question.id === proceed.id && root.work.question?.id === proceed.id)
            root.answer("y")
    }

    Timer {
        interval: 100
        repeat: true
        running: root.dirty
        onTriggered: root.publish()
    }

    Timer {
        interval: root.lingerMs
        running: root.running && !root.glanced && root.phase !== "auth" && !root.needsAnswer
        onTriggered: root.glanced = true
    }

    Timer {
        interval: 15000
        running: root.cancelling && root.running
        onTriggered: root.cancelling = false
    }

    Timer {
        interval: root.lingerMs
        running: root.finished && root.state !== "failed" && !root.watched
        onTriggered: root.acknowledge()
    }

    Process {
        id: starter

        onExited: code => {
            if (code === 0 || code === 3) {
                root.attach();
                return;
            }
            root.release();
            if (code === 4) {
                root.state = "idle";
                Pacman.upgrade();
                return;
            }
            root.reason = "The update could not start.";
            root.state = "failed";
        }
    }

    Process {
        id: prober

        command: [root.runner, "state", root.dir]

        stdout: StdioCollector {
            onStreamFinished: {
                const got = {};
                for (const line of text.split("\n")) {
                    const at = line.indexOf("=");
                    if (at > 0)
                        got[line.slice(0, at)] = line.slice(at + 1);
                }
                const pid = Number(got.pid) || 0;
                if (got.tool)
                    root.tool = got.tool;
                if (pid > 0) {
                    if (root.state !== "running") {
                        root.reset();
                        root.state = "running";
                        Polkit.expect("Update the system", root.program);
                    }
                    if (!follower.running)
                        root.follow(pid);
                    return;
                }
                if (got.status === undefined) {
                    if (root.state === "running")
                        root.finish(-1);
                    return;
                }
                if (root.state !== "running" && got.seen === "1")
                    return;
                const code = got.status === "" ? -1 : Number(got.status);
                if (root.state === "running" && root.followed) {
                    root.finish(code);
                    return;
                }
                if (root.state !== "running") {
                    root.reset();
                    root.state = "running";
                }
                root.pendingCode = code;
                root.follow(0);
            }
        }
    }

    property int pendingCode: -2
    property bool dropExit: false

    Process {
        id: follower

        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                Upgrade.feed(root.work, data);
                root.dirty = true;
            }
        }

        onExited: {
            if (root.dropExit) {
                root.dropExit = false;
                return;
            }
            if (root.mocked)
                return;
            if (root.pendingCode !== -2) {
                const code = root.pendingCode;
                root.pendingCode = -2;
                root.finish(code);
                return;
            }
            if (root.running)
                root.attach();
        }
    }

    Process {
        id: canceller

        command: [root.runner, "cancel", root.dir]

        onExited: code => {
            if (code !== 0)
                root.cancelling = false;
        }
    }
}
