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

const P = lib("services/plugin-protocol.js", ["submitLine", "formValues", "formMissing", "listed", "readManifest", "environment", "missing", "asked", "queryLine", "activateLine", "completeLine", "cancelLine", "openLine", "closeLine", "readMessage", "readItems", "readShortcut", "chordLabel", "actionOf", "readStatus", "statusLine", "coldLine", "coldId", "notifyAllowed", "enterOf", "plainScore", "crashes", "plainRows", "kept", "updated"]);
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

    test.it("keeps a program running with the shell only when its manifest asks for background", () => {
        assert.deepStrictEqual([manifest({}).plugin.background, manifest({ background: true }).plugin.background, manifest({ background: "yes" }).plugin.background], [false, true, false]);
    });

    test.it("lets a plugin add up to fifty rows to a plain search, three when it does not say", () => {
        assert.deepStrictEqual(manifest({}).plugin.global, { minLength: 3, cap: 9 });
        assert.deepStrictEqual(manifest({ global: { cap: 80 } }).plugin.global, { minLength: 3, cap: 50 });
        assert.deepStrictEqual(manifest({ global: {} }).plugin.global, { minLength: 3, cap: 3 });
    });

    test.it("refuses a manifest that is broken, misnamed, from another api or reaches nothing", () => {
        assert.match(P.readManifest("{", "/p/jira").error, /not JSON/);
        assert.match(manifest({ id: "other" }).error, /folder's name/);
        assert.match(manifest({}, "/p/Jira").error, /folder's name/);
        assert.match(manifest({ api: 4 }).error, /api 4, the shell speaks 1, 2 and 3/);
        assert.strictEqual(manifest({ api: 3 }).plugin.api, 3);
        assert.match(manifest({ exec: "./jira-plugin" }).error, /exec/);
        assert.match(manifest({ prefix: [], global: undefined }).error, /prefix, global, status/);
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
        assert.deepStrictEqual([P.openLine(), P.closeLine()], ['{"type":"open"}', '{"type":"close"}']);
        assert.ok(!P.queryLine(1, "a\nb", false).includes("\n"));
    });
});

test.describe("action shortcuts", () => {
    test.it("reads a chord in any order and case, and draws it the way a person reads it", () => {
        assert.deepStrictEqual([P.readShortcut("ctrl+d"), P.readShortcut("Shift + Ctrl + X"), P.readShortcut("alt+enter"), P.readShortcut("ctrl+f5"), P.readShortcut("")], [{ chord: "CTRL+D" }, { chord: "CTRL+SHIFT+X" }, { chord: "ALT+RETURN" }, { chord: "CTRL+F5" }, { chord: "" }]);
        assert.deepStrictEqual([P.chordLabel("CTRL+SHIFT+X"), P.chordLabel("ALT+RETURN"), P.chordLabel("")], ["Ctrl Shift X", "Alt Enter", ""]);
    });

    test.it("refuses chords that would type, that the launcher uses, or that it cannot read", () => {
        for (const [chord, why] of [["d", /ctrl or alt/], ["shift+d", /ctrl or alt/], ["ctrl+k", /already uses/], ["ctrl+enter", /already uses/], ["ctrl+backspace", /already uses/], ["ctrl+v", /already uses/], ["super+d", /modifiers/], ["ctrl+ctrl+d", /modifiers/], ["ctrl+banana", /not a key/], ["ctrl+shift+/", /shift changes/], ["alt+home", /not a key/], ["ctrl+u", /already uses/], ["ctrl+shift+enter", /already uses/]])
            assert.match(P.readShortcut(chord).refusal, why, chord);
    });

    test.it("keeps the first action that claims a chord, logs the rest, and finds an action by its chord", () => {
        const [item] = P.readItems([{ id: "r", title: "Rule", actions: [
            { id: "dim", title: "Dim", shortcut: "ctrl+d" },
            { id: "drop", title: "Drop", shortcut: "ctrl+d" },
            { id: "copy", title: "Copy", shortcut: "ctrl+c" }
        ] }]);
        assert.deepStrictEqual(item.actions.map(a => a.chord), ["CTRL+D", "", ""]);
        assert.strictEqual(item.notes.length, 2);
        assert.match(item.notes.join("\n"), /Ctrl D on Drop: Dim has it/);
        assert.strictEqual(P.actionOf(item.actions, "CTRL+D").id, "dim");
        assert.strictEqual(P.actionOf(item.actions, ""), null);
    });
});

