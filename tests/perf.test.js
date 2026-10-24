const test = require("node:test");
const assert = require("node:assert");
const path = require("node:path");

const Perf = require(path.resolve(__dirname, "../scripts/perf.js"));

test.describe("stats", () => {
    test.it("keeps the first and last run apart from the mean", () => {
        const s = Perf.stats([90, 10, 10, 10, 30]);
        assert.deepStrictEqual([s.first, s.last, s.mean, s.median, s.min, s.max, s.n], [90, 30, 30, 10, 10, 90, 5]);
    });

    test.it("skips runs that never reached a step", () => {
        const s = Perf.stats([5e6, null, null]);
        assert.deepStrictEqual([s.first, s.last, s.n, s.mean], [5e6, null, 1, 5e6]);
    });

    test.it("has nothing to say about no values", () => {
        assert.strictEqual(Perf.stats([null, undefined]), null);
    });
});

test.describe("intervals", () => {
    test.it("times each step from the one before it", () => {
        assert.deepStrictEqual(Perf.intervals([["built", 100], ["shown", 130], ["first frame", 200]]), [
            { label: "built", at: 100, delta: 100 },
            { label: "shown", at: 130, delta: 30 },
            { label: "first frame", at: 200, delta: 70 }
        ]);
    });

    test.it("numbers a step that repeats", () => {
        assert.deepStrictEqual(Perf.labelled([["results", 1], ["results", 2], ["results", 3]]).map(r => r[0]), ["results", "results #2", "results #3"]);
    });
});

test.describe("aggregate", () => {
    const span = (name, steps, detail = "") => ({ name, detail, steps, frames: 2, worstGap: 4 });
    const runs = [1, 2, 3].map(run => ({
        scenario: "clipboard",
        run,
        calls: [{ call: "clipboard toggle", ns: 30 + run, ok: true }],
        spans: [span("clipboard open", run === 1 ? [["built", 900], ["shown", 950]] : [["shown", 20]], run === 1 ? "first" : "")]
    }));

    test.it("orders steps by when they happen, whatever came before them in a run", () => {
        const ops = Perf.aggregate([1, 2].map(run => ({
            scenario: "menus",
            run,
            calls: [],
            spans: [span("menu open", run === 1 ? [["body built", 10], ["shown", 12]] : [["shown", 2], ["body built", 9]])]
        })));
        assert.deepStrictEqual(ops[0].rows.slice(0, 2).map(r => [r.row, r.values]), [
            ["> shown", [2, 2]],
            ["> body built", [10, 7]]
        ]);
    });

    test.it("lines up every run of an operation and keeps a step only some runs had", () => {
        const ops = Perf.aggregate(runs);
        const open = ops.find(o => o.name === "clipboard open");
        assert.deepStrictEqual(open.runs, [1, 2, 3]);
        const built = open.rows.find(r => r.row === "> built");
        assert.deepStrictEqual(built.values, [900, null, null]);
        const total = open.rows.find(r => r.row === "total");
        assert.deepStrictEqual([total.stats.first, total.stats.last], [950, 20]);
        assert.strictEqual(open.detail[0], "first");
    });

    test.it("times the client's call next to the shell's own steps", () => {
        const call = Perf.aggregate(runs).find(o => o.name === "clipboard, call 1: clipboard toggle");
        assert.deepStrictEqual(call.rows[0].values, [31, 32, 33]);
    });

    test.it("puts the process start in front of a boot", () => {
        const ops = Perf.aggregateBoots([{ run: 1, offset: 2e6, answered: 9e6, spans: [{ name: "boot", steps: [["shell built", 1e6]], frames: 0, worstGap: 0 }] }]);
        const boot = ops.find(o => o.name === "boot");
        assert.strictEqual(boot.from, "process started");
        assert.deepStrictEqual(boot.rows.map(r => [r.row, r.values[0]]).slice(0, 3), [
            ["> trace started", 2e6],
            ["> shell built", 1e6],
            ["> ipc answers", 6e6]
        ]);
    });
});

test.describe("scenarios", () => {
    test.it("write a config key back to the value it had", () => {
        const write = Perf.scenarios([]).find(s => s.id === "config write");
        const shell = { call: () => ({ out: "250" }) };
        assert.deepStrictEqual(write.build(shell), [["shell", "set", "clipboard.maxEntries", "249"], ["shell", "set", "clipboard.maxEntries", "250"]]);
        assert.deepStrictEqual(write.build({ call: () => ({ out: "no such setting" }) }), []);
    });

    test.it("open and close every panel and walk every settings page", () => {
        const all = Perf.scenarios(["clock"]);
        assert.ok(all.find(s => s.id === "settings pages").steps.length > 30);
        assert.deepStrictEqual(all.find(s => s.id === "menus").steps, [["menu", "open", "clock", ""], ["menu", "close"]]);
        assert.ok(all.filter(s => !s.id.startsWith("idle") && !s.build).every(s => s.steps.length >= 2));
        assert.deepStrictEqual(all.filter(s => s.id.startsWith("idle")).map(s => s.steps[0].slice(0, 2)), [["trace", "watch"], ["trace", "watch"]]);
    });
});

test.describe("profile", () => {
    const os = require("node:os");
    const fs = require("node:fs");
    const file = path.join(fs.mkdtempSync(path.join(os.tmpdir(), "perf-")), "trace.qtd");
    fs.writeFileSync(file, `<?xml version="1.0"?><trace><eventData>
<event index="0"><displayname>x</displayname><type>Javascript</type><filename>qs:@/qs/modules/ipc/TraceIpc.qml</filename><line>30</line><details>take</details></event>
<event index="1"><displayname>b</displayname><type>Binding</type><filename>file:///tmp/root/modules/menu/MenuPanel.qml</filename><line>9</line><details>a &amp;&amp; b</details></event>
</eventData><profilerDataModel>
<range startTime="1000" duration="100" eventIndex="0"/>
<range startTime="2000" duration="500" eventIndex="1"/>
<range startTime="2100" duration="100" eventIndex="1"/>
</profilerDataModel></trace>`);
    const profile = Perf.readProfile(file);

    test.it("takes nested time out of the parent's own time", () => {
        assert.deepStrictEqual(profile.ranges.map(r => r.self), [100, 400, 100]);
        assert.deepStrictEqual(profile.events[1], { type: "Binding", what: "modules/menu/MenuPanel.qml:9", name: "a && b" });
    });

    test.it("lines the profiler's clock up with the trace through each take", () => {
        assert.strictEqual(Perf.alignment(profile, [5050]), 4000);
    });

    test.it("counts only what ran inside a span", () => {
        const inside = Perf.breakdown([{ run: 1, spans: [{ name: "menu open", start: 6050, steps: [["shown", 600]] }] }], profile, 4000);
        assert.deepStrictEqual(inside["menu open"].map(i => [i.what, i.self, i.count]), [["modules/menu/MenuPanel.qml:9", 100, 1]]);
    });
});

test.describe("live report", () => {
    test.it("groups what was recorded by name, every span a run, in the order they happened", () => {
        const span = (name, at) => ({ name, steps: [["shown", at]], frames: 1, worstGap: 0 });
        const ops = Perf.aggregateLive([span("launcher open", 50e6), span("menu clock open", 9e6), span("launcher open", 5e6)]);
        assert.deepStrictEqual(ops.map(o => [o.name, o.runs]), [["launcher open", [1, 2]], ["menu clock open", [1]]]);
        assert.deepStrictEqual(ops[0].rows.find(r => r.row === "total").values, [50e6, 5e6]);
    });
});
