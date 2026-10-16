const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");

function lib(file, names) {
    const src = fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "");
    return new Function(`${src}\nreturn { ${names.join(", ")} };`)();
}

const Scripts = lib("services/script-commands.js", ["parseScript", "readScan", "argumentsFrom", "askFor", "missing", "commandFor", "outputLines", "lastLine", "runKey", "titleFromFile", "EXAMPLE", "listAsk"]);
const Projects = lib("services/projects.js", ["listFrom", "readScan", "rank", "ago", "editorFor", "terminalLine", "shellLine", "projectAsk", "parentWithin", "scanCommand", "ambientScore", "quote"]);
const Notes = lib("services/notes.js", ["withoutSkipped", "vaultsFrom", "defaultVault", "readIndex", "search", "openUri", "newUri", "fileNameFor", "notesAsk", "indexCommand", "ambientScore"]);
const Monitor = lib("services/system-monitor.js", ["monitorAsk", "readSample", "topProcesses", "readDisks", "bytesText", "uptimeText", "cpuText"]);
const Pomodoro = lib("services/pomodoro.js", ["pomodoroAsk", "nextRound", "roundLabel", "notice", "readState"]);
const Lorem = lib("services/lorem.js", ["loremAsk", "generate", "describe", "preview"]);
const Picks = lib("services/colour-picks.js", ["colourAsk", "readPicked", "remember", "forget", "readHistory"]);
const Ranking = lib("services/ranking.js", ["place", "EXACT", "PREFIX", "WORD", "ANYWHERE"]);
const os = require("node:os");
const { execFileSync } = require("node:child_process");

function scratch() {
    return fs.mkdtempSync(path.join(os.tmpdir(), "power-tools-"));
}

function bare(tools) {
    const bin = fs.mkdtempSync(path.join(os.tmpdir(), "power-bin-"));
    for (const tool of tools)
        fs.symlinkSync(execFileSync("sh", ["-c", `command -v ${tool}`]).toString().trim(), path.join(bin, tool));
    return bin;
}

const SAY = `#!/usr/bin/env python3
# @raycast.schemaVersion 1
# @raycast.title Say
# @raycast.mode fullOutput
# @raycast.icon 💬
# @raycast.packageName Speech
# @raycast.argument1 { "type": "text", "placeholder": "words" }
print("hi")
`;

