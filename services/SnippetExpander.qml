pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property int release: 400
    readonly property int selectWait: 150
    readonly property int copyWait: 220

    property var run: null

    readonly property bool busy: root.run !== null

    function expand(): string {
        if (root.busy)
            return "busy";
        if (!Typist.found)
            return root.fail("wtype is not installed, so snippets cannot be typed.");
        const address = Hypr.focusedAddress;
        if (!address)
            return root.fail("No window is in front.");
        if (Typist.isTerminal(address))
            return root.fail("Terminals cannot select text this way. Use the launcher there.");
        const room = Snippets.keywordRoom();
        if (room < 1)
            return root.fail("No snippet has a keyword yet.");
        root.run = {
            address: address,
            span: room + 1,
            before: Clipboard.entries.find(e => e.id === Clipboard.current) ?? null
        };
        stage.stepName = "select";
        stage.interval = root.release;
        stage.restart();
        return "expanding";
    }

    function select(): void {
        const keys = ["wtype", "-M", "shift"];
        for (let i = 0; i < root.run.span; i++)
            keys.push("-k", "Left");
        keys.push("-m", "shift");
        Keystrokes.send(keys);
        stage.stepName = "copy";
        stage.interval = root.selectWait;
        stage.restart();
    }

    function copySelection(): void {
        Keystrokes.send(["wtype", "-M", "ctrl", "-k", "c", "-m", "ctrl"]);
        stage.stepName = "read";
        stage.interval = root.copyWait;
        stage.restart();
    }

    function finish(copied: string): void {
        const job = root.run;
        root.run = null;
        Keystrokes.send(["wtype", "-k", "Right"]);
        const unchanged = job.before && job.before.text === copied;
        const hit = unchanged ? null : Snippets.keywordBefore(copied);
        if (job.before && !unchanged)
            Clipboard.copy(job.before);
        if (!hit) {
            root.fail("No snippet keyword sits before the cursor.");
            return;
        }
        const keys = ["wtype"];
        for (let i = 0; i < hit.length; i++)
            keys.push("-k", "BackSpace");
        Keystrokes.send(keys);
        const done = Snippets.expand(hit.snippet);
        Typist.type(done.text, done.back, job.address);
    }

    function fail(why: string): string {
        if (Typist.notifies)
            Quickshell.execDetached(["notify-send", "-a", "banditshell", "-i", "short_text", "Snippet not expanded", why]);
        return why;
    }

    Timer {
        id: stage

        property string stepName: ""

        onTriggered: {
            if (!root.run)
                return;
            if (stage.stepName === "select")
                root.select();
            else if (stage.stepName === "copy")
                root.copySelection();
            else
                reader.running = true;
        }
    }

    Process {
        id: reader

        command: ["sh", "-c", "wl-paste -n -t text 2>/dev/null; true"]

        stdout: StdioCollector {
            onStreamFinished: if (root.run)
                root.finish(text)
        }
    }
}
