pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "files-undo.js" as Undo

Singleton {
    id: root

    property var stack: []
    property string notice: ""
    property var running: null
    property int waiting: 0

    function remember(entry: var): void {
        root.stack = Undo.remember(root.stack, entry);
    }

    function moving(paths: var, dir: string, then: var): void {
        root.before(Undo.moved(Undo.into(paths, dir)), then);
    }

    function renaming(from: string, to: string, then: var): void {
        root.before(Undo.renamed(from, to), then);
    }

    function copying(paths: var, dir: string, then: var): void {
        root.before(Undo.copied(Undo.into(paths, dir)), then);
    }

    function trashed(paths: var): void {
        root.remember(Undo.trashed(paths, Date.now() / 1000));
    }

    function before(entry: var, then: var): void {
        if (entry.pairs.length === 0)
            return then();
        const targets = entry.pairs.map(pair => pair.to);
        root.start(Undo.existsCommand(targets), text => {
            if (text !== null)
                root.remember(Undo.fresh(entry, Undo.existing(targets, text)));
            then();
        });
    }

    function say(text: string): void {
        Files.failure = "";
        root.notice = text;
        fade.restart();
    }

    function undo(): void {
        if (root.running) {
            root.waiting += 1;
            return;
        }
        if (root.stack.length === 0)
            return root.say("Nothing to undo");
        if (Files.working > 0)
            return root.say("Still working, try again in a moment");

        const entry = root.stack[root.stack.length - 1];
        root.stack = root.stack.slice(0, -1);
        root.running = entry;

        if (entry.kind === "trash")
            root.start(Undo.TRASH_LISTING, text => root.start(Undo.command(entry, Undo.pick(Undo.parseTrash(text ?? ""), entry)), root.finish));
        else
            root.start(Undo.command(entry, []), root.finish);
    }

    function start(command: var, done: var): void {
        step.createObject(root, {
            command: command,
            done: done,
            running: true
        });
    }

    function finish(text: var): void {
        const counts = Undo.outcome(text ?? "");
        const said = Undo.summary(root.running, counts);
        if (counts.ok > 0)
            root.say(said);
        else
            Files.failure = said;
        root.running = null;
        Files.refresh();
        if (root.stack.length === 0)
            root.waiting = 0;
        if (root.waiting > 0) {
            root.waiting -= 1;
            root.undo();
        }
    }

    Timer {
        id: fade

        interval: 4000

        onTriggered: root.notice = ""
    }

    Component {
        id: step

        Process {
            id: task

            property var done: null
            property bool begun: false
            property bool over: false

            function end(text: var): void {
                if (task.over)
                    return;
                task.over = true;
                task.done(text);
                task.destroy();
            }

            stdout: StdioCollector {
                onStreamFinished: task.end(text)
            }

            onStarted: task.begun = true

            onRunningChanged: if (!task.running && !task.begun)
                task.end(null)
        }
    }
}
