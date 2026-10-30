const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");
const { spawn } = require("node:child_process");
const { ROOT, cleanup, cli, directory, stubs } = require("./fixtures/cli-stubs.js");

test.after(cleanup);

const dry = { env: { BANDITSHELL_DRY: "1" } };

const NODE_DIR = path.dirname(process.execPath);

function withNode(options) {
    const stub = options.stub ?? stubs();
    return Object.assign({}, options, { stub, env: Object.assign({}, options.env, { PATH: `${stub.dir}:${NODE_DIR}:/usr/bin:/bin` }) });
}

function shell(args, options = dry) {
    return cli(args, withNode(options));
}

function pluginsOf(home) {
    return path.join(home, ".config/banditshell/plugins");
}

test("plugin new writes a plugin the shell accepts, under the name given", () => {
    const run = shell(["plugin", "new", "notes"], dry);
    assert.strictEqual(run.code, 0, run.err);
    const folder = path.join(pluginsOf(run.home), "notes");
    const manifest = JSON.parse(fs.readFileSync(path.join(folder, "plugin.json"), "utf8"));
    assert.deepStrictEqual([manifest.id, manifest.prefix], ["notes", ["notes"]]);
    assert.ok(fs.existsSync(path.join(folder, "plugin.py")));
    assert.strictEqual(shell(["plugin"], { home: run.home, ...dry }).out.trim(), "notes");
});

test("plugin new --bash writes a bash plugin that can run", () => {
    const run = shell(["plugin", "new", "tally", "--bash"], dry);
    assert.strictEqual(run.code, 0, run.err);
    const script = path.join(pluginsOf(run.home), "tally", "plugin.sh");
    assert.ok(fs.statSync(script).mode & 0o100, "plugin.sh is executable");
});

test("plugin new refuses a bad name and a name already taken", () => {
    assert.strictEqual(shell(["plugin", "new", "Bad Name"], dry).code, 2);
    const first = shell(["plugin", "new", "dup"], dry);
    assert.strictEqual(shell(["plugin", "new", "dup"], { home: first.home, ...dry }).code, 1);
});

test("plugin install shows what the plugin runs before it copies it in", () => {
    const source = path.join(ROOT, "docs/plugins/examples/hello-python");
    const run = shell(["plugin", "install", source, "--yes"], dry);
    assert.strictEqual(run.code, 0, run.err);
    assert.match(run.out, /^runs +python3 -I plugin\.py$/m);
    assert.match(run.out, /^answers +after greet and in plain searches/m);
    assert.match(run.out, /^asks for +Greeting$/m);
    assert.ok(run.out.indexOf("runs") < run.out.indexOf("installed"), "shown before installing");
    assert.ok(fs.existsSync(path.join(pluginsOf(run.home), "hello-python", "plugin.py")));
    assert.strictEqual(shell(["plugin", "install", source, "--yes"], { home: run.home, ...dry }).code, 1, "refuses a second copy");
});

test("plugin install clones a git url, shows its commit and leaves .git behind", () => {
    const stub = stubs();
    const fixture = path.join(ROOT, "docs/plugins/examples/hello-bash");
    fs.writeFileSync(path.join(stub.dir, "git"), `#!/bin/sh
echo "git $*" >>"$STUB_LOG"
case "$1" in
clone) for last; do :; done; mkdir -p "$last/.git"; cp -r "${fixture}/." "$last/" ;;
-C) echo "abc1234 Greets in bash" ;;
esac
`, { mode: 0o755 });
    const run = shell(["plugin", "install", "https://example.org/hello-bash.git", "--yes"], { stub, ...dry });
    assert.strictEqual(run.code, 0, run.err);
    assert.ok(run.calls.includes(`git clone --quiet --depth 1 -- https://example.org/hello-bash.git ${run.calls[0].split(" ").pop()}`), run.calls.join("\n"));
    assert.match(run.out, /^commit +abc1234 Greets in bash$/m);
    const installed = path.join(pluginsOf(run.home), "hello-bash");
    assert.ok(fs.existsSync(path.join(installed, "plugin.sh")));
    assert.ok(!fs.existsSync(path.join(installed, ".git")));
});

