pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "dictionary.js" as Words

Singleton {
    id: root

    readonly property bool onlineEnabled: (Config.values.launcher.online ?? {}).define !== false

    readonly property string database: `${Config.cacheDir}/dictionary/wordnet-2025-1.sqlite`

    property string state: "idle"
    property real failedAt: 0
    readonly property real retryAfter: 60 * 1000
    readonly property bool building: root.state === "building"
    readonly property bool ready: root.state === "ready"

    property var answers: ({})
    property var order: []
    readonly property int keep: 300

    property bool missing: false
    property bool mayBuild: false

    property int serial: 0
    property var asked: ({})
    property var waiting: []

    function keyOf(word: string): string {
        return String(word ?? "").trim().toLowerCase();
    }

    function answerFor(word: string): var {
        return root.answers[root.keyOf(word)];
    }

    function want(word: string, explicit: bool): void {
        const key = root.keyOf(word);
        if (!key || root.answers[key] !== undefined || root.asked[key] !== undefined)
            return;
        if (root.ready) {
            root.send(key);
            return;
        }
        if (!explicit && root.missing)
            return;
        if (root.waiting.indexOf(key) < 0)
            root.waiting = root.waiting.slice(-8).concat([key]);
        root.mayBuild = root.mayBuild || explicit;
        root.start();
    }

    function start(): void {
        if (helper.running || (root.state === "failed" && Date.now() - root.failedAt < root.retryAfter))
            return;
        root.state = "starting";
        helper.command = ["python3", "-I", Quickshell.shellPath("scripts/dictionary.py"), root.mayBuild ? "serve" : "serve-built", root.database];
        helper.running = true;
    }

    function send(key: string): void {
        root.serial += 1;
        const asked = Object.assign({}, root.asked);
        asked[key] = root.serial;
        root.asked = asked;
        helper.write(JSON.stringify({
            id: root.serial,
            word: key,
            complete: true
        }) + "\n");
        idle.restart();
    }

    function store(key: string, value: var): void {
        const answers = Object.assign({}, root.answers);
        answers[key] = value;
        const order = root.order.filter(k => k !== key).concat([key]);
        while (order.length > root.keep)
            delete answers[order.shift()];
        root.answers = answers;
        root.order = order;
        const asked = Object.assign({}, root.asked);
        delete asked[key];
        root.asked = asked;
    }

    function take(line: string): void {
        let said;
        try {
            said = JSON.parse(line);
        } catch (e) {
            return;
        }
        if (said.state) {
            root.state = said.state;
            if (said.state === "failed") {
                root.failedAt = Date.now();
                console.warn(`Dictionary: the offline dictionary could not be built: ${said.error ?? ""}`);
            }
            if (said.state === "ready") {
                root.missing = false;
                const waiting = root.waiting;
                root.waiting = [];
                waiting.forEach(key => root.send(key));
            }
            return;
        }
        root.store(root.keyOf(said.word), {
            entry: said.entry ?? null,
            completions: said.completions ?? []
        });
    }

    Process {
        id: helper

        stdinEnabled: true

        stdout: SplitParser {
            onRead: line => root.take(line)
        }

        stderr: SplitParser {
            onRead: line => console.warn(`Dictionary: ${line}`)
        }

        onExited: code => {
            root.asked = ({});
            if (code === 3) {
                root.state = "idle";
                root.missing = true;
                if (root.mayBuild)
                    root.start();
                return;
            }
            if (root.state === "stopping" || code === 0) {
                root.state = "idle";
                return;
            }
            if (root.state !== "failed")
                console.warn(`Dictionary: the offline dictionary stopped with code ${code}`);
            root.state = "failed";
            root.failedAt = Date.now();
        }
    }

    Timer {
        id: idle

        interval: 10 * 60 * 1000
        onTriggered: {
            root.state = "stopping";
            helper.running = false;
        }
    }

    property Lookup online: Lookup {
        delay: 300
        keep: 200
        file: `${Config.cacheDir}/online/definitions.json`
        commandFor: word => ["curl", "-fsS", "--max-time", "6", "-A", "banditshell launcher", `https://en.wiktionary.org/api/rest_v1/page/definition/${encodeURIComponent(word)}`]
        read: (text, word) => Words.readAnswer(text, word)
    }
}
