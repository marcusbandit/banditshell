const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const child = require("node:child_process");

const ROOT = path.resolve(__dirname, "..");

function source(file) {
    return fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "");
}

const Quoting = new Function(`${source("services/quoting.js")}\nreturn { forShell, posix, visible, hasControl };`)();
const Commands = new Function("Quoting", `${source("services/files-commands.js").replace(/^\.import .*$/m, "")}
return { humanSize, join, clearLine, typed, refusal, runPlan, cdLine, cdPlan, folderCommand, fileCommand, moveCommand, trashCommand, removeCommand, progressLine, leftChild, totalsCommand, totals, statusLine, outside };`)(Quoting);

function installed(shell) {
    return child.spawnSync("sh", ["-c", `command -v ${shell}`]).status === 0;
}

function flagsFor(shell) {
    return shell === "zsh" ? ["-f"] : [];
}

const WORD_COMMANDS = ["mkdir", "touch", "mv", "gio", "rm"];
const RECORDERS = WORD_COMMANDS.map(name => `${name}() { printf '%s\\0' ${name} "$@"; }`).join("; ");

function argvOf(shell, line) {
    const run = child.spawnSync(shell, [...flagsFor(shell), "-c", `${RECORDERS}; ${line}`], {encoding: "buffer"});
    assert.strictEqual(run.status, 0, String(run.stderr));
    const fields = run.stdout.toString("utf8").split("\0");
    fields.pop();
    return fields;
}

function typedLine(shell, plan) {
    const prefix = Commands.clearLine(shell);
    assert.ok(plan.text.startsWith(prefix) && plan.text.endsWith("\r"), JSON.stringify(plan.text));
    return plan.text.slice(prefix.length, -1);
}

const NAMES = [
    "plain",
    "a b",
    "it's",
    "say \"hi\"",
    "$HOME",
    "`id`",
    "$(touch PWNED)",
    "-rf",
    "back\\slash",
    "café 😀",
    "tab\there",
    "new\nline",
    "\x01x",
    "\x1b[201~",
    "a;b&c|d"
];

test.describe("humanSize", () => {
    test.it("shows a count below a kilobyte in bytes", () => {
        assert.strictEqual(Commands.humanSize(0), "0 B");
        assert.strictEqual(Commands.humanSize(1023), "1023 B");
    });

    test.it("moves to kilobytes at exactly 1024 bytes", () => {
        assert.strictEqual(Commands.humanSize(1024), "1.0 kB");
    });

    test.it("keeps 1023 kilobytes in kB", () => {
        assert.strictEqual(Commands.humanSize(1023 * 1024), "1023 kB");
    });

    test.it("reads 1048575 bytes as 1.0 MB, not 1024 kB", () => {
        assert.strictEqual(Commands.humanSize(1048575), "1.0 MB");
    });

    test.it("moves to megabytes at exactly 1048576 bytes", () => {
        assert.strictEqual(Commands.humanSize(1048576), "1.0 MB");
    });

    test.it("carries a kilobyte value that rounds up to 1024 into MB", () => {
        assert.strictEqual(Commands.humanSize(1048064), "1.0 MB");
    });

    test.it("carries a megabyte value that rounds up to 1024 into GB", () => {
        assert.strictEqual(Commands.humanSize(1073741823), "1.0 GB");
    });

    test.it("shows one decimal below ten and whole numbers from ten up", () => {
        assert.strictEqual(Commands.humanSize(1536), "1.5 kB");
        assert.strictEqual(Commands.humanSize(10 * 1024), "10 kB");
        assert.strictEqual(Commands.humanSize(9.5 * 1048576), "9.5 MB");
    });

    test.it("reads large sizes in GB, TB and PB", () => {
        assert.strictEqual(Commands.humanSize(1e12), "931 GB");
        assert.strictEqual(Commands.humanSize(3 * 1024 ** 4), "3.0 TB");
        assert.strictEqual(Commands.humanSize(5 * 1024 ** 5), "5.0 PB");
    });

    test.it("stays in PB past the largest unit", () => {
        assert.strictEqual(Commands.humanSize(2 ** 60), "1024 PB");
    });
});