test.describe("script commands", () => {
    test.it("reads Raycast headers", () => {
        const s = Scripts.parseScript("/s/say.py", SAY, true);
        assert.strictEqual(s.title, "Say");
        assert.strictEqual(s.mode, "fullOutput");
        assert.strictEqual(s.icon, "💬");
        assert.strictEqual(s.packageName, "Speech");
        assert.strictEqual(s.arguments.length, 1);
        assert.strictEqual(s.arguments[0].placeholder, "words");
        assert.deepStrictEqual(s.interpreter, ["/usr/bin/env", "python3"]);
    });

    test.it("falls back to the file name and to compact mode", () => {
        const s = Scripts.parseScript("/s/backup-photos.sh", "#!/bin/sh\necho done\n", true);
        assert.strictEqual(s.title, "Backup photos");
        assert.strictEqual(s.mode, "compact");
        assert.strictEqual(Scripts.parseScript("/s/notes", "just words\n", false), null);
    });

    test.it("resolves file icons next to the script", () => {
        const s = Scripts.parseScript("/s/a.sh", "#!/bin/sh\n# @raycast.icon images/logo.png\n", true);
        assert.strictEqual(s.icon, "");
        assert.strictEqual(s.iconFile, "/s/images/logo.png");
    });

    test.it("splits a scan into scripts and skips documents", () => {
        const scan = "found\n\x1e1\t/s/say.py\n" + SAY + "\n\x1e0\t/s/README.md\n# readme\n\x1e0\t/s/plain.sh\n#!/bin/sh\necho\n";
        const all = Scripts.readScan(scan);
        assert.deepStrictEqual(all.map(s => s.file), ["plain.sh", "say.py"]);
        assert.strictEqual(all[0].executable, false);
    });

    test.it("takes arguments typed after the title", () => {
        const s = Scripts.parseScript("/s/say.py", SAY, true);
        assert.deepStrictEqual(Scripts.askFor(s, "say hello world").values, ["hello world"]);
        assert.deepStrictEqual(Scripts.askFor(s, "Say").values, []);
        assert.strictEqual(Scripts.askFor(s, "sayhello"), null);
        assert.deepStrictEqual(Scripts.missing(s, []), ["words"]);
        assert.deepStrictEqual(Scripts.argumentsFrom('"a b" c d', 2), ["a b", "c d"]);
        assert.deepStrictEqual(Scripts.argumentsFrom("one two three", 3), ["one", "two", "three"]);
        assert.deepStrictEqual(Scripts.argumentsFrom("one two three four", 3), ["one", "two", "three four"]);
    });

    test.it("runs through the shebang when the file is not executable", () => {
        const s = Scripts.parseScript("/s/say.py", SAY, false);
        assert.deepStrictEqual(Scripts.commandFor(s, ["hi there"]), ["/usr/bin/env", "python3", "/s/say.py", "hi there"]);
        const plain = Scripts.parseScript("/s/run", "# @raycast.title Run\n", false);
        assert.deepStrictEqual(Scripts.commandFor(plain, []), ["sh", "/s/run"]);
        const encoded = Scripts.parseScript("/s/e.sh", '#!/bin/sh\n# @raycast.argument1 { "type": "text", "placeholder": "q", "percentEncoded": true }\n', true);
        assert.deepStrictEqual(Scripts.commandFor(encoded, ["a b&c"]), ["/s/e.sh", "a%20b%26c"]);
    });

    test.it("cleans output and keeps the last line", () => {
        assert.deepStrictEqual(Scripts.outputLines("\x1b[32mone\x1b[0m\n\n two  \n"), ["one", " two"]);
        assert.strictEqual(Scripts.lastLine("a\nb\n\n"), "b");
    });

    test.it("lists every script when asked for scripts", () => {
        assert.strictEqual(Scripts.listAsk("scripts"), true);
        assert.strictEqual(Scripts.listAsk("Script commands"), true);
        assert.strictEqual(Scripts.listAsk("scripted"), false);
    });

    test.it("ships an example that reads as a Raycast script", () => {
        const s = Scripts.parseScript("/s/hello.sh", Scripts.EXAMPLE, true);
        assert.strictEqual(s.title, "Hello");
        assert.strictEqual(s.arguments[0].optional, true);
        assert.deepStrictEqual(Scripts.missing(s, []), []);
    });
});

test.describe("projects", () => {
    test.it("expands folder lists", () => {
        assert.deepStrictEqual(Projects.listFrom("~/Projects, ~/src/ ,~/Projects", "/home/a"), ["/home/a/Projects", "/home/a/src"]);
    });

    test.it("reads the scan and ranks by name, then by what was touched last", () => {
        const scan = "1700000000\tHEAD -> main, origin/main\t/p/alpha\n0\t\t/p/beta\n1600000000\tHEAD -> dev\t/p/group/alphabet\n";
        const all = Projects.readScan(scan);
        assert.strictEqual(all.length, 3);
        assert.strictEqual(all[0].branch, "main");
        assert.strictEqual(all[1].committed, 0);
        const recent = Projects.rank(all, {
            "/p/beta": 1800000000000
        }, "", Ranking.place);
        assert.deepStrictEqual(recent.map(r => r.project.name), ["beta", "alpha", "alphabet"]);
        const named = Projects.rank(all, {}, "alpha", Ranking.place);
        assert.deepStrictEqual(named.map(r => r.project.name), ["alpha", "alphabet"]);
        assert.strictEqual(Projects.parentWithin(["/p"], "/p/group/alphabet"), "group");
        assert.strictEqual(Projects.parentWithin(["/p"], "/p/alpha"), "");
    });

    test.it("says how long ago", () => {
        const now = 10 * 86400000;
        assert.strictEqual(Projects.ago(now - 30000, now), "just now");
        assert.strictEqual(Projects.ago(now - 5 * 60000, now), "5 min ago");
        assert.strictEqual(Projects.ago(now - 86400000, now), "yesterday");
        assert.strictEqual(Projects.ago(now - 3 * 86400000, now), "3 days ago");
        assert.strictEqual(Projects.ago(0, now), "");
    });

    test.it("picks an editor from VISUAL, EDITOR, then what is installed", () => {
        assert.deepStrictEqual(Projects.editorFor("", "nvim", []), {
            command: ["nvim"],
            terminal: true,
            name: "nvim"
        });
        assert.strictEqual(Projects.editorFor("code --wait", "nvim", []).terminal, false);
        assert.strictEqual(Projects.editorFor("", "", ["nvim", "zeditor"]).name, "zeditor");
        assert.strictEqual(Projects.editorFor("", "", ["nano"]).terminal, true);
        assert.strictEqual(Projects.editorFor("", "", []), null);
        assert.strictEqual(Projects.terminalLine("/p/it's", ["nvim"]), "cd '/p/it'\\''s' && exec 'nvim' .");
        assert.strictEqual(Projects.terminalLine("/p", ["nvim"], "/p/a b.sh"), "cd '/p' && exec 'nvim' '/p/a b.sh'");
    });

    test.it("knows when the query is about projects", () => {
        assert.deepStrictEqual(Projects.projectAsk("projects"), {
            text: ""
        });
        assert.deepStrictEqual(Projects.projectAsk("repo fleet"), {
            text: "fleet"
        });
        assert.strictEqual(Projects.projectAsk("progress"), null);
    });

    test.it("builds a scan that skips only safe names", () => {
        const command = Projects.scanCommand(["/p"], 2, "_archive, bad name, $(rm)");
        assert.strictEqual(command[command.length - 2], "_archive");
        assert.strictEqual(command[command.length - 3], "2");
    });
});