test.describe("preview facts", () => {
    test.it("reads facts into the preview, text above them, and drops facts with no label", () => {
        const [item] = P.readItems([{ id: "r", title: "Rule", preview: { text: "Spotify", facts: [{ label: "Does", value: "Dims to 15%" }, { value: "no label" }, { label: "Empty" }, { label: "Playing", value: 3 }] } }]);
        assert.deepStrictEqual(item.preview, { facts: [{ label: "Does", value: "Dims to 15%" }, { label: "Playing", value: "3" }], text: "Spotify" });
        const [plain] = P.readItems([{ id: "p", title: "Plain", preview: { text: "Only text", facts: [] } }]);
        assert.deepStrictEqual(plain.preview, { text: "Only text" });
        const [pictured] = P.readItems([{ id: "i", title: "Pic", preview: { image: "/a.png", facts: [{ label: "A", value: "b" }] } }]);
        assert.deepStrictEqual(pictured.preview, { image: "file:///a.png" });
    });
});

test.describe("notify and data", () => {
    test.it("gives the program a data folder of its own only when the shell names a root", () => {
        const { plugin } = manifest({});
        assert.strictEqual(P.environment(plugin, {}, {}, "/s/plugin-data").BANDITSHELL_PLUGIN_DATA, "/s/plugin-data/jira");
        assert.strictEqual(P.environment(plugin, {}, {}).BANDITSHELL_PLUGIN_DATA, undefined);
    });

    test.it("lets a notify through at most once every three seconds", () => {
        assert.deepStrictEqual([P.notifyAllowed(0, 5000), P.notifyAllowed(5000, 7999), P.notifyAllowed(5000, 8000)], [true, false, true]);
    });
});