test.describe("typed paths", () => {
    test.it("quotes an ordinary path in single quotes", () => {
        assert.deepStrictEqual(Commands.typed("zsh", ["/home/ada/notes"]), ["'/home/ada/notes'"]);
    });

    test.it("keeps spaces inside one word", () => {
        assert.deepStrictEqual(Commands.typed("bash", ["/home/ada/my notes"]), ["'/home/ada/my notes'"]);
    });

    test.it("escapes a single quote without ending the word", () => {
        assert.deepStrictEqual(Commands.typed("zsh", ["/home/ada/it's"]), ["'/home/ada/it'\\''s'"]);
    });

    test.it("keeps double quotes, dollar signs and backticks literal", () => {
        assert.deepStrictEqual(Commands.typed("bash", ['/x/"q" $HOME `id`']), ["'/x/\"q\" $HOME `id`'"]);
    });

    test.it("keeps a leading dash as part of the path", () => {
        assert.deepStrictEqual(Commands.typed("zsh", ["/home/ada/-rf"]), ["'/home/ada/-rf'"]);
    });

    test.it("keeps unicode characters as they are", () => {
        assert.deepStrictEqual(Commands.typed("zsh", ["/home/ada/café 😀"]), ["'/home/ada/café 😀'"]);
    });

    test.it("returns nothing for the whole list when one path cannot be typed", () => {
        assert.strictEqual(Commands.typed("fish", ["/home/ada/a", "/home/ada/b\x07"]), null);
    });
});

test.describe("typing into the live shell", () => {
    test.it("clears a half-typed line with alt-q in zsh and ctrl-e ctrl-u elsewhere", () => {
        assert.strictEqual(Commands.clearLine("zsh"), "\x1bq");
        assert.strictEqual(Commands.clearLine("bash"), "\x05\x15");
        assert.strictEqual(Commands.clearLine(""), "\x05\x15");
    });

    test.it("explains a refused path with the shell's name and control characters as escapes", () => {
        assert.strictEqual(Commands.refusal("zsh", "/a\x1bb"), "cannot type this path into zsh: /a\\x1bb");
        assert.strictEqual(Commands.refusal("", "/x\x07"), "cannot type this path into the shell: /x\\x07");
    });

    test.it("types the command after the clear key when the shell is live", () => {
        assert.deepStrictEqual(Commands.runPlan("zsh", true, Commands.folderCommand("/home/ada", "new folder")), {mode: "type", text: "\x1bqmkdir -p -- '/home/ada/new folder'\r"});
    });

    test.it("spawns the same command when no shell is live", () => {
        assert.deepStrictEqual(Commands.runPlan("zsh", false, Commands.folderCommand("/home/ada", "new folder")), {mode: "spawn", argv: ["mkdir", "-p", "--", "/home/ada/new folder"]});
    });

    test.it("spawns a path the shell cannot quote, never a partial line", () => {
        assert.deepStrictEqual(Commands.runPlan("", true, Commands.moveCommand("/home/ada/it's", "/home/ada/b")), {mode: "spawn", argv: ["mv", "-i", "--", "/home/ada/it's", "/home/ada/b"]});
    });

    test.it("spawns the whole command when only one of its paths cannot be typed", () => {
        assert.deepStrictEqual(Commands.runPlan("fish", true, Commands.trashCommand(["/home/ada/a", "/home/ada/b\x07"])), {mode: "spawn", argv: ["gio", "trash", "--", "/home/ada/a", "/home/ada/b\x07"]});
    });

    test.it("spawns a control character for a shell without dollar quoting", () => {
        assert.strictEqual(Commands.runPlan("sh", true, Commands.fileCommand("/home/ada", "a\nb")).mode, "spawn");
        assert.strictEqual(Commands.runPlan("nu", true, Commands.fileCommand("/home/ada", "a\x1bb")).mode, "spawn");
    });

    test.it("types a newline in zsh and bash as one escaped word", () => {
        assert.strictEqual(Commands.runPlan("zsh", true, Commands.fileCommand("/home/ada", "a\nb")).text, "\x1bqtouch -- $'/home/ada/a\\x0ab'\r");
        assert.strictEqual(Commands.runPlan("bash", true, Commands.fileCommand("/home/ada", "a\nb")).text, "\x05\x15touch -- $'/home/ada/a\\x0ab'\r");
    });
});

