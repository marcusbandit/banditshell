const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/whatsnew.js"), "utf8");
const WhatsNew = new Function(src
    + "\nreturn { parse, accumulated, severityOf, readSeen, lastSeen, legacyToMove, newestId, newestRelease, nextRelease, entriesSince, releaseNotes, sections, shortList, unreadCount, TYPES, IMPACT_KEYS };")();

const log = [
    { id: "third", date: "2026-09-03", changes: [{ type: "bugs", severity: "minor", text: "Fixed the thing." }] },
    { id: "skipped", date: "2026-09-02", changes: [{ type: "ui", severity: "minor", text: "Moved the other thing." }] },
    { id: "first", date: "2026-09-01", changes: [{ type: "features", severity: "major", text: "Added the thing; run the migration." }] }
];

test("the shipped log parses and is well formed", () => {
    const file = fs.readFileSync(path.join(ROOT, "docs/whats-new.json"), "utf8");
    const parsed = WhatsNew.parse(file);
    assert.ok(parsed.length > 0, "the shipped log must not parse empty");
    const ids = parsed.map(e => e.id);
    assert.strictEqual(new Set(ids).size, ids.length, "ids are not unique");
    for (const e of parsed) {
        assert.strictEqual(typeof e.id, "string");
        for (const c of e.changes) {
            assert.strictEqual(typeof c.text, "string");
            assert.ok(c.text.length > 0);
            assert.strictEqual(typeof c.type, "string");
            assert.ok(["major", "minor"].includes(c.severity));
        }
    }
});

test("every shipped line is one short bullet", () => {
    const doc = JSON.parse(fs.readFileSync(path.join(ROOT, "docs/whats-new.json"), "utf8"));
    const long = doc.entries.flatMap(e => e.changes.filter(c => c.text.length > 70).map(c => `${e.id}: ${c.text}`));
    assert.deepStrictEqual(long, [], "a change is 70 characters at most, see docs/agents/whats-new.md");
});

function impactProblems(raw) {
    if (!raw || typeof raw !== "object" || Array.isArray(raw))
        return ["impact is not an object"];
    const problems = Object.keys(raw).filter(k => !WhatsNew.IMPACT_KEYS.includes(k)).map(k => `unknown key ${k}`);
    for (const flag of ["restart", "cli"])
        if (flag in raw && typeof raw[flag] !== "boolean")
            problems.push(`${flag} is not true or false`);
    for (const list of ["binds", "deps"])
        if (list in raw && !(Array.isArray(raw[list]) && raw[list].every(s => typeof s === "string" && s.trim())))
            problems.push(`${list} is not a list of names`);
    return problems;
}

test("the shipped log keeps impact to its documented shape", () => {
    const doc = JSON.parse(fs.readFileSync(path.join(ROOT, "docs/whats-new.json"), "utf8"));
    for (const e of doc.entries)
        if ("impact" in e)
            assert.deepStrictEqual(impactProblems(e.impact), [], e.id);
});

test("the impact validator rejects what the loader would quietly drop", () => {
    assert.deepStrictEqual(impactProblems({ restart: true, cli: false, binds: ["launcher.toggle"], deps: ["fd"] }), []);
    assert.deepStrictEqual(impactProblems({}), []);
    assert.deepStrictEqual(impactProblems({ restart: "yes" }), ["restart is not true or false"]);
    assert.deepStrictEqual(impactProblems({ binds: "x" }), ["binds is not a list of names"]);
    assert.deepStrictEqual(impactProblems({ colour: 1 }), ["unknown key colour"]);
    assert.deepStrictEqual(impactProblems([]), ["impact is not an object"]);
});

test("impact is read when present and null when not", () => {
    const parsed = WhatsNew.parse(JSON.stringify([
        { id: "with", changes: [{ text: "x" }], impact: { restart: true, binds: ["a", 1, " b "], deps: "no" } },
        { id: "without", changes: [{ text: "x" }] },
        { id: "wrong", changes: [{ text: "x" }], impact: [1] }
    ]));
    assert.deepStrictEqual(parsed[0].impact, { restart: true, cli: false, binds: ["a", "b"], deps: [] });
    assert.strictEqual(parsed[1].impact, null);
    assert.strictEqual(parsed[2].impact, null);
});

