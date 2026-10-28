const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const SCRIPT = path.resolve(__dirname, "../scripts/pick-file.py");

function eitherCase(globs) {
    const code = [
        "import importlib.util, json, sys",
        "spec = importlib.util.spec_from_file_location('pick_file', sys.argv[1])",
        "module = importlib.util.module_from_spec(spec)",
        "spec.loader.exec_module(module)",
        "print(json.dumps([module.either_case(g) for g in sys.argv[2:]]))"
    ].join("\n");
    const run = spawnSync("python3", ["-I", "-c", code, SCRIPT, ...globs], { encoding: "utf8" });
    assert.strictEqual(run.status, 0, run.stderr);
    return JSON.parse(run.stdout);
}

test("the file filter matches an extension in either case", () => {
    assert.deepStrictEqual(eitherCase(["*.p12", "*.json"]), ["*.[pP]12", "*.[jJ][sS][oO][nN]"]);
});

function checkWith(zenity) {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), "pick-file-"));
    if (zenity)
        fs.writeFileSync(path.join(dir, "zenity"), "#!/bin/sh\nexit 0\n", { mode: 0o755 });
    const code = [
        "import importlib.util, os, sys",
        "spec = importlib.util.spec_from_file_location('pick_file', sys.argv[1])",
        "module = importlib.util.module_from_spec(spec)",
        "spec.loader.exec_module(module)",
        "module.Gio = None",
        "os.environ['PATH'] = sys.argv[2]",
        "print(module.check())"
    ].join("\n");
    const run = spawnSync("python3", ["-I", "-c", code, SCRIPT, dir], { encoding: "utf8" });
    fs.rmSync(dir, { recursive: true, force: true });
    assert.strictEqual(run.status, 0, run.stderr);
    return Number(run.stdout.trim());
}

test("the check finds zenity when no portal answers, and says no chooser without either", () => {
    assert.strictEqual(checkWith(true), 0);
    assert.strictEqual(checkWith(false), 2);
});
