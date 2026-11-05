const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/lock-pam.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Pam = new Function(src + "\nreturn { service, stack, directory, file };")();
const lock = fs.readFileSync(path.join(ROOT, "services/Lock.qml"), "utf8");

test.describe("lock screen PAM stack", () => {
    test.it("lives in the session's runtime folder, never in the checkout", () => {
        assert.strictEqual(Pam.directory("/run/user/1000"), "/run/user/1000/banditshell/pam.d");
        assert.strictEqual(Pam.file("/run/user/1000"), "/run/user/1000/banditshell/pam.d/banditshell");
        assert.strictEqual(Pam.directory(""), "");
        assert.strictEqual(Pam.file(""), "");
        assert.doesNotMatch(lock, /configDirectory:.*shellPath/);
        assert.match(lock, /configDirectory: LockPam\.directory\(root\.pamRoom\)/);
        assert.match(lock, /config: LockPam\.service/);
    });

    test.it("is written again right before every password check", () => {
        const check = lock.slice(lock.indexOf("function check("), lock.indexOf("function next("));
        assert.match(check, /root\.placeStack\(\) \|\| !pam\.start\(\)/);
        assert.match(lock, /pamStack\.setText\(LockPam\.stack\)/);
        assert.match(lock, /id: pamStack[\s\S]*?blockWrites: true/);
    });

    test.it("only asks whether this is the logged in person", () => {
        const lines = Pam.stack.split("\n").filter(Boolean);
        assert.deepStrictEqual(lines, ["auth required pam_unix.so nullok nodelay"]);
        assert.doesNotMatch(Pam.stack, /include|pam_nologin|pam_shells|pam_faillock/);
    });

    test.it("ships no PAM file the shell would read from the checkout", () => {
        assert.strictEqual(fs.existsSync(path.join(ROOT, "assets/pam.d")), false);
    });
});
