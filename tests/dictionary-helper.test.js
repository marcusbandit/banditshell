const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { execFileSync, spawn } = require("node:child_process");

const ROOT = path.resolve(__dirname, "..");
const HELPER = path.join(ROOT, "scripts", "dictionary.py");

const ENTRIES = {
    goose: { n: { form: ["geese"], pronunciation: [{ value: "ɡuːs", variety: "US" }], sense: [{ id: "goose%1:05:00::", synset: "1-n" }] } },
    run: { v: { sense: [{ id: "run%2:38:00::", synset: "2-v" }, { id: "run%2:38:04::", synset: "3-v" }] } },
    "run out": { v: { sense: [{ id: "run_out%2:30:00::", synset: "4-v" }] } },
    IT: { n: { sense: [{ id: "it%1:09:00::", synset: "7-n" }] } },
    happy: { a: { sense: [{ id: "happy%3:00:00::", synset: "5-a", antonym: ["unhappy%3:00:00::"] }] } }
};

const SYNSETS = {
    "1-n": { definition: ["web-footed water bird"], members: ["goose"], partOfSpeech: "n" },
    "2-v": { definition: ["move fast by using one's feet"], example: ["don't run"], members: ["run"], partOfSpeech: "v" },
    "3-v": { definition: ["flee"], example: [{ text: "run!" }], members: ["run", "scarper", "scat"], partOfSpeech: "v" },
    "4-v": { definition: ["become used up"], members: ["run out"], partOfSpeech: "v" },
    "5-a": { definition: ["enjoying or showing joy"], members: ["happy"], similar: ["6-s"], partOfSpeech: "a" },
    "7-n": { definition: ["information technology"], members: ["IT"], partOfSpeech: "n" },
    "6-s": { definition: ["glad"], members: ["glad"], partOfSpeech: "s" }
};

function makeSource(dir) {
    const zip = path.join(dir, "wordnet.zip");
    execFileSync("python3", ["-I", "-c", `
import json, sys, zipfile
with zipfile.ZipFile(sys.argv[1], "w") as z:
    z.writestr("entries-a.json", sys.argv[2])
    z.writestr("verb.all.json", sys.argv[3])
`, zip, JSON.stringify(ENTRIES), JSON.stringify(SYNSETS)]);
    return zip;
}

function ask(db, words) {
    return new Promise((resolve, reject) => {
        const helper = spawn("python3", ["-I", HELPER, "serve", db]);
        const lines = [];
        let pending = "";
        helper.stdout.on("data", chunk => {
            pending += chunk;
            const parts = pending.split("\n");
            pending = parts.pop();
            lines.push(...parts.filter(Boolean).map(line => JSON.parse(line)));
        });
        helper.on("error", reject);
        helper.on("close", () => resolve(lines));
        words.forEach((word, id) => helper.stdin.write(JSON.stringify({ id, word, complete: true }) + "\n"));
        helper.stdin.end();
    });
}

test.describe("offline dictionary helper", () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), "dictionary-test-"));
    const db = path.join(dir, "cache", "words.sqlite");

    test.after(() => fs.rmSync(dir, { recursive: true, force: true }));

    test.it("builds once, then answers words, forms and prefixes", async () => {
        execFileSync("python3", ["-I", HELPER, "build", db, makeSource(dir)]);
        const said = await ask(db, ["Run", "geese", "running", "ru", "nothing"]);
        assert.deepStrictEqual(said[0], { state: "ready" });
        const [run, geese, running, prefix, nothing] = said.slice(1);
        assert.strictEqual(run.entry.word, "run");
        assert.deepStrictEqual(run.entry.groups[0].senses.map(s => s.text), ["Move fast by using one's feet", "Flee"]);
        assert.deepStrictEqual(run.entry.groups[0].senses[1].synonyms, ["scarper", "scat"]);
        assert.deepStrictEqual(run.entry.groups[0].senses[1].examples, ["run!"]);
        assert.deepStrictEqual(run.completions.map(c => c.word), ["run out"]);
        assert.strictEqual(geese.entry.word, "goose");
        assert.strictEqual(geese.entry.asked, "geese");
        assert.strictEqual(geese.entry.phonetic, "/ɡuːs/");
        assert.strictEqual(running.entry.word, "run");
        assert.deepStrictEqual(prefix.completions.map(c => c.word), ["run", "run out"]);
        assert.strictEqual(nothing.entry, null);
        assert.ok(said.slice(1).every(answer => answer.completed));
    });

    test.it("keeps short stems from landing on unrelated words", async () => {
        const said = await ask(db, ["its", "it"]);
        assert.strictEqual(said[1].entry, null);
        assert.strictEqual(said[2].entry.word, "IT");
    });

    test.it("carries antonyms and similar words", async () => {
        const said = await ask(db, ["happy"]);
        const sense = said[1].entry.groups[0].senses[0];
        assert.deepStrictEqual(sense.antonyms, ["unhappy"]);
        assert.deepStrictEqual(sense.synonyms, ["glad"]);
    });

    test.it("serve-built leaves a missing dictionary alone", () => {
        const missing = path.join(dir, "missing", "words.sqlite");
        let code = 0;
        try {
            execFileSync("python3", ["-I", HELPER, "serve-built", missing], { input: "" });
        } catch (error) {
            code = error.status;
        }
        assert.strictEqual(code, 3);
        assert.strictEqual(fs.existsSync(missing), false);
    });
});
