const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "modules/controls/certificate-files.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Files = new Function(src + "\nreturn { read, needsKey, roots, clients, keys, locked, carriesKey, shortPath, fullPath, problem };")();
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
            "laptop-17-with-key.pem": "client",
            "laptop-17-locked.key": "key",
            "laptop-17-open.p12": "client",
            "laptop-17-old-export.p12": "client"
        });
    });

    test.it("offers a root certificate only as a root, and a client bundle only as a client", () => {
        const files = Files.read(FIXTURE);
        const now = Date.UTC(2026, 9, 28);
        const roots = Files.roots(files, "", now, 10).map(r => path.basename(r.path));
        const clients = Files.clients(files, now, 10).map(r => path.basename(r.path));
        assert.ok(!roots.some(name => /laptop|\.p12$/.test(name)), roots.join());
        assert.ok(!clients.some(name => /root/.test(name)), clients.join());
        assert.deepStrictEqual(Files.keys(files, 10).map(r => path.basename(r.path)), ["laptop-17.key", "laptop-17-locked.key"]);
    });

    test.it("asks for a key file only for a client certificate without its own key", () => {
        const files = Files.read(FIXTURE);
        assert.strictEqual(Files.needsKey(files, "/home/me/Downloads/laptop-17.crt"), true);
        assert.strictEqual(Files.needsKey(files, "/home/me/Downloads/laptop-17.p12"), false);
        assert.strictEqual(Files.needsKey(files, "/home/me/Documents/wifi/laptop-17-with-key.pem"), false);
        assert.strictEqual(Files.needsKey(files, "/home/me/elsewhere.pem"), false);
    });

    test.it("keeps the newest first and stops at the limit", () => {
        const now = Date.UTC(2026, 9, 28);
        assert.deepStrictEqual(Files.clients(Files.read(FIXTURE), now, 2).map(r => path.basename(r.path)), ["laptop-17.p12", "laptop-17.crt"]);
    });

    test.it("shows each root's issuer and expiry, puts the ones named like the server first and doubtful ones last", () => {
        const now = Date.UTC(2026, 9, 28);
        const list = Files.roots(Files.read(FIXTURE), "uni.edu", now, 10);
        assert.deepStrictEqual(list.map(r => [path.basename(r.path), r.detail, r.warn]), [
            ["uni-root.der", "Uni · until Oct 2036 · named like uni.edu · same as uni-root-ca.pem", false],
            ["uni-root-ca.pem", "Uni · until Oct 2036 · named like uni.edu · same as uni-root.der", false],
            ["dtu-root-ca-01.pem", "Danmarks Tekniske Universitet · until Dec 2040", false],
            ["uni-root-2014.pem", "Uni · expired Jan 2024 · named like uni.edu", true],
            ["old-root.crt", "laptop-17 · until Nov 2026 · not marked as a root", true]
        ]);
    });

    test.it("says what each client certificate holds and which file carries its key", () => {
        const now = Date.UTC(2026, 9, 28);
        assert.deepStrictEqual(Files.clients(Files.read(FIXTURE), now, 10).map(r => [path.basename(r.path), r.detail, r.warn]), [
            ["laptop-17.p12", "holds its key · locked with a password", false],
            ["laptop-17.crt", "laptop-17 · until Oct 2027 · key in laptop-17.key", false],
            ["laptop-17-with-key.pem", "laptop-17 · until Oct 2027 · holds its key", false],
            ["laptop-17-open.p12", "laptop-17 · until Oct 2027 · holds its key", false],
            ["laptop-17-old-export.p12", "laptop-17 · until Oct 2027 · holds its key", false]
        ]);
        assert.match(Files.clients(Files.read(FIXTURE), Date.UTC(2028, 0, 1), 10)[1].detail, /expired Oct 2027/);
    });

    test.it("names the certificate a key belongs to, or says it is locked", () => {
        const files = Files.read(FIXTURE);
        assert.deepStrictEqual(Files.keys(files, 10).map(r => r.detail), ["key for laptop-17.crt", "locked with a password"]);
        const alone = Files.read("\x1e/home/me/Downloads/spare.key\nprivate key\nkey 0123\n");
        assert.deepStrictEqual(Files.keys(alone, 10).map(r => r.detail), ["no certificate here fits it"]);
        const bare = Files.read("\x1e/home/me/Downloads/laptop.crt\nsubject=CN=laptop\nissuer=CN=Uni CA\n    CA:FALSE\npublic 0123\n");
        assert.match(Files.clients(bare, 0, 10)[0].detail, /needs its key file$/);
    });

    test.it("knows a locked bundle or key from one that opens without a password", () => {
        const files = Files.read(FIXTURE);
        assert.strictEqual(Files.locked(files, "/home/me/Downloads/laptop-17.p12"), true);
        assert.strictEqual(Files.locked(files, "/home/me/Downloads/laptop-17-locked.key"), true);
        assert.strictEqual(Files.locked(files, "/home/me/Downloads/laptop-17-open.p12"), false);
        assert.strictEqual(Files.locked(files, "/home/me/Downloads/laptop-17-old-export.p12"), false);
        assert.strictEqual(Files.locked(files, "/home/me/Downloads/laptop-17.key"), false);
        assert.strictEqual(Files.locked(files, "/elsewhere/typed.p12"), false);
    });

    test.it("names a copy only when the copy is in the list too, in either case of openssl's fingerprint label", () => {
        const now = Date.UTC(2026, 9, 28);
        const files = Files.read(FIXTURE);
        const shown = Files.roots(files, "dtu.dk", now, 2);
        assert.deepStrictEqual(shown.map(r => path.basename(r.path)), ["dtu-root-ca-01.pem", "uni-root.der"]);
        assert.ok(!shown[1].detail.includes("same as"), shown[1].detail);
        const older = Files.read(FIXTURE.replace(/^sha256 Fingerprint=/gm, "SHA256 Fingerprint="));
        assert.match(Files.roots(older, "uni.edu", now, 2)[0].detail, /same as uni-root-ca\.pem$/);
    });

    test.it("matches a root to a server under the school's name, past a shared second level", () => {
        const now = Date.UTC(2026, 9, 28);
        const files = Files.read(FIXTURE);
        assert.strictEqual(path.basename(Files.roots(files, "radius.dtu.dk", now, 1)[0].path), "dtu-root-ca-01.pem");
        assert.match(Files.roots(files, "wifi.uni.ac.uk", now, 1)[0].detail, /named like wifi\.uni\.ac\.uk/);
        assert.ok(!Files.roots(files, "", now, 10).some(r => r.detail.includes("named like")));
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
        assert.strictEqual(Files.roots(files, "radius.tu-berlin.de", now, 1)[0].detail, "TU-Berlin, Inc. · until Jan 2035 · named like radius.tu-berlin.de");
        assert.ok(!Files.roots(files, "wifi.it.dk", now, 10).some(r => r.detail.includes("named like")));
    });

    test.it("shows a picked file under home with a tilde and expands it back", () => {
        assert.strictEqual(Files.shortPath("/home/me/Downloads/uni-root.der", "/home/me"), "~/Downloads/uni-root.der");
        assert.strictEqual(Files.shortPath("/home/meg/x.pem", "/home/me"), "/home/meg/x.pem");
        assert.strictEqual(Files.fullPath(" ~/Downloads/uni-root.der ", "/home/me/"), "/home/me/Downloads/uni-root.der");
        assert.strictEqual(Files.fullPath("/etc/ssl/a.pem", "/home/me"), "/etc/ssl/a.pem");
    });

    test.it("says why a picked file cannot be used for its field", () => {
        const now = Date.UTC(2026, 9, 28);
        const files = Files.read(FIXTURE);
        assert.strictEqual(Files.problem(files, "/home/me/Downloads/uni-root-2014.pem", "authority", now), "uni-root-2014.pem expired in Jan 2024.");
        assert.strictEqual(Files.problem(files, "/home/me/Downloads/laptop-17.crt", "authority", now), "laptop-17.crt is not a root certificate.");
        assert.strictEqual(Files.problem(files, "/home/me/Downloads/uni-root.der", "authority", now), "");
        assert.strictEqual(Files.problem(files, "/home/me/Downloads/uni-root.der", "client", now), "uni-root.der is a root certificate, not one issued to you.");
        assert.strictEqual(Files.problem(files, "/home/me/Downloads/laptop-17.key", "client", now), "laptop-17.key is a key, not a certificate.");
        assert.strictEqual(Files.problem(files, "/home/me/Downloads/laptop-17.crt", "key", now), "laptop-17.crt holds no key.");
        assert.strictEqual(Files.problem(files, "/home/me/Downloads/laptop-17.key", "key", now), "");
        assert.strictEqual(Files.problem(files, "/elsewhere/typed.pem", "authority", now), "");
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