test("garbage parses as an empty log, not a throw", () => {
    assert.deepStrictEqual(WhatsNew.parse(""), []);
    assert.deepStrictEqual(WhatsNew.parse("not json at all"), []);
    assert.deepStrictEqual(WhatsNew.parse('{"no": "entries here"}'), []);
    assert.deepStrictEqual(WhatsNew.parse("null"), []);
    assert.deepStrictEqual(WhatsNew.parse(undefined), []);
});

test("a bare array is accepted beside the entries wrapper", () => {
    assert.deepStrictEqual(WhatsNew.parse(JSON.stringify(log)), WhatsNew.parse(JSON.stringify({ entries: log })));
});

test("malformed entries are dropped, not repaired", () => {
    const parsed = WhatsNew.parse(JSON.stringify([
        "a string is not an entry",
        { date: "2026-09-01", changes: [] },
        { id: "  ", changes: [] },
        { id: "kept", changes: [{ text: "   " }, { type: "bugs", text: "kept with its text" }] }
    ]));
    assert.strictEqual(parsed.length, 1);
    assert.strictEqual(parsed[0].id, "kept");
    assert.strictEqual(parsed[0].changes.length, 1);
    assert.strictEqual(parsed[0].changes[0].text, "kept with its text");
});

test("an entry without readable changes survives as a marker waypoint", () => {
    const parsed = WhatsNew.parse(JSON.stringify([{ id: "silent" }, { id: "after", changes: [{ type: "bugs", text: "Fixed." }] }]));
    assert.strictEqual(parsed.length, 2);
    assert.deepStrictEqual(parsed[0].changes, []);
});

test("an unknown severity reads Minor and an unknown type is kept", () => {
    const parsed = WhatsNew.parse(JSON.stringify([{ id: "e", changes: [
        { type: "something-new", severity: "catastrophic", text: "Said plainly." }
    ]}]));
    assert.strictEqual(parsed[0].changes[0].type, "something-new");
    assert.strictEqual(parsed[0].changes[0].severity, "minor");
});

test("an empty marker accumulates everything", () => {
    assert.deepStrictEqual(WhatsNew.accumulated(log, ""), log);
    assert.deepStrictEqual(WhatsNew.accumulated(log, null), log);
});

test("the marker stops the walk, and everything newer accumulates", () => {
    const pending = WhatsNew.accumulated(log, "skipped");
    assert.deepStrictEqual(pending.map(e => e.id), ["third"]);
    assert.deepStrictEqual(WhatsNew.accumulated(log, "first").map(e => e.id), ["third", "skipped"]);
});

test("a marker naming the newest entry accumulates nothing", () => {
    assert.deepStrictEqual(WhatsNew.accumulated(log, "third"), []);
});

test("a marker the log no longer contains shows everything", () => {

    assert.deepStrictEqual(WhatsNew.accumulated(log, "trimmed-away"), log);
});

test("a marker newer than the whole log, as after going back a version, shows nothing", () => {
    const dated = [
        { id: "2026-10-24-2", date: "2026-10-24", changes: [{ type: "ui", severity: "minor", text: "Two." }] },
        { id: "2026-10-24", date: "2026-10-24", changes: [{ type: "ui", severity: "minor", text: "One." }] }
    ];
    assert.deepStrictEqual(WhatsNew.accumulated(dated, "2026-10-25"), []);
    assert.deepStrictEqual(WhatsNew.accumulated(dated, "2026-10-24-3"), []);
    assert.deepStrictEqual(WhatsNew.accumulated(dated, "2026-10-23").map(e => e.id), ["2026-10-24-2", "2026-10-24"]);
    assert.deepStrictEqual(WhatsNew.accumulated(dated, "2026-10-24").map(e => e.id), ["2026-10-24-2"]);
});

test("several skipped pushes accumulate together, newest first", () => {
    const pending = WhatsNew.accumulated(log, "first");
    assert.deepStrictEqual(pending.map(e => e.id), ["third", "skipped"]);
});

test("examples never surface and never stop the walk", () => {
    const withExample = [{ id: "example", date: "", example: true, changes: [{ type: "ui", text: "Shape only." }] }, ...log];
    assert.deepStrictEqual(WhatsNew.accumulated(withExample, ""), log);
    assert.deepStrictEqual(WhatsNew.accumulated(withExample, "skipped").map(e => e.id), ["third"]);
});

