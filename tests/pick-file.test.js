const test = require("node:test");
const assert = require("node:assert");
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
