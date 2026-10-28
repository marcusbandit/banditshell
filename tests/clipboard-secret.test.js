const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/clipboard-secret.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Secret = new Function(src + "\nreturn { HINT, MASK, marked, looksSecret, sensitive, copyCommand };")();

test.describe("clipboard secrets", () => {
    test.it("treats anything the source marked as a password as secret", () => {
        assert.strictEqual(Secret.sensitive({ text: "plain words", types: ["text/plain", "x-kde-passwordManagerHint"] }), true);
        assert.strictEqual(Secret.marked(["text/plain"]), false);
    });

    test.it("spots generated passwords", () => {
        for (const fake of ["Xk9#mP2qLwZ7", "tR4$vN8!eQ2@bH6z", "aB3dE5gH7jK9mN1p"])
            assert.strictEqual(Secret.looksSecret(fake), true, fake);
    });

    test.it("spots tokens and private keys by their shape", () => {
        assert.strictEqual(Secret.looksSecret("gh" + "p_" + "x".repeat(36)), true);
        assert.strictEqual(Secret.looksSecret("sk" + "-" + "y".repeat(40)), true);
        assert.strictEqual(Secret.looksSecret("-----BEGIN OPENSSH PRIVATE KEY-----\nfake\n-----END OPENSSH PRIVATE KEY-----"), true);
    });

    test.it("leaves ordinary copies readable", () => {
        for (const plain of ["hello world", "https://example.com/Path?x=1A2B", "/home/user/File01.txt", "someone@example.com", "123e4567-e89b-12d3-a456-426614174000", "5f4dcc3b5aa765d61d8327deb882cf99", "base64EncodeURL", "v1.2.3-beta", "#FF00AA", "x".repeat(400)])
            assert.strictEqual(Secret.looksSecret(plain), false, plain);
    });

    test.it("never masks pictures or files", () => {
        assert.strictEqual(Secret.sensitive({ file: "/s/Xk9#mP2qLwZ7.png", text: "" }), false);
        assert.strictEqual(Secret.sensitive({ paths: ["/a"], text: "Xk9#mP2qLwZ7" }), false);
    });

    test.it("copies a secret entry back as sensitive when wl-copy can", () => {
        const secret = { text: "Xk9#mP2qLwZ7", types: ["text/plain"] };
        assert.deepStrictEqual(Secret.copyCommand(secret, true), ["wl-copy", "--sensitive", "-n"]);
        assert.deepStrictEqual(Secret.copyCommand(secret, false), ["wl-copy", "-n"]);
        assert.deepStrictEqual(Secret.copyCommand({ text: "plain words", types: [] }, true), ["wl-copy", "-n"]);
    });

    test.it("masks with the same dots as the island's Copied line, whatever the secret's length", () => {
        const moments = fs.readFileSync(path.join(ROOT, "services/moments.js"), "utf8");
        assert.strictEqual(moments.match(/const MASK = "([^"]*)"/)[1], Secret.MASK);
    });
});