test.describe("paste progress", () => {
    test.it("shows bytes and a percentage once the total is known", () => {
        assert.strictEqual(Commands.progressLine("Copying photos", 5 * 1024 * 1024, 20 * 1024 * 1024), "Copying photos, 5.0 MB of 20 MB (25%)");
    });

    test.it("shows bytes so far while the total is unknown and never reaches 100% before the end", () => {
        assert.strictEqual(Commands.progressLine("Moving 3 items", 2048, 0), "Moving 3 items, 2.0 kB so far");
        assert.strictEqual(Commands.progressLine("Copying a", 1000, 1000), "Copying a, 1000 B of 1000 B (99%)");
    });
});

test.describe("file commands", () => {
    test.it("joins a name onto a folder with one slash", () => {
        assert.strictEqual(Commands.join("/home/ada", "notes.txt"), "/home/ada/notes.txt");
    });

    test.it("does not double the slash under the root", () => {
        assert.strictEqual(Commands.join("/", "etc"), "/etc");
    });

    test.it("makes a folder with mkdir -p and -- before the name", () => {
        assert.deepStrictEqual(Commands.folderCommand("/home/ada", "-rf"), {words: ["mkdir", "-p", "--"], paths: ["/home/ada/-rf"]});
    });

    test.it("makes a file under the root without a doubled slash", () => {
        assert.deepStrictEqual(Commands.fileCommand("/", "-x"), {words: ["touch", "--"], paths: ["/-x"]});
    });

    test.it("moves with mv -i and -- before both paths", () => {
        assert.deepStrictEqual(Commands.moveCommand("/home/ada/-a", "/home/ada/b"), {words: ["mv", "-i", "--"], paths: ["/home/ada/-a", "/home/ada/b"]});
    });

    test.it("trashes with gio trash and -- before the paths", () => {
        assert.deepStrictEqual(Commands.trashCommand(["/home/ada/a", "/home/ada/-b"]), {words: ["gio", "trash", "--"], paths: ["/home/ada/a", "/home/ada/-b"]});
    });

    test.it("deletes forever with rm -rf, the paths, then their trash info files", () => {
        assert.deepStrictEqual(Commands.removeCommand(["/t/files/a"], ["/t/info/a.trashinfo"]), {words: ["rm", "-rf", "--"], paths: ["/t/files/a", "/t/info/a.trashinfo"]});
    });
});

test.describe("moving to a folder in the live shell", () => {
    test.it("types cd after the clear key when the shell is live and idle", () => {
        assert.deepStrictEqual(Commands.cdPlan("bash", true, false, "/home/ada/it's"), {mode: "type", text: "\x05\x15cd '/home/ada/it'\\''s'\r"});
    });

    test.it("only changes the folder when no shell is running", () => {
        assert.deepStrictEqual(Commands.cdPlan("nu", false, false, "/home/ada/it's"), {mode: "local"});
    });

    test.it("defers the typed cd while the shell is busy", () => {
        assert.deepStrictEqual(Commands.cdPlan("zsh", true, true, "/home/ada"), {mode: "desync"});
    });

    test.it("refuses a path it cannot type, even while the shell is busy", () => {
        assert.deepStrictEqual(Commands.cdPlan("nu", true, true, "/home/ada/it's"), {mode: "refuse", failure: "cannot type this path into nu: /home/ada/it's"});
    });

    test.it("types nothing for a control character in a shell without dollar quoting", () => {
        assert.strictEqual(Commands.cdLine("fish", "/home/ada/a\x07"), null);
    });
});

for (const shell of ["zsh", "bash"]) {
    test.it(`hands ${shell} the same words and paths back for every file command and name`, {skip: !installed(shell)}, () => {
        for (const name of NAMES) {
            const commands = [
                Commands.folderCommand("/home/ada", name),
                Commands.fileCommand("/home/ada", name),
                Commands.moveCommand("/home/ada/from", `/home/ada/${name}`),
                Commands.trashCommand([`/home/ada/${name}`]),
                Commands.removeCommand([`/home/ada/${name}`], [`/home/ada/${name}.trashinfo`])
            ];
            for (const command of commands) {
                const plan = Commands.runPlan(shell, true, command);
                assert.strictEqual(plan.mode, "type", JSON.stringify(name));
                assert.deepStrictEqual(argvOf(shell, typedLine(shell, plan)), [...command.words, ...command.paths], JSON.stringify(name));
            }
        }
    });

    test.it(`cds ${shell} into a folder whose name holds shell characters`, {skip: !installed(shell)}, () => {
        const base = fs.mkdtempSync(path.join(os.tmpdir(), "files-commands-"));
        try {
            const dir = path.join(base, "it's $HOME `id` \"q\" café 😀");
            fs.mkdirSync(dir);
            const plan = Commands.cdPlan(shell, true, false, dir);
            const run = child.spawnSync(shell, [...flagsFor(shell), "-c", `${typedLine(shell, plan)}; pwd -P`], {encoding: "utf8"});
            assert.strictEqual(run.stdout.trim(), fs.realpathSync(dir), run.stderr);
        } finally {
            fs.rmSync(base, {recursive: true, force: true});
        }
    });
}