test.describe("status items", () => {
    const declared = manifest({ status: [{ id: "mic", place: "rail", icon: "mic" }, { id: "held", place: "island" }] }).plugin;

    test.it("reads declared items from the manifest, keeps their programs running and needs no prefix", () => {
        assert.deepStrictEqual(declared.status, [{ id: "mic", place: "rail", title: "Jira", icon: "mic" }, { id: "held", place: "island", title: "Jira", icon: "bug_report" }]);
        assert.strictEqual(declared.background, true);
        assert.strictEqual(manifest({ prefix: [], global: undefined, status: [{ id: "mic", place: "rail" }] }).plugin.id, "jira");
        assert.match(manifest({ status: [{ id: "mic", place: "dock" }] }).error, /rail or island/);
        assert.match(manifest({ status: [1, 2, 3, 4, 5].map(n => ({ id: `s${n}`, place: "rail" })) }).error, /at most 4/);
    });

    test.it("fills an update from its declaration and refuses one plugin.json never declared", () => {
        const { item } = P.readStatus({ id: "mic", tone: "alarm", text: "Spotify dimmed", lines: ["Spotify dimmed", "", "Zen paused"], icon: "Not An Icon" }, declared.status);
        assert.deepStrictEqual([item.title, item.icon, item.tone, item.lines, item.click, item.shown, item.progress], ["Jira", "mic", "alarm", ["Spotify dimmed", "Zen paused"], "menu", true, -1]);
        assert.match(P.readStatus({ id: "other" }, declared.status).error, /does not declare/);
        assert.strictEqual(P.readStatus({ id: "mic", tone: "loud" }, declared.status).item.tone, "plain");
        assert.strictEqual(P.readStatus({ id: "mic", shown: false }, declared.status).item.shown, false);
    });

    test.it("clicks an action, the rows or the rail's menu, and never a menu in the island", () => {
        const acts = [{ id: "undo", title: "Give back" }];
        assert.strictEqual(P.readStatus({ id: "mic", click: "undo", actions: acts }, declared.status).item.click, "undo");
        assert.strictEqual(P.readStatus({ id: "mic", click: "nope" }, declared.status).item.click, "menu");
        assert.strictEqual(P.readStatus({ id: "held", click: "menu" }, declared.status).item.click, "rows");
        assert.deepStrictEqual([P.coldId("plugin:jira:", "plugin:jira:PROJ-41"), P.coldId("plugin:jira:", "plugin:jira:"), P.coldId("plugin:jira:", "plugin:jira:!waiting"), P.coldId("plugin:jira:", "plugin:other:x")], ["PROJ-41", "", "", ""]);
        assert.strictEqual(P.coldLine("PROJ-41"), '{"type":"activate","seq":0,"id":"PROJ-41","action":"","cold":true}');
        assert.strictEqual(P.statusLine("mic", "undo"), '{"type":"activate","seq":0,"id":"mic","action":"undo","status":true}');
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

    test.it("reads the three page kinds and refuses one it does not know", () => {
        const detail = P.readMessage(JSON.stringify({ type: "view", view: { kind: "detail", id: "d", title: "PROJ-41", text: "Login fails", facts: [{ label: "Status", value: "Open" }, { value: "no label" }], actions: [{ id: "assign", title: "Assign" }] } })).view;
        assert.deepStrictEqual([detail.kind, detail.text, detail.facts, detail.actions.map(a => a.id)], ["detail", "Login fails", [{ label: "Status", value: "Open" }], ["assign"]]);
        const list = P.readMessage(JSON.stringify({ type: "view", view: { kind: "list", id: "l", title: "Comments", items: [{ id: "1", title: "First" }, { title: "no id" }] } }), "/p/x").view;
        assert.deepStrictEqual([list.placeholder, list.items.map(i => i.id)], ["Filter", ["1"]]);
        assert.match(P.readMessage('{"type":"view","view":{"kind":"grid","id":"g","title":"G"}}').error, /kind/);
        assert.match(P.readMessage('{"type":"view","view":{"kind":"detail","title":"no id"}}').error, /id and a title/);
    });

    test.it("reads form fields with their starting values, and refuses broken ones", () => {
        const form = P.readMessage(JSON.stringify({ type: "view", view: { kind: "form", id: "new", title: "New issue", fields: [
            { key: "summary", type: "text", title: "Summary", required: true },
            { key: "kind", type: "choice", choices: [{ value: "bug", title: "Bug" }, "task"], value: "task" },
            { key: "urgent", type: "toggle", value: true },
            { key: "token", type: "secret" }
        ] } })).view;
        assert.strictEqual(form.submit, "Submit");
        assert.deepStrictEqual(form.fields[1].choices, [{ value: "bug", title: "Bug" }, { value: "task", title: "task" }]);
        assert.deepStrictEqual(P.formValues(form, { summary: "Crash" }), { summary: "Crash", kind: "task", urgent: true, token: "" });
        assert.deepStrictEqual(P.formMissing(form, {}), ["summary"]);
        assert.match(P.readMessage('{"type":"view","view":{"kind":"form","id":"f","title":"F","fields":[{"key":"a","type":"choice"}]}}').error, /field/);
        assert.match(P.readMessage('{"type":"view","view":{"kind":"form","id":"f","title":"F","fields":[]}}').error, /no fields/);
        assert.strictEqual(P.submitLine("new", { summary: "Crash" }), '{"type":"submit","view":"new","values":{"summary":"Crash"}}');
        assert.strictEqual(P.activateLine(3, "1", "", "comments"), '{"type":"activate","seq":3,"id":"1","action":"","view":"comments"}');
    });

    test.it("filters a list page with the shell's matcher, keeping the plugin's order when nothing is typed", () => {
        const view = P.readMessage(JSON.stringify({ type: "view", view: { kind: "list", id: "l", title: "L", items: [{ id: "a", title: "Zebra" }, { id: "b", title: "Apple" }, { id: "c", title: "Grape", keywords: ["apple"] }] } })).view;
        const place = (label, typed) => Ranking.place(label, typed);
        assert.deepStrictEqual(P.listed(view, "", place).map(i => i.id), ["a", "b", "c"]);
        assert.deepStrictEqual(P.listed(view, "apple", place).map(i => i.id), ["b", "c"]);
    });

    test.it("skips lines that are not JSON, unknown types and views it cannot show", () => {
        assert.match(P.readMessage("hello from print()").error, /not JSON/);
        assert.match(P.readMessage('{"type":"append"}').error, /does not know: append/);
        assert.match(P.readMessage('{"type":"results","items":[]}').error, /seq/);
        assert.match(P.readMessage('{"type":"view","view":{}}').error, /kind/);
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

    test.it("reads tall rows, pictures, tags, props and previews, and keeps QML inside the plugin's folder", () => {
        const [card, drawn, outside] = P.readItems([
            { id: "a", title: "A", height: 20, image: "art/a.png", tags: ["new", 3, ""], text: "Two lines", preview: "Some text", props: { n: 1 } },
            { id: "b", title: "B", qml: "./rows/Row.qml", preview: { qml: "Preview.qml" }, height: "auto" },
            { id: "c", title: "C", qml: "../elsewhere/Row.qml", preview: { qml: "/tmp/Row.qml" }, image: "javascript:x", props: [1] }
        ], "/p/jira");
        assert.deepStrictEqual([card.height, card.image, card.tags, card.preview, card.props], [12, "file:///p/jira/art/a.png", ["new", "3"], { text: "Some text" }, { n: 1 }]);
        assert.deepStrictEqual([drawn.qml, drawn.preview, drawn.height], ["/p/jira/rows/Row.qml", { qml: "/p/jira/Preview.qml" }, 0]);
        assert.deepStrictEqual([outside.qml, outside.preview, outside.image, outside.props, outside.notes.length, outside.height], ["", null, "", {}, 2, 1]);
    });

    test.it("leads plain searches with plugin rows unless told to mix them in or keep them last", () => {
        const items = P.readItems([{ id: "a", title: "Notes app" }, { id: "b", title: "Weather", answer: true }, { id: "c", title: "Zebra" }, { id: "d", title: "Today", pin: true }]);
        const place = (label, typed) => Ranking.place(label, typed);
        const scores = rank => Object.fromEntries(P.plainRows(items, "notes", rank, place).map(m => [m.item.id, m.score]));
        assert.deepStrictEqual(scores("first"), { a: 13, b: 14, d: Infinity });
        assert.deepStrictEqual(scores("mixed"), { a: 3.5, b: 4.5, d: Infinity });
        assert.deepStrictEqual(scores("last"), { a: -1, b: 0, d: Infinity });
        assert.deepStrictEqual(scores("nonsense"), scores("first"));
    });

    test.it("keeps the last rows on screen until the next answer, and updates one row in place", () => {
        const items = P.readItems([{ id: "a", title: "A" }, { id: "b", title: "B" }]);
        assert.deepStrictEqual(P.kept({ items, prefixed: true }, { prefixed: true }), items);
        assert.deepStrictEqual(P.kept({ items, prefixed: true, late: true }, { prefixed: true }), []);
        assert.deepStrictEqual(P.kept({ items, prefixed: false }, { prefixed: true }), []);
        const answered = P.readItems([{ id: "a", title: "4", answer: true }, { id: "b", title: "Today", pin: true }, { id: "c", title: "C" }]);
        assert.deepStrictEqual(P.kept({ items: answered, prefixed: false }, { prefixed: false }).map(i => i.id), ["c"]);
        const update = P.readMessage('{"type":"update","item":{"id":"b","title":"B done"}}');
        assert.deepStrictEqual(P.updated(items, update.item).map(i => i.title), ["A", "B done"]);
        assert.strictEqual(P.updated(items, P.readItems([{ id: "z", title: "Z" }])[0]), null);
        assert.match(P.readMessage('{"type":"update","item":{"title":"no id"}}').error, /update/);
    });

    test.it("waits longer after each crash and switches off after three in a minute", () => {
        assert.deepStrictEqual(P.crashes([], 100000), { recent: [], off: false, delay: 0 });
        assert.deepStrictEqual(P.crashes([1000, 50000], 100000), { recent: [50000], off: false, delay: 1000 });
        assert.strictEqual(P.crashes([60000, 70000], 100000).delay, 2000);
        assert.strictEqual(P.crashes([60000, 70000, 90000], 100000).off, true);
    });
});

function talk(folder, lines, env = {}) {
    const { plugin, error } = P.readManifest(fs.readFileSync(path.join(folder, "plugin.json"), "utf8"), folder);
    assert.ok(plugin, error);
    return new Promise((resolve, reject) => {
        const child = spawn(plugin.exec[0], plugin.exec.slice(1), { cwd: folder, env: Object.assign({ PATH: process.env.PATH }, env, P.environment(plugin, {}, {})) });
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
                answers.push(P.readMessage(buffer.slice(0, at), folder));
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

test("the Python example opens a detail, a list and a form page, and answers the form", async () => {
    const folder = path.join(ROOT, "docs/plugins/examples/hello-python");
    const { answers } = await talk(folder, [
        P.activateLine(1, "greet:ada", "details"),
        P.activateLine(1, "greet:ada", "letters"),
        P.activateLine(1, "greet:ada", "write"),
        P.submitLine("write", { name: "ada", style: "loud", sign: false })
    ]);
    assert.deepStrictEqual(answers.map(a => a.type === "view" ? a.view.kind : a.error || a.do), ["detail", "list", "form", "copy"]);
    assert.deepStrictEqual(answers[1].view.items.map(i => i.title), ["a", "d", "a"]);
    assert.strictEqual(answers[3].text, "HELLO, ADA!");
});

test("the streaks example draws its rows in QML and updates a row in place when it is ticked off", async () => {
    const folder = path.join(ROOT, "docs/plugins/examples/streaks");
    const state = fs.mkdtempSync(path.join(require("node:os").tmpdir(), "streaks-"));
    const { answers } = await talk(folder, [P.queryLine(1, "", true), P.activateLine(1, "read", "toggle")], { XDG_STATE_HOME: state });
    fs.rmSync(state, { recursive: true, force: true });
    const [results, update] = answers;
    assert.deepStrictEqual(results.items.map(i => [i.id, i.height, path.basename(i.qml), i.preview && path.basename(i.preview.qml)]), [["today", 0, "", null], ["read", 1, "StreakRow.qml", "StreakPreview.qml"], ["stretch", 1, "StreakRow.qml", "StreakPreview.qml"], ["drink-water", 1, "StreakRow.qml", "StreakPreview.qml"]]);
    assert.deepStrictEqual([update.type, update.item.id, update.item.props.done, update.item.props.streak], ["update", "read", true, 1]);
});
