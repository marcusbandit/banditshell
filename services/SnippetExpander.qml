pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property int armWait: 60
    readonly property int keysWait: 90
    readonly property int readWait: 120
    readonly property int reads: 4
    readonly property int restoreWait: 350
    readonly property int limit: 6000
    readonly property var letGo: ["-m", "ctrl", "-m", "alt", "-m", "altgr", "-m", "logo", "-m", "shift"]

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
            before: Clipboard.entries.find(e => e.id === Clipboard.current) ?? null,
            token: `banditshell-snippet-probe-${Date.now()}`,
            stage: "arm",
            wait: "",
            tries: 0,
            selected: false,
            hit: null
        };
        Clipboard.mute(true);
        watchdog.restart();
        root.guard(() => {
            root.run.wait = "offer";
            Clipboard.offer(["wl-copy"], root.run.token, false);
        });
        return "expanding";
    }

    function guard(step: var): void {
        try {
            step();
        } catch (e) {
            console.warn("SnippetExpander:", e);
            root.abort("Something went wrong, so nothing was typed.");
        }
    }

    function keys(argv: var): void {
        Keystrokes.send([argv[0], ...root.letGo, ...argv.slice(1)]);
    }

    function advance(from: string): void {
        if (!root.run || root.run.wait !== from)
            return;
        root.run.wait = "";
        settle.restart();
    }

    function next(): void {
        const job = root.run;
        if (!job)
            return;
        root.guard(() => {
            if (job.stage === "arm") {
                job.stage = "select";
                const select = ["wtype", "-M", "shift"];
                for (let i = 0; i < job.span; i++)
                    select.push("-k", "Left");
                select.push("-m", "shift");
                job.wait = "keys";
                root.keys(select);
            } else if (job.stage === "select") {
                job.stage = "copy";
                job.wait = "keys";
                root.keys(["wtype", "-M", "ctrl", "-k", "c", "-m", "ctrl"]);
            } else if (job.stage === "copy") {
                job.stage = "read";
                root.read();
            } else if (job.stage === "restore") {
                job.stage = "act";
                Clipboard.mute(false);
                root.act();
            }
        });
    }

    function read(): void {
        root.run.tries += 1;
        reader.running = true;
    }

    function heard(text: string): void {
        const job = root.run;
        if (!job || job.stage !== "read")
            return;
        const fresh = text !== "" && text !== job.token;
        if (!fresh && job.tries < root.reads) {
            settle.restart();
            return;
        }
        job.selected = fresh;
        job.hit = fresh ? Snippets.keywordBefore(text) : null;
        job.stage = "restore";
        root.guard(() => {
            job.wait = "offer";
            if (job.before)
                Clipboard.copy(job.before);
            else
                Clipboard.offer(["wl-copy", "--clear"], "", false);
        });
    }

    function act(): void {
        const job = root.run;
        root.run = null;
        watchdog.stop();
        if (job.selected)
            root.keys(["wtype", "-k", "Right"]);
        if (!job.hit) {
            root.fail(job.selected ? "No snippet keyword sits before the cursor." : "Nothing could be read before the cursor.");
            return;
        }
        const erase = ["wtype"];
        for (let i = 0; i < job.hit.length; i++)
            erase.push("-k", "BackSpace");
        root.keys(erase);
        const done = Snippets.expand(job.hit.snippet);
        Typist.type(done.text, done.back, job.address);
    }

    function abort(why: string): void {
        const job = root.run;
        root.run = null;
        watchdog.stop();
        settle.stop();
        if (job) {
            if (job.before)
                Clipboard.copy(job.before);
            else
                Clipboard.offer(["wl-copy", "--clear"], "", false);
        }
        unmute.restart();
        root.fail(why);
    }

    function fail(why: string): string {
        if (Typist.notifies)
            Quickshell.execDetached(["notify-send", "-a", "banditshell", "-i", "short_text", "Snippet not expanded", why]);
        return why;
    }

    Connections {
        target: Keystrokes

        function onDrained(): void {
            root.advance("keys");
        }
    }

    Connections {
        target: Clipboard

        function onOffersSettled(): void {
            root.advance("offer");
        }
    }

    Timer {
        id: settle

        interval: root.run?.stage === "restore" ? root.restoreWait : root.run?.stage === "read" ? root.readWait : root.run?.stage === "arm" ? root.armWait : root.keysWait
        onTriggered: {
            if (root.run?.stage === "read")
                root.guard(() => root.read());
            else
                root.next();
        }
    }

    Timer {
        id: unmute

        interval: root.restoreWait
        onTriggered: Clipboard.mute(false)
    }

    Timer {
        id: watchdog

        interval: root.limit
        onTriggered: root.abort("It took too long, so nothing was typed.")
    }

    Process {
        id: reader

        command: ["sh", "-c", "wl-paste -n -t text 2>/dev/null; true"]

        stdout: StdioCollector {
            onStreamFinished: root.heard(text)
        }
    }
}
