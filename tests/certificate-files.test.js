const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "modules/controls/certificate-files.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Files = new Function(src + "\nreturn { read, fitting, needsKey, roots, carriesKey };")();
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
            "uni-root-2014.pem": "authority",
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

    test.it("shows each root's issuer and expiry, puts the ones naming the server first and expired ones last", () => {
        const now = Date.UTC(2026, 9, 28);
        const list = Files.roots(Files.read(FIXTURE), "uni.edu", now, 10);
        assert.deepStrictEqual(list.map(r => [path.basename(r.path), r.detail, r.warn]), [
            ["uni-root.der", "Uni · until Oct 2036 · matches uni.edu", false],
            ["uni-root-ca.pem", "Uni · until Oct 2036 · matches uni.edu", false],
            ["dtu-root-ca-01.pem", "Danmarks Tekniske Universitet · until Dec 2040", false],
            ["old-root.crt", "laptop-17 · until Nov 2026", false],
            ["uni-root-2014.pem", "Uni · expired Jan 2024 · matches uni.edu", true]
        ]);
    });

    test.it("matches a root to a server under the school's name, past a shared second level", () => {
        const now = Date.UTC(2026, 9, 28);
        const files = Files.read(FIXTURE);
        assert.strictEqual(path.basename(Files.roots(files, "radius.dtu.dk", now, 1)[0].path), "dtu-root-ca-01.pem");
        assert.match(Files.roots(files, "wifi.uni.ac.uk", now, 1)[0].detail, /matches wifi\.uni\.ac\.uk$/);
        assert.ok(!Files.roots(files, "", now, 10).some(r => r.detail.includes("matches")));
    });

    test.it("keeps a comma inside an issuer name, and matches a hyphenated school but not a two-letter one", () => {
        const now = Date.UTC(2026, 9, 28);
        const text = [
            "\x1e/home/me/Downloads/tub.pem",
            "subject=C=DE, O=TU-Berlin, Inc., CN=TUB Root",
            "issuer=C=DE, O=TU-Berlin, Inc., CN=TUB Root",
            "notAfter=Jan  1 00:00:00 2035 GMT",
            "    CA:TRUE",
            "\x1e/home/me/Downloads/it.pem",
            "subject=O=IT Services, CN=IT Root",
            "issuer=O=IT Services, CN=IT Root",
            "    CA:TRUE",
            ""
        ].join("\n");
        const files = Files.read(text);
        assert.strictEqual(Files.roots(files, "radius.tu-berlin.de", now, 1)[0].detail, "TU-Berlin, Inc. · until Jan 2035 · matches radius.tu-berlin.de");
        assert.ok(!Files.roots(files, "wifi.it.dk", now, 10).some(r => r.detail.includes("matches")));
    });

    test.it("knows when the picked certificate carries its own key", () => {
        const files = Files.read(FIXTURE);
        assert.strictEqual(Files.carriesKey(files, "/home/me/Documents/wifi/laptop-17-with-key.pem"), true);
        assert.strictEqual(Files.carriesKey(files, "/home/me/Downloads/laptop-17.p12"), true);
        assert.strictEqual(Files.carriesKey(files, "/home/me/Downloads/laptop-17.crt"), false);
        assert.strictEqual(Files.carriesKey(files, "/elsewhere/bundle.pfx"), true);
        assert.strictEqual(Files.carriesKey(files, "/elsewhere/cert.pem"), false);
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