test.describe("files commands: the folder you just left", () => {
    test.it("names the child of the new folder that holds the old one", () => {
        assert.strictEqual(Commands.leftChild("/a/b/c", "/a/b"), "c");
        assert.strictEqual(Commands.leftChild("/a/b/c", "/a"), "b");
        assert.strictEqual(Commands.leftChild("/a", "/"), "a");
    });

    test.it("names nothing when the new folder is not above the old one", () => {
        assert.strictEqual(Commands.leftChild("/a/bc", "/a/b"), "");
        assert.strictEqual(Commands.leftChild("/a", "/a"), "");
        assert.strictEqual(Commands.leftChild("/x", "/y"), "");
        assert.strictEqual(Commands.leftChild("/", "/a"), "");
    });
});

test.describe("files commands: folder totals", () => {
    test.it("reads the byte total and the item count", () => {
        assert.deepStrictEqual(Commands.totals("token 3\nsize 123456\nitems 80\n"), {token: "3", bytes: 123456, items: 80});
    });

    test.it("leaves the size empty when du printed nothing", () => {
        assert.deepStrictEqual(Commands.totals("token 4\nsize \nitems 0\n"), {token: "4", bytes: null, items: 0});
    });

    test.it("runs du and ls on the path given as an argument, not spliced into the script", () => {
        const command = Commands.totalsCommand("/tmp/a b'; rm -rf x", 7);
        assert.deepStrictEqual(command.slice(-3), ["sh", "/tmp/a b'; rm -rf x", "7"]);
        assert.ok(!command[2].includes("rm -rf"));
    });

    test.it("measures a real folder whose name holds a newline", () => {
        const dir = fs.mkdtempSync(path.join(os.tmpdir(), "totals-"));
        const odd = path.join(dir, "a\nb");
        fs.mkdirSync(odd);
        fs.writeFileSync(path.join(odd, "a"), "x".repeat(10000));
        fs.writeFileSync(path.join(odd, ".hidden"), "y");
        fs.mkdirSync(path.join(odd, "sub"));
        const command = Commands.totalsCommand(odd, 9);
        const run = child.spawnSync(command[0], command.slice(1), {encoding: "utf8"});
        const got = Commands.totals(run.stdout);
        fs.rmSync(dir, {recursive: true});
        assert.strictEqual(got.token, "9");
        assert.strictEqual(got.items, 3);
        assert.ok(got.bytes >= 10001);
    });
});

test.describe("statusLine", () => {
    const size = bytes => `${bytes} B`;

    test.it("counts the items of a folder", () => {
        assert.strictEqual(Commands.statusLine(300, [], size), "300 items");
        assert.strictEqual(Commands.statusLine(1, [{kind: "file", size: 5}], size), "1 item");
        assert.strictEqual(Commands.statusLine(0, [], size), "0 items");
    });

    test.it("counts a selection of many and adds up the file sizes", () => {
        const picks = [{kind: "file", size: 100}, {kind: "file", size: 24}];
        assert.strictEqual(Commands.statusLine(300, picks, size), "2 selected, 124 B");
    });

    test.it("leaves the size out when only folders are picked", () => {
        assert.strictEqual(Commands.statusLine(9, [{kind: "dir", size: 4096}, {kind: "dir", size: 4096}], size), "2 selected");
    });

    test.it("says the size only covers files when a folder is picked", () => {
        const picks = [{kind: "file", size: 100}, {kind: "dir", size: 4096}];
        assert.strictEqual(Commands.statusLine(9, picks, size), "2 selected, 100 B in files");
    });
});

test.describe("outside", () => {
    test.it("keeps the files that are not already in the folder", () => {
        assert.deepStrictEqual(Commands.outside(["/home/a/x.png", "/home/b/y.png", "/z.txt"], "/home/a"), ["/home/b/y.png", "/z.txt"]);
        assert.deepStrictEqual(Commands.outside(["/z.txt"], "/"), []);
    });
});
