const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { execFileSync, spawnSync } = require("node:child_process");

const ROOT = path.resolve(__dirname, "..");

const cc = ["cc", "gcc", "clang"].find(name => spawnSync(name, ["--version"]).status === 0);

test.describe("which files the preview reads as text", {skip: cc ? false : "no C compiler"}, () => {
    const scratch = fs.mkdtempSync(path.join(os.tmpdir(), "bs-sniff-"));
    const helper = path.join(scratch, "bs-ls");
    const pdf = Buffer.from("%PDF-1.4\n%\xe2\xe3\xcf\xd3\n1 0 obj\n<< /Type /Catalog >>\nendobj\n", "latin1");

    test.before(() => execFileSync(cc, ["-O2", "-o", helper, path.join(ROOT, "src/bs-ls.c")]));
    test.after(() => fs.rmSync(scratch, {recursive: true, force: true}));

    function stat(name, body) {
        const file = path.join(scratch, name);
        fs.writeFileSync(file, body);
        return JSON.parse(execFileSync(helper, ["--stat", file], {encoding: "utf8"}));
    }

    test.it("never reads a PDF as text, with or without its extension", () => {
        assert.strictEqual(stat("manual.pdf", pdf).text, false);
        assert.strictEqual(stat("scan", pdf).text, false);
    });

    test.it("never reads a known binary kind as text even when its first bytes look like it", () => {
        assert.strictEqual(stat("song.mp3", "ID3 looks like words").text, false);
        assert.strictEqual(stat("report.docx", "PK plain enough").text, false);
    });

    test.it("reads bytes that are not UTF-8 as binary", () => {
        const bytes = Buffer.alloc(400);
        for (let i = 0; i < bytes.length; i++)
            bytes[i] = 0x80 + (i * 37) % 0x7f;
        assert.strictEqual(stat("blob", bytes).text, false);
    });

    test.it("still reads UTF-8 text, accents and a character cut at the end included", () => {
        assert.strictEqual(stat("menu.txt", "Crème brûlée, smørrebrød\n").text, true);
        assert.strictEqual(stat("notes", "plain words\n").text, true);
        const long = Buffer.concat([Buffer.from("é".repeat(2047) + "a"), Buffer.from("€").subarray(0, 2)]);
        assert.strictEqual(stat("cut.txt", long).text, true);
    });
});
