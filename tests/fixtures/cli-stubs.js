const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const ROOT = path.resolve(__dirname, "../..");
const CLI = path.join(ROOT, "cli/banditshell");
const TMP = fs.mkdtempSync(path.join(os.tmpdir(), "banditshell-cli-"));

function cleanup() {
    fs.rmSync(TMP, { recursive: true, force: true });
}

function directory(prefix) {
    return fs.mkdtempSync(path.join(TMP, `${prefix}-`));
}

function stubs() {
    const dir = directory("stubs");
    const log = path.join(dir, "calls.log");
    fs.writeFileSync(log, "");
    const refuse = '#!/bin/sh\necho "$(basename "$0") $*" >>"$STUB_LOG"\nexit 99\n';
    for (const name of ["qs", "hyprctl", "grim", "slurp", "notify-send", "wl-copy", "jq", "python3", "gcc", "git"])
        fs.writeFileSync(path.join(dir, name), refuse, { mode: 0o755 });
    return { dir, log };
}

function cli(args, options = {}) {
    const home = options.home ?? directory("home");
    const stub = options.stub ?? stubs();
    const result = spawnSync("bash", [CLI, ...args], {
        cwd: ROOT,
        encoding: "utf8",
        env: {
            PATH: `${stub.dir}:/usr/bin:/bin`,
            HOME: home,
            LANG: "C.UTF-8",
            XDG_RUNTIME_DIR: path.join(home, "run"),
            STUB_LOG: stub.log,
            NO_COLOR: "1",
            ...(options.env ?? {})
        }
    });
    return {
        code: result.status,
        out: result.stdout,
        err: result.stderr,
        calls: fs.readFileSync(stub.log, "utf8").split("\n").filter(Boolean),
        home,
        stub
    };
}

module.exports = { ROOT, CLI, TMP, cleanup, directory, stubs, cli };