test("plugin install never installs without a yes", () => {
    const run = shell(["plugin", "install", path.join(ROOT, "docs/plugins/examples/hello-bash")], dry);
    assert.strictEqual(run.code, 2);
    assert.match(run.err, /--yes/);
    assert.ok(!fs.existsSync(path.join(pluginsOf(run.home), "hello-bash")));
});

test("plugin install refuses a folder whose manifest the shell would refuse", () => {
    const folder = directory("broken");
    fs.writeFileSync(path.join(folder, "plugin.json"), '{"api":2,"id":"broken","name":"Broken","exec":["x"],"prefix":["b"]}');
    const run = shell(["plugin", "install", folder, "--yes"], dry);
    assert.strictEqual(run.code, 1);
    assert.match(run.err, /api 2/);
});

test("plugin install lists links, survives a dangling one and refuses one that leaves the plugin", () => {
    const folder = directory("linked");
    fs.cpSync(path.join(ROOT, "docs/plugins/examples/hello-bash"), folder, { recursive: true });
    fs.symlinkSync("plugin.sh", path.join(folder, "alias.sh"));
    fs.symlinkSync("missing", path.join(folder, "dangling"));
    const fine = shell(["plugin", "install", folder, "--yes"], dry);
    assert.strictEqual(fine.code, 0, fine.err);
    assert.match(fine.out, /alias\.sh -> plugin\.sh/);
    assert.match(fine.out, /dangling -> missing/);
    fs.symlinkSync("/etc", path.join(folder, "escape"));
    const refused = shell(["plugin", "install", folder, "--yes"], dry);
    assert.strictEqual(refused.code, 1);
    assert.match(refused.err, /escape -> \/etc/);
    assert.ok(!fs.existsSync(path.join(pluginsOf(refused.home), "hello-bash")));
});

test("plugin install names a bad id plainly, whatever the folder is called", () => {
    const folder = directory("src");
    fs.writeFileSync(path.join(folder, "plugin.json"), '{"api":1,"id":"Bad","name":"B","exec":["x"],"prefix":["b"]}');
    assert.match(shell(["plugin", "install", folder, "--yes"], dry).err, /the id must be lowercase letters, digits and -/);
});

test("the bash template fills only rows it made, never its hint", () => {
    const run = shell(["plugin", "new", "yy", "--bash"], dry);
    const script = path.join(pluginsOf(run.home), "yy", "plugin.sh");
    const out = require("node:child_process").execFileSync("bash", [script], { input: '{"type":"complete","id":"hint"}\n{"type":"complete","id":"echo:hi"}\n', env: { PATH: process.env.PATH, BANDITSHELL_PLUGIN_ID: "yy" }, encoding: "utf8" });
    assert.deepStrictEqual(out.trim().split("\n").map(l => JSON.parse(l).text), ["yy hi "]);
});

test("the plugin template answers a query and a Tab", async () => {
    const run = shell(["plugin", "new", "echo"], dry);
    const folder = path.join(pluginsOf(run.home), "echo");
    const child = spawn("python3", ["-I", "plugin.py"], { cwd: folder, env: { PATH: process.env.PATH, BANDITSHELL_PLUGIN_ID: "echo" } });
    const out = await new Promise((resolve, reject) => {
        let text = "";
        const timer = setTimeout(() => reject(new Error(`no answer: ${text}`)), 5000);
        child.stdout.on("data", chunk => {
            text += chunk;
            if (text.split("\n").length > 2) {
                clearTimeout(timer);
                child.stdin.end();
                resolve(text.trim().split("\n").map(line => JSON.parse(line)));
            }
        });
        child.stdin.write('{"type":"query","seq":4,"text":"hi there","prefixed":true}\n{"type":"complete","id":"echo:hi there"}\n');
    });
    assert.deepStrictEqual([out[0].seq, out[0].items[0].title, out[1].text], [4, "hi there", "echo hi there "]);
});
