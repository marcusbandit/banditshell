const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");
const { spawn } = require("node:child_process");

const ROOT = path.resolve(__dirname, "..");

function lib(file, names) {
    const src = fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "");
    return new Function(`${src}\nreturn { ${names.join(", ")} };`)();
}

const P = lib("services/plugin-protocol.js", ["readManifest", "environment", "missing", "asked", "queryLine", "activateLine", "completeLine", "cancelLine", "readMessage", "readItems", "enterOf", "plainScore", "crashes"]);
const Ranking = lib("services/ranking.js", ["place"]);

const JIRA = {
    api: 1,
    id: "jira",
    name: "Jira",
    about: "Search your Jira issues",
    icon: "bug_report",
    exec: ["./jira-plugin", "--quiet"],
    prefix: ["jira", "J"],
    global: { minLength: 3, cap: 9 },
    preferences: [
        { key: "site", type: "text", title: "Jira site", placeholder: "acme.atlassian.net", required: true },
        { key: "token", type: "secret", title: "API token" },
        { key: "mine", type: "toggle", title: "Only mine", default: true }
    ]
};

const manifest = (fields, folder = "/p/jira") => P.readManifest(JSON.stringify(Object.assign({}, JIRA, fields)), folder);

test.describe("plugin manifest", () => {
    test.it("reads the manifest from the issue and finds ./ programs in the plugin's folder", () => {
        const { plugin } = manifest({});
        assert.deepStrictEqual([plugin.id, plugin.name, plugin.exec, plugin.prefix, plugin.icon], ["jira", "Jira", ["/p/jira/jira-plugin", "--quiet"], ["jira", "j"], { name: "bug_report" }]);
    });

    test.it("caps what a plugin may add to a plain search at five rows", () => {
        assert.deepStrictEqual(manifest({}).plugin.global, { minLength: 3, cap: 5 });
        assert.deepStrictEqual(manifest({ global: {} }).plugin.global, { minLength: 3, cap: 3 });
    });

    test.it("refuses a manifest that is broken, misnamed, from another api or reaches nothing", () => {
        assert.match(P.readManifest("{", "/p/jira").error, /not JSON/);
        assert.match(manifest({ id: "other" }).error, /folder's name/);
        assert.match(manifest({}, "/p/Jira").error, /folder's name/);
        assert.match(manifest({ api: 2 }).error, /api 2/);
        assert.match(manifest({ exec: "./jira-plugin" }).error, /exec/);
        assert.match(manifest({ prefix: [], global: undefined }).error, /prefix, global/);
        assert.match(manifest({ preferences: [{ key: "a b", type: "text" }] }).error, /preference/);
        assert.match(manifest({ preferences: [{ key: "a", type: "colour" }] }).error, /preference/);
    });

    test.it("hands preferences to the program as environment variables, never a secret to config", () => {
        const { plugin } = manifest({});
        assert.deepStrictEqual(P.environment(plugin, { site: "acme.atlassian.net" }, { token: "s3cret" }), {
            BANDITSHELL_PLUGIN_ID: "jira",
            BANDITSHELL_PLUGIN_DIR: "/p/jira",
            BANDITSHELL_API: "1",
            BANDITSHELL_PREF_SITE: "acme.atlassian.net",
            BANDITSHELL_PREF_TOKEN: "s3cret",
            BANDITSHELL_PREF_MINE: "1"
        });
        assert.strictEqual(P.environment(plugin, { token: "leaked" }, {}).BANDITSHELL_PREF_TOKEN, "");
    });

    test.it("names the required preferences still missing", () => {
        const { plugin } = manifest({});
        assert.deepStrictEqual(P.missing(plugin, {}, {}), ["site"]);
        assert.deepStrictEqual(P.missing(plugin, { site: "x" }, {}), []);
    });
});

test.describe("plugin queries", () => {
    const { plugin } = manifest({});

    test.it("sends what follows a prefix word, and plain searches long enough", () => {
        assert.deepStrictEqual(P.asked(plugin, "jira login bug"), { prefixed: true, text: "login bug", word: "jira" });
        assert.deepStrictEqual(P.asked(plugin, "J  login"), { prefixed: true, text: "login", word: "j" });
        assert.deepStrictEqual(P.asked(plugin, "jira"), { prefixed: true, text: "", word: "jira" });
        assert.deepStrictEqual(P.asked(plugin, "jirafe"), { prefixed: false, text: "jirafe", word: "" });
        assert.strictEqual(P.asked(plugin, "ji"), null);
        assert.strictEqual(P.asked(manifest({ global: undefined }).plugin, "login bug"), null);
    });

    test.it("writes each message as one line of JSON", () => {
        assert.strictEqual(P.queryLine(12, "login bug", true), '{"type":"query","seq":12,"text":"login bug","prefixed":true}');
        assert.strictEqual(P.activateLine(12, "PROJ-41", "open"), '{"type":"activate","seq":12,"id":"PROJ-41","action":"open"}');
        assert.strictEqual(P.completeLine("PROJ-41"), '{"type":"complete","id":"PROJ-41"}');
        assert.strictEqual(P.cancelLine(12), '{"type":"cancel","seq":12}');
        assert.ok(!P.queryLine(1, "a\nb", false).includes("\n"));
    });
});

test.describe("plugin answers", () => {
    test.it("reads results, keeping valid items once each and at most fifty", () => {
        const items = [{ id: "a", title: "A" }, { id: "a", title: "again" }, { title: "no id" }, "junk"];
        for (let i = 0; i < 60; i++)
            items.push({ id: `n${i}`, title: `N${i}` });
        const read = P.readMessage(JSON.stringify({ type: "results", seq: 3, items }));
        assert.strictEqual(read.seq, 3);
        assert.strictEqual(read.items.length, 50);
        assert.deepStrictEqual(read.items.slice(0, 2).map(i => i.id), ["a", "n0"]);
    });

    test.it("finds an item's relative picture in the plugin's folder", () => {
        const read = P.readMessage('{"type":"results","seq":1,"items":[{"id":"a","title":"A","icon":"icons/star.png"},{"id":"b","title":"B","icon":"⭐"}]}', "/p/jira");
        assert.deepStrictEqual(read.items.map(i => i.icon), [{ file: "/p/jira/icons/star.png" }, { glyph: "⭐" }]);
    });

    test.it("skips lines that are not JSON, unknown types and views it cannot show", () => {
        assert.match(P.readMessage("hello from print()").error, /not JSON/);
        assert.match(P.readMessage('{"type":"append"}').error, /does not know: append/);
        assert.match(P.readMessage('{"type":"results","items":[]}').error, /seq/);
        assert.match(P.readMessage('{"type":"view","view":{}}').error, /view/);
    });

    test.it("carries out only the effects it knows, with links it can open safely", () => {
        assert.deepStrictEqual(P.readMessage('{"type":"effect","do":"copy","text":"PROJ-41"}'), { type: "effect", do: "copy", text: "PROJ-41" });
        assert.deepStrictEqual(P.readMessage('{"type":"effect","do":"open","target":"https://x.org"}'), { type: "effect", do: "open", target: "https://x.org" });
        assert.match(P.readMessage('{"type":"effect","do":"open","target":"javascript:alert(1)"}').error, /javascript/);
        assert.match(P.readMessage('{"type":"effect","do":"exec","run":["rm"]}').error, /does not know: exec/);
        assert.deepStrictEqual(P.readMessage('{"type":"effect","do":"close"}'), { type: "effect", do: "close" });
        assert.deepStrictEqual(P.readMessage('{"type":"fill","text":"jira PROJ-41 "}'), { type: "fill", text: "jira PROJ-41 " });
    });

    test.it("does Enter in the shell for open, copy and run, and asks the plugin otherwise", () => {
        const [withOpen, withActions, bare, refused, localAction] = P.readItems([
            { id: "1", title: "T", open: "https://x.org", actions: [{ id: "assign", title: "Assign" }] },
            { id: "2", title: "T", actions: [{ id: "assign", title: "Assign" }, { id: "key", title: "Copy key", copy: "K" }] },
            { id: "3", title: "T" },
            { id: "4", title: "T", open: "notes.txt" },
            { id: "5", title: "T", actions: [{ id: "key", title: "Copy key", copy: "K" }] }
        ]);
        assert.strictEqual(P.enterOf(withOpen).local.open, "https://x.org");
        assert.deepStrictEqual(P.enterOf(withActions), { action: "assign" });
        assert.deepStrictEqual(P.enterOf(bare), { action: "" });
        assert.match(P.enterOf(refused).local.refusal, /not absolute/);
        assert.strictEqual(P.enterOf(localAction).local.copy, "K");
        assert.match(P.readItems([{ id: "r", title: "T", run: "rm -rf ~" }])[0].refusal, /list of strings/);
    });

    test.it("ranks plain-search rows on title over keywords", () => {
        const [byTitle, byKeyword] = P.readItems([{ id: "a", title: "Login" }, { id: "b", title: "Other", keywords: ["login"] }]);
        const place = (label, typed) => Ranking.place(label, typed);
        assert.ok(P.plainScore(byTitle, "login", place) > P.plainScore(byKeyword, "login", place));
        assert.ok(P.plainScore(byTitle, "zebra", place) <= 0);
    });

    test.it("waits longer after each crash and switches off after three in a minute", () => {
        assert.deepStrictEqual(P.crashes([], 100000), { recent: [], off: false, delay: 0 });
        assert.deepStrictEqual(P.crashes([1000, 50000], 100000), { recent: [50000], off: false, delay: 1000 });
        assert.strictEqual(P.crashes([60000, 70000], 100000).delay, 2000);
        assert.strictEqual(P.crashes([60000, 70000, 90000], 100000).off, true);
    });
});

function talk(folder, lines) {
    const { plugin, error } = P.readManifest(fs.readFileSync(path.join(folder, "plugin.json"), "utf8"), folder);
    assert.ok(plugin, error);
    return new Promise((resolve, reject) => {
        const child = spawn(plugin.exec[0], plugin.exec.slice(1), { cwd: folder, env: Object.assign({ PATH: process.env.PATH }, P.environment(plugin, {}, {})) });
        const answers = [];
        let buffer = "";
        const timer = setTimeout(() => {
            child.kill("SIGKILL");
            reject(new Error(`${plugin.id} answered ${answers.length} of ${lines.length}`));
        }, 5000);
        child.stdout.on("data", chunk => {
            buffer += chunk;
            let at;
            while ((at = buffer.indexOf("\n")) >= 0) {
                answers.push(P.readMessage(buffer.slice(0, at)));
                buffer = buffer.slice(at + 1);
            }
            if (answers.length >= lines.length) {
                clearTimeout(timer);
                child.stdin.end();
                resolve({ plugin, answers });
            }
        });
        child.on("error", reject);
        child.stdin.write(lines.map(l => `${l}\n`).join(""));
    });
}

for (const name of ["hello-bash", "hello-python"]) {
    test(`the ${name} example answers a query and a Tab the way the docs say`, async () => {
        const folder = path.join(ROOT, "docs/plugins/examples", name);
        const { plugin, answers } = await talk(folder, [P.queryLine(1, "world", true), P.completeLine("hello:world")]);
        assert.ok(plugin.prefix.length && plugin.global);
        const [results, fill] = answers;
        assert.strictEqual(results.type, "results", results.error);
        assert.strictEqual(results.seq, 1);
        assert.ok(results.items.length >= 1);
        assert.match(results.items[0].title, /world/);
        assert.ok(P.enterOf(results.items[0]).local, "Enter is carried out by the shell");
        assert.deepStrictEqual(fill, { type: "fill", text: `${plugin.prefix[0]} world ` });
    });
}
