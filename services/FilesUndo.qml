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

    function renaming(from: string, to: string, then: var): void {
        root.before(Undo.renamed(from, to), then);
    }

    function trashed(paths: var): void {
        root.remember(Undo.trashed(paths, Date.now() / 1000));
    }

    function pasted(cut: bool, pairs: var, replaced: var, at: real): void {
        root.remember(Undo.batch([cut ? Undo.moved(pairs) : Undo.copied(pairs), Undo.trashed(replaced, at)]));
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

        root.perform(entry, root.finish);
    }

    function perform(entry: var, done: var): void {
        if (entry.kind === "batch")
            root.picked(entry.parts, picks => root.chain(entry.parts.map((part, i) => Undo.command(part, picks[i])), [], done));
        else if (entry.kind === "trash")
            root.picked([entry], picks => root.start(Undo.command(entry, picks[0]), out => done([out])));
        else
            root.start(Undo.command(entry, []), out => done([out]));
    }

    function picked(parts: var, done: var): void {
        root.start(Undo.TRASH_LISTING, text => {
            const items = Undo.parseTrash(text ?? "");
            done(parts.map(part => part.kind === "trash" ? Undo.pick(items, part) : []));
        });
    }

    function chain(commands: var, texts: var, done: var): void {
        if (texts.length === commands.length)
            return done(texts);
        root.start(commands[texts.length], out => root.chain(commands, texts.concat([out]), done));
    }

    function start(command: var, done: var): void {
        step.createObject(root, {
            command: command,
            done: done,
            running: true
        });
    }

    function finish(texts: var): void {
        const told = Undo.report(root.running, texts);
        if (told.ok)
            root.say(told.text);
        else
            Files.failure = told.text;
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
                task.done(text, complaint.text);
                task.destroy();
            }

            stdout: StdioCollector {
                onStreamFinished: task.end(text)
            }

            stderr: StdioCollector {
                id: complaint
            }

            onStarted: task.begun = true

            onRunningChanged: if (!task.running && !task.begun)
                task.end(null)
        }
    }
}