test("entries with nothing to show are skipped but do not eat the marker", () => {

    const silent = [{ id: "silent", date: "2026-09-04", changes: [] }, ...log];
    assert.deepStrictEqual(WhatsNew.accumulated(silent, ""), log);
    assert.deepStrictEqual(WhatsNew.accumulated(silent, "silent").map(e => e.id), ["third", "skipped", "first"]);
});

test("an empty log accumulates nothing", () => {
    assert.deepStrictEqual(WhatsNew.accumulated([], ""), []);
    assert.deepStrictEqual(WhatsNew.accumulated(WhatsNew.parse("{}"), ""), []);
});

test("an entry is Major when any change in it is", () => {
    assert.strictEqual(WhatsNew.severityOf(log[0]), "minor");
    assert.strictEqual(WhatsNew.severityOf(log[2]), "major");
    assert.strictEqual(WhatsNew.severityOf({ id: "e", changes: [] }), "minor");
    assert.strictEqual(WhatsNew.severityOf(undefined), "minor");
});

test("the seen mark is the first line of the state file, trimmed", () => {
    assert.strictEqual(WhatsNew.readSeen("third\n"), "third");
    assert.strictEqual(WhatsNew.readSeen("  third  \nignored"), "third");
    assert.strictEqual(WhatsNew.readSeen(""), "");
    assert.strictEqual(WhatsNew.readSeen(undefined), "");
});

test("the state file wins over the old config key, which stands in until it is moved", () => {
    assert.strictEqual(WhatsNew.lastSeen("new\n", "old"), "new");
    assert.strictEqual(WhatsNew.lastSeen("", "old"), "old");
    assert.strictEqual(WhatsNew.lastSeen("", ""), "");
    assert.deepStrictEqual(WhatsNew.accumulated(log, WhatsNew.lastSeen("", "first")).map(e => e.id), ["third", "skipped"]);
});

test("the old config key moves once, and only when the state file has no mark", () => {
    assert.strictEqual(WhatsNew.legacyToMove("", "old"), "old");
    assert.strictEqual(WhatsNew.legacyToMove("", ""), "");
    assert.strictEqual(WhatsNew.legacyToMove("new\n", "old"), "");
});

test("the version is the newest real entry's id, the example skipped", () => {
    assert.strictEqual(WhatsNew.newestId(log), "third");
    assert.strictEqual(WhatsNew.newestId([{ id: "shape", example: true, changes: [] }, { id: "2026-10-17", changes: [] }]), "2026-10-17");
    assert.strictEqual(WhatsNew.newestId([{ id: "shape", example: true, changes: [] }]), "");
    assert.strictEqual(WhatsNew.newestId([]), "");
    assert.strictEqual(WhatsNew.newestId(undefined), "");
});

test("the newest release is the highest semver tag, by number and not by text", () => {
    assert.strictEqual(WhatsNew.newestRelease(["v0.9.3", "v0.10.0", "v0.2.1", ""]), "v0.10.0");
    assert.strictEqual(WhatsNew.newestRelease(["v2026.10.17-3", "v0.1.0-rc1", "0.4.0", "v01.0.0", "v0.1.0"]), "v0.1.0");
    assert.strictEqual(WhatsNew.newestRelease(["nope"]), "");
    assert.strictEqual(WhatsNew.newestRelease([]), "");
});

test("the next release is minor for a feature, patch for fixes only, none for nothing", () => {
    assert.deepStrictEqual(WhatsNew.nextRelease("v0.1.0", ["fix(island): a (#3)", "feat(files): b (#4)"]), { tag: "v0.2.0", bump: "minor" });
    assert.deepStrictEqual(WhatsNew.nextRelease("v0.2.5", ["fix(island): a", "docs: b", "chore: c", "perf(x): d"]), { tag: "v0.2.6", bump: "patch" });
    assert.deepStrictEqual(WhatsNew.nextRelease("v0.2.5", ["refactor(x)!: a breaking change"]), { tag: "v0.3.0", bump: "minor" });
    assert.deepStrictEqual(WhatsNew.nextRelease("v0.2.5", ["Merge branch x", "featherweight: not a feat"]), { tag: "v0.2.6", bump: "patch" });
    assert.deepStrictEqual(WhatsNew.nextRelease("v1.4.2", ["feat: c"]), { tag: "v1.5.0", bump: "minor" });
    assert.deepStrictEqual(WhatsNew.nextRelease("v1.4.2", ["fix: a", "feat(x)!: c"]), { tag: "v2.0.0", bump: "major" });
    assert.deepStrictEqual(WhatsNew.nextRelease("", ["fix: a"]), { tag: "v0.1.0", bump: "first" });
    assert.strictEqual(WhatsNew.nextRelease("v0.1.0", []), null);
    assert.strictEqual(WhatsNew.nextRelease("v0.1.0", ["", "  "]), null);
});

