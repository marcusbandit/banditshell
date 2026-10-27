const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const {spawn, spawnSync} = require("node:child_process");

const ROOT = path.resolve(__dirname, "..");
const work = fs.mkdtempSync(path.join(os.tmpdir(), "bs-watch-"));
const binary = path.join(work, "bs-ls");
const compiler = ["gcc", "clang"].find(cc => spawnSync(cc, ["--version"]).status === 0);
const built = compiler && spawnSync(compiler, ["-O2", "-o", binary, path.join(ROOT, "src/bs-ls.c")]).status === 0;

test.after(() => fs.rmSync(work, {recursive: true, force: true}));

const pause = ms => new Promise(resolve => setTimeout(resolve, ms));

function watch(dir) {
    const child = spawn(binary, ["--watch", dir], {stdio: ["pipe", "pipe", "pipe"]});
    const heard = [];
    let buffer = "";
    child.stdout.on("data", chunk => {
        buffer += chunk;
        const lines = buffer.split("\n");
        buffer = lines.pop();
        heard.push(...lines);
    });
    const exited = new Promise(resolve => child.on("exit", code => resolve(code)));
    const ready = new Promise(resolve => {
        child.stdout.on("data", () => heard.includes("ready") && resolve());
        exited.then(resolve);
    });
    return {child, heard, exited, ready, changes: () => heard.filter(line => line === "changed").length};
}

function folder(name) {
    const dir = path.join(work, name);
    fs.mkdirSync(dir);
    return dir;
}

test.describe("files watch", {skip: built ? false : "no C compiler"}, () => {
    test.it("a burst of changes is one message", async () => {
        const dir = folder("burst");
        const w = watch(dir);
        await w.ready;
        for (let i = 0; i < 500; i++)
            fs.writeFileSync(path.join(dir, `f${i}`), "");
        fs.renameSync(path.join(dir, "f0"), path.join(dir, "g0"));
        fs.rmSync(path.join(dir, "f1"));
        await pause(300);
        assert.strictEqual(w.changes(), 1);
        w.child.stdin.end();
        assert.strictEqual(await w.exited, 0);
    });

    test.it("reading the folder is not a change", async () => {
        const dir = folder("quiet");
        fs.writeFileSync(path.join(dir, "a"), "text");
        const w = watch(dir);
        await w.ready;
        spawnSync(binary, [dir]);
        fs.readFileSync(path.join(dir, "a"));
        await pause(250);
        assert.strictEqual(w.changes(), 0);
        w.child.stdin.end();
        await w.exited;
    });

    test.it("a change that never stops still reports about once a second", async () => {
        const dir = folder("storm");
        const w = watch(dir);
        await w.ready;
        const end = Date.now() + 2300;
        for (let i = 0; Date.now() < end; i++) {
            fs.writeFileSync(path.join(dir, `s${i}`), "");
            if (i % 40 === 0)
                await pause(5);
        }
        await pause(300);
        assert.ok(w.changes() >= 2 && w.changes() <= 4, `heard ${w.changes()}`);
        w.child.stdin.end();
        await w.exited;
    });

    test.it("stops when the shell lets go of it", async () => {
        const w = watch(folder("orphan"));
        await w.ready;
        w.child.stdin.end();
        assert.strictEqual(await w.exited, 0);
    });

    test.it("reports and stops when the folder itself goes", async () => {
        const dir = folder("gone");
        const w = watch(dir);
        await w.ready;
        fs.rmSync(dir, {recursive: true});
        assert.strictEqual(await w.exited, 0);
        assert.strictEqual(w.changes(), 1);
    });

    test.it("refuses a folder it cannot watch", async () => {
        const w = watch(path.join(work, "missing"));
        assert.strictEqual(await w.exited, 1);
        assert.ok(!w.heard.includes("ready"));
    });
});
