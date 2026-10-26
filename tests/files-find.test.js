const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { execFileSync, spawnSync } = require("node:child_process");

const ROOT = path.resolve(__dirname, "..");

function lib(file, names) {
    const src = fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "");
    return new Function(`${src}\nreturn { ${names.join(", ")} };`)();
}

const Find = lib("services/files-find.js", ["LEAST", "LIMIT", "SKIP_NAMES", "SKIP_PATHS", "command", "parse", "place", "named", "narrows", "merged", "grouped", "searchable"]);
const Order = lib("services/files-order.js", ["ordered"]);

const HOME = "/home/ada";

function argsAfterDashes(words) {
    return words.slice(words.indexOf("--") + 1);
}

test.describe("the search command line", () => {
    test.it("puts the query and home after -- as two whole words", () => {
        for (const query of ["two words", "it's", "say \"hi\"", "-rf", "$(rm -rf ~)", "a\nb"]) {
            const words = Find.command("/x/bs-ls", query, HOME, HOME, {});
            assert.deepStrictEqual(argsAfterDashes(words), [query.trim(), HOME], JSON.stringify(query));
        }
    });

    test.it("runs the helper at low priority with a result cap", () => {
        const words = Find.command("/x/bs-ls", "report", HOME, HOME, {});
        assert.deepStrictEqual(words.slice(0, 7), ["nice", "-n", "10", "/x/bs-ls", "--find", "--limit", String(Find.LIMIT)]);
    });

    test.it("skips heavy and private places under home unless asked", () => {
        const words = Find.command("/x/bs-ls", "report", HOME, HOME, {});
        for (const name of ["node_modules", ".git", ".cache"])
            assert.ok(words.join("\0").includes(`--skip\0${name}`), name);
        for (const rel of [".local/share/Trash", ".ssh", ".gnupg"])
            assert.ok(words.join("\0").includes(`--skip-path\0${HOME}/${rel}`), rel);
        const deep = Find.command("/x/bs-ls", "report", HOME, HOME, {deep: true});
        assert.ok(deep.includes("--deep"));
        assert.ok(!deep.includes("--skip") && !deep.includes("--skip-path"));
    });

    test.it("searches the open folder first only when it is inside home", () => {
        const first = words => words.includes("--first") ? words[words.indexOf("--first") + 1] : null;
        assert.strictEqual(first(Find.command("b", "report", HOME, `${HOME}/My Docs`, {})), `${HOME}/My Docs`);
        assert.strictEqual(first(Find.command("b", "report", HOME, HOME, {})), null);
        assert.strictEqual(first(Find.command("b", "report", HOME, "/etc", {})), null);
        assert.strictEqual(first(Find.command("b", "report", HOME, "/home/adam", {})), null);
    });

    test.it("passes hidden files on only when they are shown", () => {
        assert.ok(Find.command("b", "rc", HOME, HOME, {hidden: true}).includes("--hidden"));
        assert.ok(!Find.command("b", "rc", HOME, HOME, {}).includes("--hidden"));
    });

    test.it("does not walk for a query too short to mean anything or one with a slash", () => {
        assert.strictEqual(Find.command("b", "a", HOME, HOME, {}), null);
        assert.strictEqual(Find.command("b", "   ", HOME, HOME, {}), null);
        assert.strictEqual(Find.command("b", "docs/x", HOME, HOME, {}), null);
    });
});

test.describe("reading what the walk says", () => {
    test.it("keys a result by its full path, whatever its name holds", () => {
        for (const name of ["two words.txt", "it's \"quoted\".md", "new\nline.txt", "ünïcode ✓"]) {
            const line = JSON.stringify({dir: `${HOME}/a b`, name: name, kind: "file"});
            assert.ok(!line.includes("\n"));
            const said = Find.parse(line);
            assert.strictEqual(said.entry.name, name);
            assert.strictEqual(said.entry.key, `${HOME}/a b/${name}`);
        }
    });

    test.it("reads progress, the end, and ignores noise", () => {
        assert.deepStrictEqual(Find.parse('{"scanned":500,"found":3}'), {scanned: 500});
        assert.deepStrictEqual(Find.parse('{"done":true,"scanned":9,"found":2,"capped":true}'), {done: true, scanned: 9, capped: true});
        for (const line of ["", "not json", "[]", "null", '{"name":"x"}', '{"dir":"/a","name":""}'])
            assert.strictEqual(Find.parse(line), null, line);
    });

    test.it("says where a result lives relative to home", () => {
        assert.strictEqual(Find.place(HOME, HOME), "~");
        assert.strictEqual(Find.place(`${HOME}/Documents/work`, HOME), "~/Documents/work");
        assert.strictEqual(Find.place("/home/adam/x", HOME), "/home/adam/x");
    });
});