test.describe("notes", () => {
    const registry = JSON.stringify({
        vaults: {
            a: {
                path: "/h/Obsidian/Mind",
                ts: 5
            },
            b: {
                path: "/h/Work",
                ts: 9,
                open: true
            }
        }
    });

    test.it("merges registered and found vaults, open one first", () => {
        const vaults = Notes.vaultsFrom([registry, ""], "/h/Obsidian/Mind/.obsidian\n/h/Obsidian/Loose/.obsidian\n");
        assert.deepStrictEqual(vaults.map(v => v.name), ["Work", "Mind", "Loose"]);
        assert.strictEqual(vaults.find(v => v.name === "Loose").registered, false);
        assert.strictEqual(Notes.defaultVault(vaults, "").name, "Work");
        assert.strictEqual(Notes.defaultVault(vaults, "Mind").name, "Mind");
        assert.strictEqual(Notes.defaultVault(vaults, "/h/Obsidian/Loose").name, "Loose");
    });

    test.it("indexes notes by vault and finds them by name", () => {
        const vaults = Notes.vaultsFrom([registry], "");
        const notes = Notes.readIndex("100\t/h/Work/Plans/Big plan.md\n200\t/h/Obsidian/Mind/plan b.md\n300\t/h/Elsewhere/x.md\n", vaults);
        assert.strictEqual(notes.length, 2);
        assert.strictEqual(notes[0].relative, "Plans/Big plan");
        assert.strictEqual(notes[0].vaultName, "Work");
        const hits = Notes.search(notes, "plan", Ranking.place, 5);
        assert.deepStrictEqual(hits.map(h => h.note.name), ["plan b", "Big plan"]);
    });

    test.it("writes Obsidian links and safe names", () => {
        assert.strictEqual(Notes.openUri("My vault", "Plans/Big plan"), "obsidian://open?vault=My%20vault&file=Plans%2FBig%20plan");
        assert.strictEqual(Notes.newUri("Work", "a&b"), "obsidian://new?vault=Work&name=a%26b");
        assert.strictEqual(Notes.fileNameFor("todo: buy #milk / eggs"), "todo buy milk eggs");
    });

    test.it("tells creating from searching", () => {
        assert.deepStrictEqual(Notes.notesAsk("note buy milk"), {
            create: "buy milk",
            text: "buy milk"
        });
        assert.deepStrictEqual(Notes.notesAsk("notes plan"), {
            create: "",
            text: "plan"
        });
        assert.strictEqual(Notes.notesAsk("note"), null);
        assert.strictEqual(Notes.notesAsk("notepad"), null);
    });
});