test("release notes list only entries the last release did not have, by section", () => {
    const entry = (id, ...changes) => ({ id, changes: changes.map(([type, text, severity]) => ({ type, text, severity: severity ?? "minor" })) });
    const before = JSON.stringify({ entries: [entry("2026-10-20", ["features", "Old thing"])] });
    const after = JSON.stringify({ entries: [
        { id: "shape", example: true, changes: [{ type: "ui", severity: "minor", text: "Example" }] },
        entry("2026-10-22", ["bugs", "Fixed thing"], ["config", "Renamed key", "major"]),
        entry("2026-10-21", ["features", "New thing"]),
        entry("2026-10-20", ["features", "Old thing"])
    ] });
    const got = WhatsNew.entriesSince(before, after);
    assert.deepStrictEqual(got.map(e => e.id), ["2026-10-22", "2026-10-21"]);
    assert.strictEqual(WhatsNew.releaseNotes(got, false), "## Big changes\n\n- Renamed key\n\n## New\n\n- New thing\n\n## Fixed\n\n- Fixed thing\n");
    assert.match(WhatsNew.releaseNotes([], false), /nothing you will notice/);
    assert.match(WhatsNew.releaseNotes([], true), /first numbered release/);
});

test("sections put big changes first and fold minor ones by kind across updates", () => {
    const got = WhatsNew.sections([
        { changes: [{ type: "ui", severity: "minor", text: "A" }, { type: "issues", severity: "minor", text: "B" }] },
        { changes: [{ type: "bugs", severity: "minor", text: "C" }, { type: "config", severity: "major", text: "D" }, { type: "odd", text: "E" }, { type: "ui", text: "A" }] }
    ]);
    assert.deepStrictEqual(got.map(s => [s.key, s.changes.map(c => c.text)]), [
        ["major", ["D"]],
        ["ui", ["A", "A"]],
        ["bugs", ["B", "C"]],
        ["other", ["E"]]
    ]);
});

test("a few changes read as one tagged list in section order, and a long log keeps its sections", () => {
    const few = WhatsNew.shortList([
        { changes: [{ type: "bugs", severity: "minor", text: "Fixed thing" }, { type: "features", severity: "minor", text: "New thing" }] },
        { changes: [{ type: "ui", severity: "major", text: "Big thing" }] }
    ]);
    assert.deepStrictEqual(few, [
        { key: "major", tag: "Big", text: "Big thing", unread: false },
        { key: "features", tag: "New", text: "New thing", unread: false },
        { key: "bugs", tag: "Fixed", text: "Fixed thing", unread: false }
    ]);
    const many = Array.from({ length: 7 }, (_, i) => ({ type: "bugs", severity: "minor", text: `Fix ${i}` }));
    assert.deepStrictEqual(WhatsNew.shortList([{ changes: many }]), []);
    assert.strictEqual(WhatsNew.shortList([{ changes: many.slice(0, 6) }]).length, 6);
});

test("changes from entries not read yet are marked unread, in both lists, and counted", () => {
    const log = [
        { id: "2026-11-04", changes: [{ type: "ui", severity: "minor", text: "Newest" }] },
        { id: "2026-11-03", changes: [{ type: "bugs", severity: "minor", text: "Older" }, { type: "bugs", severity: "minor", text: "Older too" }] }
    ];
    const pending = [log[0]];
    assert.deepStrictEqual(WhatsNew.shortList(log, pending).map(l => [l.text, l.unread]), [["Newest", true], ["Older", false], ["Older too", false]]);
    assert.deepStrictEqual(WhatsNew.sections(log, ["2026-11-03"]).map(s => s.changes.map(c => c.unread)), [[false], [true, true]]);
    assert.strictEqual(WhatsNew.unreadCount(WhatsNew.shortList(log, pending), []), 1);
    assert.strictEqual(WhatsNew.unreadCount([], WhatsNew.sections(log, log)), 3);
    assert.strictEqual(WhatsNew.unreadCount(WhatsNew.shortList(log, []), []), 0);
    assert.strictEqual(WhatsNew.unreadCount(), 0);
});
