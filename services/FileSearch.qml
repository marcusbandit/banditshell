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

    readonly property var appNoise: ["Cache", "Code Cache", "GPUCache", "CacheStorage", "Service Worker", "IndexedDB", "blob_storage", "Local Storage", "Session Storage", "Crashpad", "DawnCache", "DawnGraphiteCache", "DawnWebGPUCache", "GrShaderCache", "ShaderCache", "WebStorage", "Partitions", "CachedData", "workspaceStorage", "History", "logs"]

    readonly property string configDir: `${System.home}/.config`
    readonly property bool configSearched: root.hidden === ".config" || root.hidden === "all"

    readonly property int findLimit: 600

    function excluding(flag: string, names: var, prefix: string): var {
        return names.reduce((out, n) => out.concat([flag, prefix + n]), []);
    }

    function commands(text: string): var {
        const base = ["nice", "-n", "10", "fd", "--fixed-strings", "--ignore-case", "--type", "f", "--type", "d", "--max-results", String(root.findLimit), ...(text.indexOf("/") >= 0 ? ["--full-path"] : []), ...root.excluding("--exclude", root.noise, "")];
        const out = [base.concat(root.hidden === "all" ? ["--hidden", "--exclude", "/.config"] : [], ["--", text, System.home])];
        if (root.configSearched)
            out.push(base.concat(["--no-ignore-vcs"], root.excluding("--exclude", root.appNoise, ""), ["--", text, root.configDir]));
        return out;
    }

    property bool fdFound: false
    property bool rgFound: false

    readonly property bool contents: Config.values.launcher.contents

    readonly property int hitLimit: 8

    function grepCommands(text: string, within: var): var {
        const base = ["nice", "-n", "19", "rg", "--fixed-strings", "--smart-case", "--max-count", "1", "--line-number", "--with-filename", "--no-heading", "--color", "never", "--max-filesize", "1M", "--max-columns", "240", "--max-columns-preview"];
        if (within)
            return [base.concat(["--", text], within)];
        const walk = base.concat(["--threads", "2"], root.excluding("--glob", root.noise, "!"));
        const out = [walk.concat(["--", text, System.home])];
        if (root.configSearched)
            out.push(walk.concat(["--no-ignore-vcs"], root.excluding("--glob", root.appNoise, "!"), ["--", text, root.configDir]));
        return out;
    }

    property string grepped: ""
    property var grepFiles: []
    property bool grepAll: false
    property var grepWithin: null

    property string grepAsked: ""
    property string grepAnswered: ""
    property var hits: []

    property int grepGeneration: 0
    property var grepping: []
    property var grepFound: []
    property int grepLeft: 0

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
        root.grepping.forEach(run => run.running = false);
    }

    function hit(generation: int, query: string, line: string): void {
        if (generation !== root.grepGeneration || root.grepFound.length >= root.hitLimit || root.grepFound.indexOf(line) >= 0)
            return;
        root.grepFound = root.grepFound.concat([line]);
        root.hits = root.grepFound;
        root.grepAnswered = query;
        if (root.grepFound.length >= root.hitLimit)
            root.grepping.forEach(run => run.running = false);
    }

    function grepEnded(generation: int, query: string): void {
        if (generation !== root.grepGeneration)
            return;
        root.grepLeft -= 1;
        if (root.grepLeft > 0)
            return;
        if (!root.grepFound.length) {
            root.hits = [];
            root.grepAnswered = query;
        }
        const all = root.grepFound.length < root.hitLimit;
        root.grepAll = all;
        root.grepped = all ? query : "";
        root.grepFiles = all ? root.grepFound.map(hit => Narrowing.pathOf(hit)).filter(Boolean) : [];
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
    property var finding: []
    property var gathered: []
    property int findLeft: 0
    property bool findCapped: false

    function gather(generation: int, query: string, lines: var): void {
        if (generation !== root.findGeneration)
            return;
        const seen = {};
        const merged = root.gathered.concat(lines).filter(line => seen[line] ? false : (seen[line] = true));
        root.gathered = merged;
        root.findCapped = root.findCapped || lines.length >= root.findLimit;
        root.findLeft -= 1;
        root.lines = merged;
        root.answered = query;
        if (root.findLeft > 0)
            return;
        root.found = query;
        root.foundLines = merged;
        root.foundAll = !root.findCapped;
    }

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
            const commands = root.grepCommands(root.grepAsked, root.grepWithin);
            root.grepFound = [];
            root.grepLeft = commands.length;
            root.grepping = root.grepping.concat(commands.map(command => grepper.createObject(root, {
                    command: command,
                    generation: root.grepGeneration,
                    query: root.grepAsked,
                    running: true
                })));
        }
    }

    Component {
        id: grepper

        Process {
            id: run

            property int generation: 0
            property string query: ""

            stdout: SplitParser {
                onRead: line => root.hit(run.generation, run.query, line)
            }

            onExited: root.grepEnded(run.generation, run.query)

            onRunningChanged: if (!run.running) {
                root.grepping = root.grepping.filter(other => other !== run);
                run.destroy();
            }
        }
    }

    Timer {
        id: settle

        interval: 90

        onTriggered: {
            root.findGeneration += 1;
            root.finding.forEach(run => run.running = false);
            const commands = root.commands(root.asked);
            root.gathered = [];
            root.findCapped = false;
            root.findLeft = commands.length;
            root.finding = root.finding.concat(commands.map(command => finder.createObject(root, {
                    command: command,
                    generation: root.findGeneration,
                    query: root.asked,
                    running: true
                })));
        }
    }

    Component {
        id: finder

        Process {
            id: run

            property int generation: 0
            property string query: ""

            stdout: StdioCollector {
                onStreamFinished: root.gather(run.generation, run.query, text.split("\n").filter(Boolean))
            }

            onRunningChanged: if (!run.running) {
                root.finding = root.finding.filter(other => other !== run);
                run.destroy();
            }
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