test.describe("system monitor", () => {
    const sample = (uptime, ticks) => `100\n4096\n${uptime}\n---\n10\n---\n10 (fire fox) S 1 1 1 0 -1 0 0 0 0 0 ${ticks} 0 0 0 20 0 1 0 5 100 2560 0\n20 (kworker/0:1) I 2 0 0 0 -1 0 0 0 0 0 ${ticks * 3} 0 0 0 20 0 1 0 5 0 0 0\n30 (sshd) S 1 1 1 0 -1 0 0 0 0 0 10 0 0 0 20 0 1 0 5 100 512 0`;

    test.it("knows its words", () => {
        assert.strictEqual(Monitor.monitorAsk("CPU"), "cpu");
        assert.strictEqual(Monitor.monitorAsk("disk  space"), "disk");
        assert.strictEqual(Monitor.monitorAsk("top"), "top");
        assert.strictEqual(Monitor.monitorAsk("system"), "system");
        assert.strictEqual(Monitor.monitorAsk("systemd"), "");
    });

    test.it("works out CPU per process from two samples", () => {
        const before = Monitor.readSample(sample(100, 100));
        const after = Monitor.readSample(sample(102, 200));
        assert.strictEqual(after.processes["10"].name, "fire fox");
        const top = Monitor.topProcesses(before, after, 5);
        assert.deepStrictEqual(top.map(p => p.name), ["fire fox", "sshd"]);
        assert.strictEqual(top[0].cpu, 50);
        assert.strictEqual(top[0].memory, 2560 * 4096);
        assert.strictEqual(top[0].own, true);
        assert.strictEqual(top[1].own, false);
    });

    test.it("reads disks and leaves out pseudo filesystems and repeats", () => {
        const df = "Filesystem Type 1024-blocks Used Available Capacity Mounted on\n/dev/nvme0n1p2 btrfs 1000 400 600 40% /\n/dev/nvme0n1p2 btrfs 1000 400 600 40% /home\ntmpfs tmpfs 100 1 99 1% /tmp\n/dev/sdb1 vfat 2000 500 1500 25% /run/media/a/My Stick\n";
        const disks = Monitor.readDisks(df);
        assert.deepStrictEqual(disks.map(d => d.mount), ["/", "/run/media/a/My Stick"]);
        assert.strictEqual(disks[0].fraction, 0.4);
        assert.strictEqual(disks[0].size, 1024000);
    });

    test.it("says sizes and spans plainly", () => {
        assert.strictEqual(Monitor.bytesText(512 * 1024 * 1024), "512 MB");
        assert.strictEqual(Monitor.bytesText(9.84 * 1024 ** 3), "9.8 GB");
        assert.strictEqual(Monitor.uptimeText(3 * 86400 + 4 * 3600), "3 days 4 h");
        assert.strictEqual(Monitor.uptimeText(5 * 3600 + 12 * 60), "5 h 12 min");
        assert.strictEqual(Monitor.cpuText(4.26), "4.3%");
        assert.strictEqual(Monitor.cpuText(42.6), "43%");
    });
});

test.describe("pomodoro", () => {
    const settings = {
        focus: 25,
        breakMinutes: 5,
        longBreak: 15,
        rounds: 4
    };

    test.it("reads what is typed", () => {
        assert.deepStrictEqual(Pomodoro.pomodoroAsk("pomodoro"), {
            phase: "pomodoro",
            minutes: 0,
            breakMinutes: 0,
            long: false
        });
        assert.strictEqual(Pomodoro.pomodoroAsk("pomodoro 50 10").breakMinutes, 10);
        assert.strictEqual(Pomodoro.pomodoroAsk("focus 25").minutes, 25);
        assert.strictEqual(Pomodoro.pomodoroAsk("focus for 45 min").minutes, 45);
        assert.strictEqual(Pomodoro.pomodoroAsk("break 5").phase, "break");
        assert.strictEqual(Pomodoro.pomodoroAsk("take a long break").long, true);
        assert.strictEqual(Pomodoro.pomodoroAsk("focus left"), null);
        assert.strictEqual(Pomodoro.pomodoroAsk("focus workspace 3"), null);
        assert.strictEqual(Pomodoro.pomodoroAsk("focus 0"), null);
    });

    test.it("goes focus, break, and a long break every fourth round", () => {
        assert.deepStrictEqual(Pomodoro.nextRound({
            phase: "focus",
            round: 1
        }, settings), {
            phase: "break",
            round: 1,
            minutes: 5
        });
        assert.strictEqual(Pomodoro.nextRound({
            phase: "focus",
            round: 4
        }, settings).phase, "long");
        assert.deepStrictEqual(Pomodoro.nextRound({
            phase: "break",
            round: 1,
            focusMinutes: 50
        }, settings), {
            phase: "focus",
            round: 2,
            minutes: 50
        });
        assert.strictEqual(Pomodoro.nextRound({
            phase: "long",
            round: 4
        }, settings).round, 1);
        assert.strictEqual(Pomodoro.nextRound({
            phase: "break",
            round: 0
        }, settings).round, 1);
    });

    test.it("labels rounds and says what comes next", () => {
        assert.strictEqual(Pomodoro.roundLabel({
            phase: "focus",
            round: 2
        }, settings), "Focus round 2");
        const said = Pomodoro.notice({
            phase: "focus",
            round: 2
        }, {
            phase: "break",
            minutes: 5,
            round: 2
        });
        assert.strictEqual(said.summary, "Focus round 2 done");
        assert.strictEqual(said.body, "Break for 5 minutes");
        assert.strictEqual(Pomodoro.readState("{}"), null);
        assert.strictEqual(Pomodoro.readState('{"timer":"t1","phase":"focus","round":2}').round, 2);
    });
});

