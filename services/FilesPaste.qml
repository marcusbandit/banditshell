pragma Singleton

import QtQuick
import Quickshell
import "files-conflicts.js" as Conflicts

Singleton {
    id: root

    property var items: []
    property var chosen: []
    property bool cut: false
    property bool busy: false
    property var then: null

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
        root.run(Conflicts.command(ops, cut), (text, errors) => {
            Files.working -= 1;
            root.busy = false;
            const outcome = Conflicts.results(ops, text ?? "");
            FilesUndo.pasted(cut, outcome.pairs, outcome.replaced, at);
            if (then)
                then(outcome);
            const failed = Conflicts.failure(outcome, cut, ops.length, errors);
            if (failed)
                Files.failure = failed;
            else if (Conflicts.notice(outcome))
                FilesUndo.say(Conflicts.notice(outcome));
            Files.refresh();
        });
    }

    function run(command: var, done: var): void {
        FilesUndo.start(command, done);
    }
}
