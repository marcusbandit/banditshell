const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/lock-pam.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Pam = new Function(src + "\nreturn { service, stack, faceService, faceStack, faceModules, directory, file, findFace };")();

test.describe("lock screen PAM stack", () => {
    test.it("lives in the session's runtime folder, never in the checkout", () => {
        assert.strictEqual(Pam.directory("/run/user/1000"), "/run/user/1000/banditshell/pam.d");
        assert.strictEqual(Pam.file("/run/user/1000"), "/run/user/1000/banditshell/pam.d/banditshell");
        assert.strictEqual(Pam.directory(""), "");
        assert.strictEqual(Pam.file(""), "");
    });

    test.it("only asks whether this is the logged in person", () => {
        const lines = Pam.stack.split("\n").filter(Boolean);
        assert.deepStrictEqual(lines, ["auth required pam_unix.so nullok nodelay"]);
        assert.doesNotMatch(Pam.stack, /include|pam_nologin|pam_shells|pam_faillock/);
    });

    test.it("keeps the face check in a file of its own beside the password's", () => {
        assert.strictEqual(Pam.file("/run/user/1000", Pam.faceService), "/run/user/1000/banditshell/pam.d/banditshell-face");
        assert.notStrictEqual(Pam.faceService, Pam.service);
        assert.strictEqual(Pam.file("", Pam.faceService), "");
    });

    test.it("asks howdy alone for a face, and nothing else", () => {
        const lines = Pam.faceStack.split("\n").filter(Boolean);
        assert.deepStrictEqual(lines, ["auth required pam_howdy.so"]);
        assert.doesNotMatch(Pam.faceStack, /include|pam_unix|pam_permit|workaround/);
    });

    test.it("looks for howdy only where PAM keeps its modules", () => {
        assert.ok(Pam.faceModules.length > 0);
        for (const module of Pam.faceModules)
            assert.match(module, /^\/(usr\/)?lib[^/]*(\/[a-z0-9_-]+-linux-gnu)?\/security\/pam_howdy\.so$/);
        const command = Pam.findFace();
        assert.deepStrictEqual(command.slice(-Pam.faceModules.length), Pam.faceModules);
        assert.strictEqual(command[0], "sh");
    });

    test.it("ships no PAM file the shell would read from the checkout", () => {
        assert.strictEqual(fs.existsSync(path.join(ROOT, "assets/pam.d")), false);
    });
});