test.describe("lorem ipsum", () => {
    test.it("reads counts and units", () => {
        assert.deepStrictEqual(Lorem.loremAsk("lorem 3"), {
            count: 3,
            unit: "paragraphs"
        });
        assert.deepStrictEqual(Lorem.loremAsk("lorem 20 words"), {
            count: 20,
            unit: "words"
        });
        assert.deepStrictEqual(Lorem.loremAsk("lorem ipsum"), {
            count: 1,
            unit: "paragraphs"
        });
        assert.strictEqual(Lorem.loremAsk("lorem 5 sentences").unit, "sentences");
        assert.strictEqual(Lorem.loremAsk("loremx"), null);
        assert.strictEqual(Lorem.loremAsk("lorem 99999 words"), null);
    });

    test.it("makes exactly what was asked, the same way each time", () => {
        const words = Lorem.generate(20, "words");
        assert.strictEqual(words.split(" ").length, 20);
        assert.ok(words.indexOf("Lorem ipsum dolor sit amet") === 0);
        assert.strictEqual(Lorem.generate(3, "paragraphs").split("\n\n").length, 3);
        assert.strictEqual(Lorem.generate(3, "paragraphs"), Lorem.generate(3, "paragraphs"));
        assert.strictEqual(Lorem.generate(4, "sentences").split(". ").length, 4);
        assert.strictEqual(Lorem.describe(1, "paragraphs"), "1 paragraph");
        assert.strictEqual(Lorem.describe(20, "words"), "20 words");
        assert.strictEqual(Lorem.preview("aaa bbb ccc", 6), "aaa…");
    });
});

test.describe("colour picks", () => {
    test.it("knows picking from listing", () => {
        assert.strictEqual(Picks.colourAsk("pick colour"), "pick");
        assert.strictEqual(Picks.colourAsk("color picker"), "pick");
        assert.strictEqual(Picks.colourAsk("colours"), "history");
        assert.strictEqual(Picks.colourAsk("colour"), "");
    });

    test.it("reads hyprpicker output and keeps a short history", () => {
        assert.strictEqual(Picks.readPicked("#A1B2C3\n"), "#a1b2c3");
        assert.strictEqual(Picks.readPicked(""), "");
        let history = Picks.remember([], "#111111", 1, 2);
        history = Picks.remember(history, "#222222", 2, 2);
        history = Picks.remember(history, "#111111", 3, 2);
        assert.deepStrictEqual(history.map(h => h.hex), ["#111111", "#222222"]);
        history = Picks.remember(history, "#333333", 4, 2);
        assert.deepStrictEqual(history.map(h => h.hex), ["#333333", "#111111"]);
        assert.deepStrictEqual(Picks.forget(history, "#333333").map(h => h.hex), ["#111111"]);
        assert.deepStrictEqual(Picks.readHistory('{"picks":[{"hex":"#abcdef","at":1},{"hex":"bad"}]}', 5), [{
                hex: "#abcdef",
                at: 1
            }]);
    });
});

test.describe("vaults left out", () => {
    const vaults = [{ name: "Agent", path: "/home/u/Obsidian/Agent" }, { name: "Thoughts", path: "/home/u/Obsidian/Thoughts" }, { name: "Work", path: "/home/u/Work" }];

    test.it("drops vaults named by name or by folder, with ~ for home", () => {
        assert.deepStrictEqual(Notes.withoutSkipped(vaults, "Agent, ~/Work", "/home/u").map(v => v.name), ["Thoughts"]);
        assert.deepStrictEqual(Notes.withoutSkipped(vaults, "/home/u/Obsidian/Agent/", "/home/u").map(v => v.name), ["Thoughts", "Work"]);
    });

    test.it("keeps every vault when nothing is left out", () => {
        assert.strictEqual(Notes.withoutSkipped(vaults, "", "/home/u").length, 3);
        assert.strictEqual(Notes.withoutSkipped(vaults, " , ", "/home/u").length, 3);
    });
});

