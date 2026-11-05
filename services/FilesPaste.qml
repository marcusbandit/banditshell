pragma Singleton

import QtQuick
import Quickshell
import "files-conflicts.js" as Conflicts
import "files-commands.js" as FilesCommands

Singleton {
    id: root

    property var items: []
    property var chosen: []
    property bool cut: false
    property bool busy: false
    property var then: null

    property bool active: false
    property bool shown: false
    property bool stopping: false
    property bool measuring: false
    property bool sizing: false
    property string title: ""
    property real copied: 0
    property real total: 0
    property var sources: []
    property var targets: []
    property var job: null
    property int round: 0

    readonly property string line: root.stopping ? "Stopping, " + root.title.toLowerCase() : FilesCommands.progressLine(root.title, root.copied, root.total)

    readonly property int asking: root.busy ? -1 : Conflicts.next(root.chosen)
    readonly property var question: root.asking >= 0 ? root.items[root.asking] : null
    readonly property int waiting: root.question ? Conflicts.waiting(root.items, root.chosen) : 0

    function start(paths: var, dir: string, cut: bool, then: var): void {
        if (root.busy || root.question)
            return FilesUndo.say("Still pasting, try again in a moment");
        Files.failure = "";
        const all = Conflicts.items(paths, dir, cut);
        const looped = Conflicts.loops(all);
        if (looped.length > 0)
            Files.failure = Conflicts.loopRefusal(looped);
        const list = Conflicts.placeable(all);
        if (list.length === 0)
            return;
        root.busy = true;
        root.cut = cut;
        root.then = then ?? null;
        root.run(Conflicts.probeCommand(list), text => {
            root.items = Conflicts.probed(list, text ?? "");
            root.chosen = Conflicts.choices(root.items);
            root.busy = false;
            root.proceed();
        });
    }

    function answer(choice: string, all: bool): void {
        if (!root.question)
            return;
        root.chosen = Conflicts.answer(root.items, root.chosen, root.asking, choice, all);
        root.proceed();
    }

    function cancel(): void {
        root.items = [];
        root.chosen = [];
        root.then = null;
    }

    function proceed(): void {
        if (Conflicts.next(root.chosen) >= 0)
            return;
        const ops = Conflicts.operations(root.items, root.chosen);
        const cut = root.cut;
        const then = root.then;
        root.cancel();
        if (ops.length === 0)
            return;
        const at = Date.now() / 1000;
        root.busy = true;
        Files.working += 1;
        root.title = Conflicts.busyTitle(ops, cut);
        root.sources = ops.map(op => op.from);
        root.targets = ops.map(op => op.target);
        root.round += 1;
        root.copied = 0;
        root.total = 0;
        root.measuring = false;
        root.sizing = false;
        root.stopping = false;
        root.shown = false;
        root.active = true;
        pulse.interval = 1000;
        pulse.restart();
        root.job = root.run(Conflicts.command(ops, cut), (text, errors) => {
            pulse.stop();
            root.active = false;
            root.shown = false;
            root.job = null;
            Files.working -= 1;
            root.busy = false;
            const outcome = Conflicts.results(ops, text ?? "");
            FilesUndo.pasted(cut, outcome.pairs, outcome.replaced, at);
            FilesUndo.show(Conflicts.arrived(outcome.pairs, Files.cwd));
            if (then)
                then(outcome);
            const stopped = Conflicts.stoppedLine(outcome, cut, Conflicts.folderName(ops[0].dir, Files.home));
            const failed = stopped || Conflicts.failure(outcome, cut, ops.length, errors);
            if (failed)
                Files.failure = failed;
            else if (Conflicts.notice(outcome))
                FilesUndo.say(Conflicts.notice(outcome));
            Files.refresh();
        });
    }

    function run(command: var, done: var): var {
        return FilesUndo.start(command, done);
    }

    function stop(): void {
        if (!root.active || root.stopping || !root.job)
            return;
        root.stopping = true;
        root.job.signal(15);
    }

    function measure(): void {
        root.shown = true;
        const round = root.round;
        if (!root.measuring) {
            root.measuring = true;
            root.run(Conflicts.sizeCommand(root.sources), text => {
                if (root.active && round === root.round)
                    root.total = Conflicts.sizeTotal(text ?? "");
            });
        }
        if (root.sizing)
            return;
        root.sizing = true;
        const began = Date.now();
        root.run(Conflicts.sizeCommand(root.targets), text => {
            if (round !== root.round)
                return;
            root.sizing = false;
            pulse.interval = Math.max(1000, (Date.now() - began) * 3);
            if (root.active)
                root.copied = Conflicts.sizeTotal(text ?? "");
        });
    }

    Timer {
        id: pulse

        interval: 1000
        repeat: true

        onTriggered: root.measure()
    }
}
