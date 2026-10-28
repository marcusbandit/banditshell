const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "modules/controls/certificate-files.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Files = new Function(src + "\nreturn { read, fitting, needsKey };")();
const SCAN = path.join(ROOT, "scripts/certificate-files.sh");
const FIXTURE = fs.readFileSync(path.join(ROOT, "tests/fixtures/certificate-files.txt"), "utf8");

function kinds(files) {
    return Object.fromEntries(files.map(f => [path.basename(f.path), f.kind]));
}

test.describe("certificate files", () => {
    test.it("sorts what openssl read into root, client and key", () => {
        assert.deepStrictEqual(kinds(Files.read(FIXTURE)), {
            "dtu-root-ca-01.pem": "authority",
            "uni-root.der": "authority",
            "uni-root-ca.pem": "authority",
            "old-root.crt": "authority",
            "laptop-17.p12": "client",
            "laptop-17.key": "key",
            "laptop-17.crt": "client",
            "laptop-17-with-key.pem": "client"
        });
    });

    test.it("offers a root certificate only as a root, and a client bundle only as a client", () => {
        const files = Files.read(FIXTURE);
        const roots = Files.fitting(files, "authority", 10).map(p => path.basename(p));
        const clients = Files.fitting(files, "client", 10).map(p => path.basename(p));
        assert.ok(!roots.some(name => /laptop|\.p12$/.test(name)), roots.join());
        assert.ok(!clients.some(name => /root/.test(name)), clients.join());
        assert.deepStrictEqual(Files.fitting(files, "key", 10).map(p => path.basename(p)), ["laptop-17.key"]);
    });

    test.it("asks for a key file only for a client certificate without its own key", () => {
        const files = Files.read(FIXTURE);
        assert.strictEqual(Files.needsKey(files, "/home/me/Downloads/laptop-17.crt"), true);
        assert.strictEqual(Files.needsKey(files, "/home/me/Downloads/laptop-17.p12"), false);
        assert.strictEqual(Files.needsKey(files, "/home/me/Documents/wifi/laptop-17-with-key.pem"), false);
        assert.strictEqual(Files.needsKey(files, "/home/me/elsewhere.pem"), false);
    });

    test.it("keeps the newest first and stops at the limit", () => {
        assert.deepStrictEqual(Files.fitting(Files.read(FIXTURE), "authority", 2), ["/home/me/Documents/dtu-root-ca-01.pem", "/home/me/Downloads/uni-root.der"]);
    });

    test.it("drops a file nothing could be read from", () => {
        assert.ok(!Files.read(FIXTURE).some(f => f.path.endsWith("broken.pem")));
        assert.deepStrictEqual(Files.read(""), []);
    });

    test.it("lists every file even when openssl reads from stdin", () => {
        const dir = fs.mkdtempSync(path.join(os.tmpdir(), "certificate-files-"));
        const bin = path.join(dir, "bin");
        const downloads = path.join(dir, "home", "Downloads");
        fs.mkdirSync(bin);
        fs.mkdirSync(downloads, { recursive: true });
        fs.writeFileSync(path.join(bin, "openssl"), "#!/bin/sh\ncat >/dev/null\nexit 1\n", { mode: 0o755 });
        for (const name of ["a.p12", "b.pem", "c.crt", "d key.key"])
            fs.writeFileSync(path.join(downloads, name), "x");
        const out = spawnSync("/bin/sh", [SCAN], { env: { PATH: `${bin}:/usr/bin:/bin`, HOME: path.join(dir, "home") }, encoding: "utf8", input: "" });
        fs.rmSync(dir, { recursive: true, force: true });
        assert.strictEqual(out.status, 0);
        const listed = out.stdout.split("\x1e").map(r => r.split("\n")[0]).filter(Boolean).map(p => path.basename(p)).sort();
        assert.deepStrictEqual(listed, ["a.p12", "b.pem", "c.crt", "d key.key"]);
    });
});