test.describe("review fixes", () => {
    test.it("finds repositories under a symlinked project folder", () => {
        const dir = scratch();
        fs.mkdirSync(path.join(dir, "real", "app", ".git"), {
            recursive: true
        });
        fs.symlinkSync(path.join(dir, "real"), path.join(dir, "link"));
        const command = Projects.scanCommand([path.join(dir, "link")], 2, "_archive");
        const found = Projects.readScan(execFileSync(command[0], command.slice(1)).toString());
        assert.deepStrictEqual(found.map(p => p.path), [path.join(dir, "link", "app")]);
    });

    test.it("indexes symlinked and dot-named vaults without fd", () => {
        const dir = scratch();
        fs.mkdirSync(path.join(dir, ".vault", ".obsidian"), {
            recursive: true
        });
        fs.writeFileSync(path.join(dir, ".vault", "first.md"), "x");
        fs.writeFileSync(path.join(dir, ".vault", ".obsidian", "hidden.md"), "x");
        fs.mkdirSync(path.join(dir, "elsewhere"));
        fs.writeFileSync(path.join(dir, "elsewhere", "second.md"), "x");
        fs.symlinkSync(path.join(dir, "elsewhere"), path.join(dir, "linked"));
        const vaults = Notes.vaultsFrom([], `${path.join(dir, ".vault")}/.obsidian\n${path.join(dir, "linked")}/.obsidian\n`);
        const command = Notes.indexCommand(vaults, 100);
        const env = {
            PATH: bare(["sh", "nice", "find", "head", "stat", "xargs"])
        };
        const notes = Notes.readIndex(execFileSync(command[0], command.slice(1), {
            env
        }).toString(), vaults);
        assert.deepStrictEqual(notes.map(n => n.name).sort(), ["first", "second"]);
    });

    test.it("counts an editor as a terminal one only by its whole name", () => {
        assert.strictEqual(Projects.editorFor("neovide", "", []).terminal, false);
        assert.strictEqual(Projects.editorFor("vivaldi", "", []).terminal, false);
        assert.strictEqual(Projects.editorFor("/usr/bin/vim", "", []).terminal, true);
        assert.strictEqual(Projects.editorFor("emacs -nw", "", []).terminal, true);
        assert.strictEqual(Projects.editorFor("emacs", "", []).terminal, false);
    });

    test.it("keeps notes and projects below an app prefix match when not asked for", () => {
        const app = 0.5;
        for (const score of [Projects.ambientScore, Notes.ambientScore]) {
            assert.ok(score(Ranking.EXACT) < app);
            assert.ok(score(Ranking.EXACT) > score(Ranking.PREFIX));
            assert.ok(score(Ranking.PREFIX) > score(Ranking.WORD));
            assert.ok(score(Ranking.WORD) > 0);
            assert.strictEqual(score(Ranking.ANYWHERE), 0);
        }
    });

    test.it("keeps only the newest notes for a bare notes listing", () => {
        const vaults = Notes.vaultsFrom([], "/v/.obsidian\n");
        const lines = [];
        for (let i = 0; i < 500; i++)
            lines.push(`${(i * 7919) % 500}\t/v/note ${i}.md`);
        const notes = Notes.readIndex(lines.join("\n"), vaults);
        const top = Notes.search(notes, "", Ranking.place, 10);
        const sorted = notes.slice().sort((a, b) => b.modified - a.modified).slice(0, 10);
        assert.deepStrictEqual(top.map(h => h.note.path), sorted.map(n => n.path));
        const named = Notes.search(notes, "note 1", Ranking.place, 3);
        assert.strictEqual(named[0].note.name, "note 1");
    });

    test.it("quotes a shell path with a quote in it", () => {
        assert.strictEqual(Projects.quote("/opt/bandit's shell/install.sh"), "'/opt/bandit'\\''s shell/install.sh'");
    });

    test.it("still takes arguments after leading spaces", () => {
        const s = Scripts.parseScript("/s/say.py", SAY, true);
        assert.deepStrictEqual(Scripts.askFor(s, "   say hi").values, ["hi"]);
    });
});
