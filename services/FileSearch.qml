pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "narrowing.js" as Narrowing

Singleton {
    id: root

    readonly property int least: 3

    readonly property string hidden: Config.values.launcher.hiddenFiles

    readonly property var noise: ["node_modules", ".cache", ".git", ".npm", ".cargo", ".rustup", ".gradle", ".m2", ".var", ".steam", ".local/share/Steam", ".local/share/Trash", ".mozilla", ".pki", ".nv"]

    function command(text: string): var {
        const all = root.hidden === "all";
        return ["nice", "-n", "10", "fd", "--fixed-strings", "--ignore-case", "--type", "f", "--type", "d", "--max-results", "600", ...(all ? ["--hidden"] : []), ...root.noise.reduce((out, n) => out.concat(["--exclude", n]), []), "--", text, System.home, ...(root.hidden === ".config" ? [`${System.home}/.config`] : [])];
    }

    property bool fdFound: false
    property bool rgFound: false

    readonly property bool contents: Config.values.launcher.contents

    readonly property int hitLimit: 8

    function grepCommand(text: string, within: var): var {
        return ["nice", "-n", "19", "rg", "--fixed-strings", "--smart-case", "--max-count", "1", "--line-number", "--with-filename", "--no-heading", "--color", "never", "--max-filesize", "1M", "--max-columns", "240", "--max-columns-preview", ...(within ? [] : ["--threads", "2", ...root.noise.reduce((out, n) => out.concat(["--glob", `!${n}`]), [])]), "--", text, ...(within ?? [System.home])];
    }

    property string grepped: ""
    property var grepFiles: []
    property bool grepAll: false
    property var grepWithin: null

    property string grepAsked: ""
    property string grepAnswered: ""
    property var hits: []

    property int grepGeneration: 0
    property var latestGrep: null

    function grep(text: string): void {
        const t = text.trim();
        root.grepAsked = t;
        if (!root.rgFound || !root.contents || t.length < root.least) {
            grepSettle.stop();
            root.stopGrep();
            root.hits = [];
            root.grepAnswered = t;
            return;
        }
        const narrower = root.grepAll && Narrowing.grepNarrows(root.grepped, t);
        if (narrower && !root.grepFiles.length) {
            grepSettle.stop();
            root.stopGrep();
            root.hits = [];
            root.grepAnswered = t;
            return;
        }
        root.grepWithin = narrower ? root.grepFiles : null;
        grepSettle.interval = narrower ? 60 : 450;
        grepSettle.restart();
    }

    function stopGrep(): void {
        root.grepGeneration += 1;
        if (root.latestGrep)
            root.latestGrep.running = false;
        root.latestGrep = null;
    }

    property string asked: ""
    property string answered: ""
    property var lines: []

    property string found: ""
    property var foundLines: []
    property bool foundAll: false

    onHiddenChanged: root.found = ""

    property string listedDir: ""
    property var entries: []

    property int findGeneration: 0
    property var latestFind: null

    property int listGeneration: 0
    property var latestList: null

    function find(text: string): void {
        const t = text.trim();
        root.asked = t;
        if (!root.fdFound || t.length < root.least) {
            settle.stop();
            root.lines = [];
            root.answered = t;
            return;
        }
        if (root.foundAll && Narrowing.narrows(root.found, t)) {
            settle.stop();
            root.findGeneration += 1;
            root.lines = Narrowing.keepNamed(root.foundLines, t);
            root.answered = t;
            return;
        }
        settle.restart();
    }

    function list(dir: string): void {
        if (!dir || dir === root.listedDir)
            return;
        root.listedDir = dir;
        root.entries = [];
        root.listGeneration += 1;
        if (root.latestList)
            root.latestList.running = false;
        root.latestList = lister.createObject(root, {
            command: [Files.helper("bs-ls"), dir.length > 1 ? dir.replace(/\/$/, "") : dir],
            generation: root.listGeneration,
            query: dir,
            running: true
        });
    }

    function forget(): void {
        root.listedDir = "";
        root.entries = [];
        root.found = "";
        root.grepped = "";
        root.grepAll = false;
        grepSettle.stop();
        root.stopGrep();
        root.hits = [];
        root.grepAnswered = "";
    }

    Timer {
        id: grepSettle

        interval: 250

        onTriggered: {
            root.stopGrep();
            root.latestGrep = grepper.createObject(root, {
                command: root.grepCommand(root.grepAsked, root.grepWithin),
                generation: root.grepGeneration,
                query: root.grepAsked,
                running: true
            });
        }
    }

    Component {
        id: grepper

        Process {
            id: run

            property int generation: 0
            property string query: ""
            property var found: []

            stdout: SplitParser {
                onRead: line => {
                    if (run.generation !== root.grepGeneration || run.found.length >= root.hitLimit)
                        return;
                    run.found.push(line);
                    root.hits = run.found.slice();
                    root.grepAnswered = run.query;
                    if (run.found.length >= root.hitLimit)
                        run.running = false;
                }
            }

            onExited: {
                if (run.generation !== root.grepGeneration)
                    return;
                if (!run.found.length) {
                    root.hits = [];
                    root.grepAnswered = run.query;
                }
                const all = run.found.length < root.hitLimit;
                root.grepAll = all;
                root.grepped = all ? run.query : "";
                root.grepFiles = all ? run.found.map(hit => Narrowing.pathOf(hit)).filter(Boolean) : [];
            }

            onRunningChanged: if (!run.running)
                run.destroy()
        }
    }

    Timer {
        id: settle

        interval: 90

        onTriggered: {
            root.findGeneration += 1;
            if (root.latestFind)
                root.latestFind.running = false;
            root.latestFind = finder.createObject(root, {
                command: root.command(root.asked),
                generation: root.findGeneration,
                query: root.asked,
                running: true
            });
        }
    }

    Component {
        id: finder

        Process {
            id: run

            property int generation: 0
            property string query: ""

            stdout: StdioCollector {
                onStreamFinished: {
                    if (run.generation !== root.findGeneration)
                        return;
                    const lines = text.split("\n").filter(Boolean);
                    root.lines = lines;
                    root.answered = run.query;
                    root.found = run.query;
                    root.foundLines = lines;
                    root.foundAll = lines.length < 600;
                }
            }

            onRunningChanged: if (!run.running)
                run.destroy()
        }
    }

    Component {
        id: lister

        Process {
            id: run

            property int generation: 0
            property string query: ""

            stdout: StdioCollector {
                onStreamFinished: {
                    if (run.generation !== root.listGeneration || run.query !== root.listedDir)
                        return;
                    try {
                        const answer = JSON.parse(text);
                        root.entries = answer.ok ? answer.entries : [];
                    } catch (e) {
                        root.entries = [];
                    }
                }
            }

            onRunningChanged: if (!run.running)
                run.destroy()
        }
    }

    Process {
        command: ["sh", "-c", "command -v fd"]
        running: true
        onExited: code => root.fdFound = code === 0
    }

    Process {
        command: ["sh", "-c", "command -v rg"]
        running: true
        onExited: code => root.rgFound = code === 0
    }
}
