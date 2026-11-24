const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/lock-pam.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Pam = new Function(src + "\nreturn { service, stack, faceService, faces, faceStack, faceModules, faceOf, directory, file, findFace };")();

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

    test.it("tries Gaze first and falls back to howdy when Gaze cannot see you", () => {
        assert.strictEqual(Pam.faceStack(["gaze", "howdy"]), "auth sufficient pam_gaze.so\nauth required pam_howdy.so\n");
    });

    test.it("asks one face module alone when only one is wanted", () => {
        assert.strictEqual(Pam.faceStack(["gaze"]), "auth required pam_gaze.so\n");
        assert.strictEqual(Pam.faceStack(["howdy"]), "auth required pam_howdy.so\n");
    });

    test.it("never writes a face file that could open without a face", () => {
        assert.strictEqual(Pam.faceStack([]), "");
        assert.strictEqual(Pam.faceStack(undefined), "");
        assert.strictEqual(Pam.faceStack(["permit"]), "");
        assert.strictEqual(Pam.faceStack(["unix", "howdy"]), "auth required pam_howdy.so\n");
        assert.doesNotMatch(Pam.faceStack(["gaze", "howdy"]), /include|pam_unix|pam_permit|workaround|optional/);
    });

    test.it("looks for face modules only where PAM keeps its modules", () => {
        const modules = Pam.faceModules();
        assert.ok(modules.length > 0);
        for (const module of modules) {
            assert.match(module, /^\/(usr\/)?lib[^/]*(\/[a-z0-9_-]+-linux-gnu)?\/security\/pam_(gaze|howdy)\.so$/);
            assert.ok(Pam.faces.indexOf(Pam.faceOf(module)) >= 0, module);
        }
        const command = Pam.findFace();
        assert.deepStrictEqual(command.slice(-modules.length), modules);
        assert.strictEqual(command[0], "sh");
    });

    test.it("reads which face module a found path is", () => {
        assert.strictEqual(Pam.faceOf("/usr/lib/security/pam_gaze.so"), "gaze");
        assert.strictEqual(Pam.faceOf("/lib/x86_64-linux-gnu/security/pam_howdy.so"), "howdy");
        assert.strictEqual(Pam.faceOf("/usr/lib/security/pam_unix.so"), "");
        assert.strictEqual(Pam.faceOf(""), "");
    });

    test.it("ships no PAM file the shell would read from the checkout", () => {
        assert.strictEqual(fs.existsSync(path.join(ROOT, "assets/pam.d")), false);
    });
});