test.describe("ordering results", () => {
    const e = (dir, name, extra) => Object.assign({dir: dir, name: name, kind: "file", class: "text", size: 1, mtime: 1, key: `${dir}/${name}`}, extra);
    const cwd = `${HOME}/Docs`;
    const local = [{name: "zz report.txt", kind: "file", class: "text", size: 5, mtime: 9}, {name: "a report.txt", kind: "file", class: "text", size: 1, mtime: 1}];
    const found = [
        e(HOME, "b report.txt", {size: 50}),
        e(`${cwd}/deep`, "c report.txt", {size: 2}),
        e(cwd, "a report.txt"),
        e(`${HOME}/Other`, "a report.txt", {size: 9})
    ];

    test.it("puts this folder first, then below it, then the rest of home", () => {
        const out = Find.grouped(local, found, cwd, list => Order.ordered(list, "name", false));
        assert.deepStrictEqual(out.map(x => x.key ?? x.name), ["a report.txt", "zz report.txt", `${cwd}/deep/c report.txt`, `${HOME}/Other/a report.txt`, `${HOME}/b report.txt`]);
    });

    test.it("keeps the current sort and direction inside each group", () => {
        const out = Find.grouped(local, found, cwd, list => Order.ordered(list, "size", true));
        assert.deepStrictEqual(out.map(x => x.key ?? x.name), ["a report.txt", "zz report.txt", `${cwd}/deep/c report.txt`, `${HOME}/Other/a report.txt`, `${HOME}/b report.txt`]);
        const big = Find.grouped(local, found, cwd, list => Order.ordered(list, "size", false));
        assert.deepStrictEqual(big.slice(3).map(x => x.key), [`${HOME}/b report.txt`, `${HOME}/Other/a report.txt`]);
    });

    test.it("narrows a finished walk instead of walking again", () => {
        assert.ok(Find.narrows("rep", "report"));
        assert.ok(!Find.narrows("report", "rep"));
        assert.ok(!Find.narrows("r", "re"));
        assert.deepStrictEqual(Find.named(found, "C REP").map(x => x.name), ["c report.txt"]);
    });

    test.it("lets fresh results replace kept ones without doubling them", () => {
        const kept = [found[0], found[1]];
        const out = Find.merged([found[1], found[3]], kept);
        assert.deepStrictEqual(out.map(x => x.key), [found[1].key, found[3].key, found[0].key]);
    });
});

const cc = ["cc", "gcc", "clang"].find(name => spawnSync(name, ["--version"]).status === 0);

test.describe("the walk itself", {skip: cc ? false : "no C compiler"}, () => {
    const scratch = fs.mkdtempSync(path.join(os.tmpdir(), "bs-find-"));
    const helper = path.join(scratch, "bs-ls");
    const home = path.join(scratch, "home");
    const outside = path.join(scratch, "outside");

    test.before(() => {
        execFileSync(cc, ["-O2", "-o", helper, path.join(ROOT, "src/bs-ls.c")]);
        const touch = rel => {
            fs.mkdirSync(path.dirname(path.join(home, rel)), {recursive: true});
            fs.writeFileSync(path.join(home, rel), "");
        };
        ["Docs/report one.txt", "Docs/deep/report \"quoted\".md", "Docs/new\nline report.txt", "Music/Report.flac",
            ".cache/app/report.bin", "proj/node_modules/m/report.js", "proj/.git/report", ".local/share/Trash/files/report.old",
            ".ssh/report_key", ".hidden report"].forEach(touch);
        fs.mkdirSync(outside, {recursive: true});
        fs.writeFileSync(path.join(outside, "report outside.txt"), "");
        fs.symlinkSync(outside, path.join(home, "link out"));
        for (let d = 0; d < 300; d++) {
            const dir = path.join(home, "bulk", `d${d}`);
            fs.mkdirSync(dir, {recursive: true});
            for (let f = 0; f < 100; f++)
                fs.writeFileSync(path.join(dir, `file ${f}.txt`), "");
        }
        touch("bulk/d299/needle.txt");
    });

    test.after(() => fs.rmSync(scratch, {recursive: true, force: true}));

    function walk(query, cwd, options) {
        const words = Find.command(helper, query, home, cwd, options ?? {});
        const out = execFileSync(words[0], words.slice(1), {encoding: "utf8", maxBuffer: 64 << 20});
        const said = out.split("\n").filter(Boolean).map(Find.parse);
        assert.ok(said.every(Boolean), "every line parses");
        return {entries: said.filter(s => s.entry).map(s => s.entry), done: said.find(s => s.done)};
    }

    const rel = entry => path.relative(home, entry.key);

    test.it("finds odd names whole and skips the usual places", () => {
        const {entries, done} = walk("REPORT", home);
        assert.deepStrictEqual(entries.map(rel).sort(), ["Docs/deep/report \"quoted\".md", "Docs/new\nline report.txt", "Docs/report one.txt", "Music/Report.flac"]);
        assert.strictEqual(done.capped, false);
    });

    test.it("never follows a symlink out of home", () => {
        assert.ok(!walk("outside", home, {deep: true, hidden: true}).entries.some(e => e.key.startsWith(outside)));
        assert.deepStrictEqual(walk("link out", home).entries.map(rel), ["link out"]);
    });

    test.it("reaches hidden and skipped places only when asked", () => {
        const all = walk("report", home, {hidden: true, deep: true}).entries.map(rel);
        for (const r of [".cache/app/report.bin", "proj/node_modules/m/report.js", ".local/share/Trash/files/report.old", ".ssh/report_key", ".hidden report"])
            assert.ok(all.includes(r), r);
        assert.deepStrictEqual(walk("report", home, {hidden: true}).entries.map(rel).filter(r => r.startsWith(".")), [".hidden report"]);
    });

    test.it("reports the open folder's matches before the rest", () => {
        const {entries} = walk("report", path.join(home, "Music"));
        assert.strictEqual(rel(entries[0]), "Music/Report.flac");
        assert.strictEqual(entries.length, 4);
    });

    test.it("stops at the cap in a home of thirty thousand files", () => {
        const {entries, done} = walk("file", home, {limit: 250});
        assert.strictEqual(entries.length, 250);
        assert.strictEqual(done.capped, true);
    });

    test.it("finds one file among thirty thousand", () => {
        const began = Date.now();
        const {entries, done} = walk("needle", home);
        assert.deepStrictEqual(entries.map(rel), ["bulk/d299/needle.txt"]);
        assert.ok(done.scanned > 300);
        assert.ok(Date.now() - began < 5000);
    });
});
