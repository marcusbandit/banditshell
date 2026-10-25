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

    function moved(paths: var, dir: string): void {
        root.remember(Undo.moved(Undo.into(paths, dir)));
    }

    function renamed(from: string, to: string): void {
        root.remember(Undo.renamed(from, to));
    }

    function trashed(paths: var): void {
        root.remember(Undo.trashed(paths, Date.now() / 1000));
    }

    function beforeCopy(paths: var, dir: string, then: var): void {
        const pairs = Undo.into(paths, dir);
        if (pairs.length === 0)
            return then();
        const targets = pairs.map(pair => pair.to);
        root.start(Undo.existsCommand(targets), text => {
            if (text !== null)
                root.remember(Undo.copied(pairs, Undo.existing(targets, text)));
            then();
        });
    }

    function say(text: string): void {
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
        root.say(Undo.summary(root.running, Undo.outcome(text ?? "")));
        root.running = null;
        Files.refresh();
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
