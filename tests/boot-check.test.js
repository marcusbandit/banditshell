const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const { classifyLine, scanLog, statusCalls } = require("../scripts/boot-check.js");

test("a TypeError line is one TypeError and nothing else", () => {
    assert.deepStrictEqual(classifyLine('WARN scene: file:///x/modules/panel/PanelWindows.qml:42: TypeError: Property "close" of object is not a function'), ["TypeError"]);
});

test("a TypeError that reads a missing property counts under both classes", () => {
    assert.deepStrictEqual(
        classifyLine("ERROR: file:///x/Y.qml:7: TypeError: Cannot read property 'notifications' of undefined"),
        ["TypeError", "Cannot read property"]
    );
});

test("a moved singleton member reads as a ReferenceError and as not defined", () => {
    assert.deepStrictEqual(
        classifyLine("ERROR: file:///x/Z.qml:9: ReferenceError: Shell is not defined"),
        ["ReferenceError", "is not defined"]
    );
});

test("load failures, bad assignments and binding loops each have their class", () => {
    assert.deepStrictEqual(classifyLine("ERROR: Failed to load configuration"), ["Failed to load"]);
    assert.deepStrictEqual(classifyLine("WARN: file:///x/A.qml:3:5: Unable to assign QString to int"), ["Unable to assign"]);
    assert.deepStrictEqual(classifyLine("WARN: file:///x/A.qml:3:5: QML Item: Binding loop detected for property \"width\""), ["binding loop"]);
});

test("colour escapes do not hide an error", () => {
    assert.deepStrictEqual(classifyLine("\x1b[31mERROR\x1b[0m TypeError: x is not a function"), ["TypeError"]);
});

test("ordinary log lines are clean", () => {
    assert.deepStrictEqual(classifyLine("INFO: Reloaded configuration"), []);
    assert.deepStrictEqual(classifyLine("INFO scene: Launching config in /home/x"), []);
    assert.deepStrictEqual(classifyLine(""), []);
});

test("the known environment lines of a headless private session are ignored", () => {
    const environment = [
        "ERROR: HYPRLAND_INSTANCE_SIGNATURE is not set, Hyprland is not running",
        "WARN: Failed to load Hyprland socket: no Hyprland signature",
        "ERROR: Failed to create pipewire context",
        "WARN quickshell.service.pipewire: TypeError while connecting to pipewire",
        "ERROR: ext-idle-notify-v1 is not defined by the compositor",
        "WARN: Failed to load /tmp/home/Pictures/Wallpapers/dawn.png: No such file or directory",
        "ERROR: wallpaper file does not exist: /home/x/Pictures/a.jpg, Failed to load"
    ];
    for (const line of environment)
        assert.deepStrictEqual(classifyLine(line), [], line);
});

test("a real error that happens to mention a wallpaper module is still caught", () => {
    assert.deepStrictEqual(classifyLine("ERROR: file:///x/modules/wallpaper/Picker.qml:5: TypeError: undefined is not a function"), ["TypeError"]);
});

test("scanLog tallies lines per class and lists each distinct line once", () => {
    const log = [
        "INFO: fine",
        "ERROR: A.qml:1: TypeError: Cannot read property 'a' of undefined",
        "ERROR: A.qml:1: TypeError: Cannot read property 'a' of undefined",
        "ERROR: B.qml:2: ReferenceError: Foo is not defined",
        "ERROR: HYPRLAND_INSTANCE_SIGNATURE is not set"
    ].join("\n");
    const byName = Object.fromEntries(scanLog(log).map(result => [result.name, result]));
    assert.strictEqual(byName.TypeError.count, 2);
    assert.strictEqual(byName.TypeError.distinct.length, 1);
    assert.strictEqual(byName["Cannot read property"].count, 2);
    assert.strictEqual(byName.ReferenceError.count, 1);
    assert.strictEqual(byName["is not defined"].count, 1);
    assert.strictEqual(byName["Failed to load"].count, 0);
    assert.strictEqual(byName["binding loop"].count, 0);
});

test("a clean log scans to zero in every class", () => {
    assert.ok(scanLog("INFO: Reloaded\nINFO: done\n").every(result => result.count === 0));
});

test("status calls are the targets whose status takes no arguments", () => {
    const targets = {
        timer: ["status(): string", "start(duration: string, label: string): string"],
        island: ["status(screen: string): string", "push(id: string): string"],
        zeta: ["status(): string"],
        launcher: ["open(query: string): string", "status(): string"],
        silent: ["toggle(): string"],
        statuses: ["statusline(): string"]
    };
    assert.deepStrictEqual(statusCalls(targets), ["launcher", "timer", "zeta"]);
});

test("the real ipc snapshot yields a status call for the panels and the services it names", () => {
    const targets = JSON.parse(fs.readFileSync(path.join(ROOT, "tests/fixtures/ipc-targets.json"), "utf8"));
    const calls = statusCalls(targets);
    for (const expected of ["launcher", "clipboard", "mode", "quiet", "timer", "wallpaper"])
        assert.ok(calls.includes(expected), expected);
    assert.ok(!calls.includes("island"));
});

test("the calls mode prints one target per line, as the inner script reads them", () => {
    const { execFileSync } = require("node:child_process");
    const out = execFileSync("node", [path.join(ROOT, "scripts/boot-check.js"), "calls", path.join(ROOT, "tests/fixtures/ipc-targets.json")], { encoding: "utf8" });
    const lines = out.trim().split("\n");
    assert.ok(lines.length > 10);
    assert.ok(lines.every(line => /^[a-z]+$/.test(line)));
});
