const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const ROOT = path.resolve(__dirname, "..");

function lib(file, names) {
    const src = fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "");
    return new Function(`${src}\nreturn { ${names.join(", ")} };`)();
}

const Model = lib("modules/workshop/layout-model.js", ["normalise", "arrange", "message", "problems", "dealing", "split", "remove", "moveRegion", "setRegion", "setOrder", "setWhen", "addFallback", "removeArrangement", "rename", "nameProblem", "cleanName", "holderIds", "stage", "blank", "columns", "STARTERS", "MESSAGES", "describeSize", "whenText"]);
const Lua = lib("modules/workshop/layout-lua.js", ["generate", "bindLines", "loader", "failedNames", "luaString"]);

const LUA = ["lua", "lua5.4"].find(bin => spawnSync(bin, ["-v"]).status === 0);

const RUNNER = String.raw`
local registry = {}
local errors = {}
local active_address
local dispatched = {}

hl = {
    layout = {
        register = function(name, provider)
            if registry[name] then
                errors[#errors + 1] = "layout 'lua:" .. name .. "' is already registered"
                return
            end
            registry[name] = provider
        end,
    },
    get_active_window = function()
        if not active_address then return nil end
        return { address = active_address }
    end,
    dispatch = function(what)
        dispatched[#dispatched + 1] = what
    end,
    dsp = {
        layout = function(msg) return { layout = msg } end,
        window = { swap = function(opts) return { swap = opts.target } end },
    },
    timer = function(fn) fn() end,
}

local function encode(value)
    if type(value) == "number" then
        return string.format("%.17g", value)
    elseif type(value) == "string" then
        return string.format("%q", value)
    elseif type(value) == "table" then
        local parts = {}
        if #value > 0 or next(value) == nil then
            for i = 1, #value do parts[i] = encode(value[i]) end
            return "[" .. table.concat(parts, ",") .. "]"
        end
        for k, v in pairs(value) do parts[#parts + 1] = string.format("%q", k) .. ":" .. encode(v) end
        table.sort(parts)
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return "null"
end

local scenarios = dofile(arg[1])
local results = {}
for s, scenario in ipairs(scenarios) do
    registry = {}
    dispatched = {}
    banditshell_workshop = nil
    for _, file in ipairs(scenario.load) do dofile(file) end
    local provider = registry[scenario.layout]
    local targets = {}
    local placed = {}
    for i = 1, scenario.count do
        targets[i] = {
            index = i,
            window = { address = "0x" .. i, workspace = { id = 1 } },
            place = function(self, box) placed[self.index] = { box.x, box.y, box.w, box.h } end,
        }
    end
    local ctx = { area = scenario.area, targets = targets }
    for _, step in ipairs(scenario.steps or {}) do
        active_address = step.active and ("0x" .. step.active) or nil
        provider.recalculate(ctx)
        provider.layout_msg(ctx, step.msg)
    end
    placed = {}
    provider.recalculate(ctx)
    local swaps = {}
    for _, d in ipairs(dispatched) do swaps[#swaps + 1] = d.swap end
    local boxes = {}
    for i = 1, scenario.count do boxes[i] = placed[i] or "missing" end
    results[s] = { boxes = boxes, swaps = swaps, errors = #errors }
end
io.write(encode(results))
`;

function luaArea(area) {
    return `{ x = ${area.x}, y = ${area.y}, w = ${area.w}, h = ${area.h} }`;
}

function runLua(scenarios) {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), "layout-workshop-"));
    const runner = path.join(dir, "runner.lua");
    const input = path.join(dir, "scenarios.lua");
    fs.writeFileSync(runner, RUNNER);
    const body = scenarios.map(s => `{ layout = ${Lua.luaString(s.layout)}, load = { ${s.load.map(Lua.luaString).join(", ")} }, area = ${luaArea(s.area)}, count = ${s.count}, steps = { ${(s.steps || []).map(step => `{ active = ${step.active || "nil"}, msg = ${Lua.luaString(step.msg)} }`).join(", ")} } }`);
    fs.writeFileSync(input, `return {\n${body.join(",\n")}\n}\n`);
    const run = spawnSync(LUA, [runner, input], { encoding: "utf8" });
    fs.rmSync(dir, { recursive: true, force: true });
    assert.strictEqual(run.status, 0, run.stderr);
    return JSON.parse(run.stdout);
}

function writeLayout(model) {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), "layout-workshop-lua-"));
    const file = path.join(dir, `${model.name}.lua`);
    fs.writeFileSync(file, Lua.generate(model));
    return file;
}

function jsBoxes(model, area, count, steps) {
    let state = { weights: {}, scales: {} };
    for (const step of steps || [])
        state = Model.message(model, area, count, state, step.active ? step.active - 1 : -1, step.msg);
    const placed = Model.arrange(model, area, count, state);
    const out = [];
    for (let i = 0; i < count; i++) {
        const box = placed.windows[i];
        out.push(box ? [box.x, box.y, box.w, box.h] : "missing");
    }
    return out;
}

const SHAPES = [
    { x: 0, y: 0, w: 5120, h: 1440 },
    { x: 0, y: 0, w: 1200, h: 1920 },
    { x: 72, y: 20, w: 5038, h: 1410 },
    { x: 1210, y: 20, w: 1180, h: 1890 },
    { x: 0, y: 0, w: 2560, h: 1440 },
    { x: 3, y: 7, w: 3441, h: 1001 }
];

const STAGE_STEPS = [
    [],
    [{ active: 2, msg: "taller" }],
    [{ active: 2, msg: "taller" }, { active: 2, msg: "taller" }, { active: 4, msg: "shorter" }],
    [{ active: 3, msg: "shorter" }, { active: 5, msg: "taller" }, { active: 3, msg: "shorter" }],
    [{ active: 2, msg: "taller" }, { active: 2, msg: "taller" }, { active: 2, msg: "taller" }, { active: 2, msg: "taller" }, { active: 2, msg: "taller" }, { active: 2, msg: "taller" }, { active: 2, msg: "taller" }]
];

test.describe("layout workshop model", () => {
    test.it("normalises junk into a usable layout", () => {
        const model = Model.normalise({ name: "My Layout!", arrangements: [{ root: { kind: "nonsense" }, order: { first: ["nowhere"] } }] });
        assert.strictEqual(model.name, "my-layout");
        assert.strictEqual(model.arrangements.length, 1);
        assert.strictEqual(model.arrangements[0].root.kind, "stack");
        assert.deepStrictEqual(model.arrangements[0].order.first, []);
        assert.deepStrictEqual(model.arrangements[0].order.repeat, [model.arrangements[0].root.id]);
        const spaces = Model.normalise({ arrangements: [{ root: { kind: "space" } }] });
        assert.strictEqual(spaces.arrangements[0].root.kind, "stack");
    });

    test.it("gives duplicate region ids fresh names", () => {
        const model = Model.normalise({ arrangements: [{ root: { kind: "split", children: [{ id: "a", kind: "slot" }, { id: "a", kind: "stack" }] } }] });
        const ids = model.arrangements[0].root.children.map(c => c.id);
        assert.strictEqual(new Set(ids).size, 2);
    });

    test.it("checks names", () => {
        assert.strictEqual(Model.nameProblem("stage-drawn", ["lua:stage"]), "");
        assert.match(Model.nameProblem("stage", ["stage"]), /already registers/);
        assert.match(Model.nameProblem("dwindle", []), /built-in/);
        assert.match(Model.nameProblem("Bad Name", []), /letters/);
        assert.match(Model.nameProblem("", []), /name/);
    });

    test.it("deals stage windows to main, then right and left in turn", () => {
        const model = Model.stage();
        assert.deepStrictEqual(Model.dealing(model.arrangements[0], 6).assigned, ["main", "right", "left", "right", "left", "right"]);
    });

    test.it("skips a full slot in the repeat pattern and spills when everything is full", () => {
        const model = Model.normalise({
            arrangements: [{
                root: { id: "root", kind: "split", children: [{ id: "a", kind: "slot" }, { id: "b", kind: "slot" }] },
                order: { first: ["a"], repeat: ["a", "b"] }
            }]
        });
        assert.deepStrictEqual(Model.dealing(model.arrangements[0], 4).assigned, ["a", "b", "a", "b"]);
    });

    test.it("collapses an empty region so the rest fills the space", () => {
        const model = Model.blank();
        const area = { x: 0, y: 0, w: 1000, h: 500 };
        assert.deepStrictEqual(jsBoxes(model, area, 1), [[0, 0, 1000, 500]]);
        assert.deepStrictEqual(jsBoxes(model, area, 2), [[0, 0, 600, 500], [600, 0, 400, 500]]);
        assert.deepStrictEqual(jsBoxes(model, area, 3), [[0, 0, 600, 500], [600, 0, 400, 250], [600, 250, 400, 250]]);
    });

    test.it("falls back when a region would not fit, by width or by window count", () => {
        const stage = Model.stage();
        assert.strictEqual(Model.arrange(stage, { x: 0, y: 0, w: 5120, h: 1440 }, 3, {}).index, 0);
        assert.strictEqual(Model.arrange(stage, { x: 0, y: 0, w: 2560, h: 1440 }, 3, {}).index, 1);
        assert.strictEqual(Model.arrange(stage, { x: 0, y: 0, w: 1200, h: 1920 }, 3, {}).index, 1);
        const counted = Model.setWhen(stage, 0, "maxWindows", 3);
        assert.strictEqual(Model.arrange(counted, { x: 0, y: 0, w: 5120, h: 1440 }, 3, {}).index, 0);
        assert.strictEqual(Model.arrange(counted, { x: 0, y: 0, w: 5120, h: 1440 }, 4, {}).index, 1);
        const roomy = Model.setWhen(stage, 0, "fit", 1500);
        assert.strictEqual(Model.arrange(roomy, { x: 0, y: 0, w: 5120, h: 1440 }, 2, {}).index, 1);
    });

    test.it("places every window and never overlaps on the stage", () => {
        const model = Model.stage();
        for (const area of SHAPES)
            for (let count = 1; count <= 8; count++) {
                const boxes = jsBoxes(model, area, count);
                assert.ok(boxes.every(b => b !== "missing"));
                for (let i = 0; i < boxes.length; i++)
                    for (let j = i + 1; j < boxes.length; j++) {
                        const [a, b] = [boxes[i], boxes[j]];
                        const apart = a[0] + a[2] <= b[0] || b[0] + b[2] <= a[0] || a[1] + a[3] <= b[1] || b[1] + b[3] <= a[1];
                        assert.ok(apart, `windows ${i + 1} and ${j + 1} overlap at ${count} on ${area.w}x${area.h}`);
                    }
            }
    });

    test.it("holds the stage window to 16:9 at full height on the ultrawide", () => {
        const boxes = jsBoxes(Model.stage(), { x: 0, y: 0, w: 5120, h: 1440 }, 3);
        assert.deepStrictEqual(boxes, [[1280, 0, 2560, 1440], [3840, 0, 1280, 1440], [0, 0, 1280, 1440]]);
    });

    test.it("splits a region beside itself or wraps it in a new split", () => {
        const model = Model.stage();
        const across = Model.split(model, 0, "left", "row");
        assert.strictEqual(across.model.arrangements[0].root.children.length, 4);
        assert.ok(across.model.arrangements[0].order.repeat.includes(across.made));
        const down = Model.split(model, 0, "left", "column");
        const wrapped = down.model.arrangements[0].root.children[0];
        assert.strictEqual(wrapped.kind, "split");
        assert.strictEqual(wrapped.axis, "column");
        assert.strictEqual(wrapped.children[0].id, "left");
        assert.deepStrictEqual(wrapped.size, { rule: "share", value: 1 });
        const back = Model.remove(down.model, 0, down.made);
        assert.deepStrictEqual(back.arrangements[0].root, model.arrangements[0].root);
    });

    test.it("removes regions from the fill order with them", () => {
        const model = Model.remove(Model.stage(), 0, "left");
        assert.deepStrictEqual(model.arrangements[0].order.repeat, ["right"]);
        assert.deepStrictEqual(Model.moveRegion(model, 0, "right", -1).arrangements[0].root.children.map(c => c.id), ["right", "main"]);
    });

    test.it("edits region fields, order, fallbacks and the name", () => {
        let model = Model.setRegion(Model.stage(), 0, "main", { size: { rule: "fraction", value: 0.5 } });
        assert.strictEqual(Model.describeSize(model.arrangements[0].root.children[1].size), "50%");
        model = Model.setOrder(model, 0, ["main", "left"], ["right"]);
        assert.deepStrictEqual(Model.dealing(model.arrangements[0], 4).assigned, ["main", "left", "right", "right"]);
        model = Model.addFallback(model, 0);
        assert.strictEqual(model.arrangements.length, 3);
        model = Model.removeArrangement(model, 2);
        assert.strictEqual(model.arrangements.length, 2);
        assert.strictEqual(Model.rename(model, "Wide Stage").name, "wide-stage");
        assert.strictEqual(Model.whenText(model.arrangements[1], 1, 2), "otherwise");
    });

    test.it("warns when nothing repeats", () => {
        const model = Model.setOrder(Model.stage(), 0, ["main"], []);
        assert.strictEqual(Model.problems(model).length, 1);
        assert.deepStrictEqual(Model.problems(Model.stage()), []);
    });

    test.it("changes weights in a stack and shares between regions", () => {
        const model = Model.blank();
        const area = { x: 0, y: 0, w: 1000, h: 1000 };
        const taller = Model.message(model, area, 3, {}, 1, "taller");
        assert.strictEqual(taller.weights[1], 1.25);
        const wider = Model.message(model, area, 3, {}, 1, "wider");
        assert.strictEqual(wider.scales.side, 1.25);
        const fixed = Model.setRegion(model, 0, "side", { size: { rule: "pixels", value: 300 } });
        assert.deepStrictEqual(Model.message(fixed, area, 3, {}, 1, "wider").scales, {});
        const narrower = Model.message(model, area, 3, {}, 0, "narrower");
        assert.strictEqual(narrower.scales.main, 0.8);
        assert.deepStrictEqual(Model.message(model, area, 3, taller, 1, "reset"), { weights: {}, scales: {} });
    });
});

test.describe("layout workshop lua", { skip: !LUA && "no lua interpreter" }, () => {
    test.it("generates Lua that parses and reads like a description", () => {
        const source = Lua.generate(Model.stage());
        assert.match(source, /local name = "stage-drawn"/);
        assert.match(source, /order = \{ first = \{ "main" \}, \["repeat"\] = \{ "right", "left" \} \}/);
        assert.match(source, /size = \{ rule = "aspect", width = 16, height = 9 \}/);
        assert.doesNotMatch(source, /[\u2013\u2014]/);
        const file = writeLayout(Model.stage());
        const check = spawnSync(LUA, ["-e", `loadfile(${Lua.luaString(file)})`], { encoding: "utf8" });
        assert.strictEqual(check.status, 0, check.stderr);
    });

    test.it("registers once, swaps the implementation on a second load, and registers again after a reload", () => {
        const first = Model.stage();
        const file = writeLayout(first);
        const changed = Model.setRegion(first, 0, "main", { size: { rule: "aspect", width: 4, height: 3 } });
        const second = writeLayout(changed);
        fs.renameSync(second, file);
        const dir = fs.mkdtempSync(path.join(os.tmpdir(), "layout-workshop-twice-"));
        const runner = path.join(dir, "twice.lua");
        const original = path.join(dir, "original.lua");
        fs.writeFileSync(original, Lua.generate(first));
        fs.writeFileSync(runner, `
local registry, count, errors = {}, 0, 0
hl = { layout = { register = function(name, p) if registry[name] then errors = errors + 1 return end registry[name] = p count = count + 1 end } }
local function width()
    local placed
    local ctx = { area = { x = 0, y = 0, w = 5120, h = 1440 }, targets = { { window = { address = "a" }, place = function(_, box) placed = box end } } }
    registry["stage-drawn"].recalculate(ctx)
    return placed.w
end
load(${JSON.stringify(Lua.loader([original]))})()
local before = width()
load(${JSON.stringify(Lua.loader([file]))})()
local after = width()
registry = {}
load(${JSON.stringify(Lua.loader([file], true))})()
io.write(count, " ", errors, " ", before, " ", after, " ", width())
`);
        const run = spawnSync(LUA, [runner], { encoding: "utf8" });
        fs.rmSync(dir, { recursive: true, force: true });
        assert.strictEqual(run.status, 0, run.stderr);
        assert.strictEqual(run.stdout, "2 0 2560 1920 1920");
    });

    test.it("places windows exactly like the hand-written stage.lua, 1 to 8 windows, both monitors", () => {
        const model = Model.stage();
        const file = writeLayout(model);
        const fixture = path.join(ROOT, "tests/fixtures/stage.lua");
        const scenarios = [];
        for (const area of SHAPES)
            for (let count = 1; count <= 8; count++)
                for (const steps of STAGE_STEPS) {
                    scenarios.push({ layout: "stage", load: [fixture], area, count, steps });
                    scenarios.push({ layout: "stage-drawn", load: [file], area, count, steps });
                }
        const results = runLua(scenarios);
        for (let i = 0; i < scenarios.length; i += 2) {
            const { area, count, steps } = scenarios[i];
            const where = `${count} windows on ${area.w}x${area.h} after ${JSON.stringify(steps)}`;
            assert.deepStrictEqual(results[i + 1].boxes, results[i].boxes, `generated Lua differs from stage.lua: ${where}`);
            assert.deepStrictEqual(jsBoxes(model, area, count, steps), results[i].boxes, `JS preview differs from stage.lua: ${where}`);
        }
    });

    test.it("lets the first window grow in the one column fallback, where stage.lua holds it", () => {
        const model = Model.stage();
        const area = { x: 0, y: 0, w: 1200, h: 1920 };
        const boxes = jsBoxes(model, area, 2, [{ active: 1, msg: "taller" }]);
        assert.deepStrictEqual(boxes, [[0, 0, 1200, 1066], [0, 1066, 1200, 854]]);
        const wide = jsBoxes(model, { x: 0, y: 0, w: 5120, h: 1440 }, 3, [{ active: 1, msg: "taller" }]);
        assert.deepStrictEqual(wide, jsBoxes(model, { x: 0, y: 0, w: 5120, h: 1440 }, 3));
    });

    test.it("promotes by swapping with the first window, like put_on_stage", () => {
        const file = writeLayout(Model.stage());
        const [promoted, first] = runLua([
            { layout: "stage-drawn", load: [file], area: SHAPES[0], count: 4, steps: [{ active: 3, msg: "promote" }] },
            { layout: "stage-drawn", load: [file], area: SHAPES[0], count: 4, steps: [{ active: 1, msg: "promote" }] }
        ]);
        assert.deepStrictEqual(promoted.swaps, ["address:0x1"]);
        assert.deepStrictEqual(first.swaps, []);
    });

    test.it("matches the JS preview for every starter and many random layouts", () => {
        const random = seedRandom(16);
        const models = Model.STARTERS.map(s => s.make());
        for (let i = 0; i < 40; i++)
            models.push(randomModel(random, i));
        const scenarios = [];
        const expected = [];
        const messages = ["taller", "shorter", "wider", "narrower"];
        models.forEach(model => {
            const file = writeLayout(model);
            for (const area of SHAPES)
                for (let count = 0; count <= 9; count += random() < 0.5 ? 1 : 2) {
                    const steps = [];
                    const many = Math.floor(random() * 4);
                    for (let s = 0; s < many && count > 0; s++)
                        steps.push({ active: 1 + Math.floor(random() * count), msg: messages[Math.floor(random() * messages.length)] });
                    scenarios.push({ layout: model.name, load: [file], area, count, steps });
                    expected.push(jsBoxes(model, area, count, steps));
                }
        });
        const results = runLua(scenarios);
        results.forEach((result, i) => {
            const s = scenarios[i];
            assert.deepStrictEqual(result.boxes, expected[i], `${s.layout} with ${s.count} on ${s.area.w}x${s.area.h} after ${JSON.stringify(s.steps)}`);
        });
    });

    test.it("writes binds for the messages", () => {
        const lines = Lua.bindLines(Model.stage(), Model.MESSAGES.slice(0, 1));
        assert.deepStrictEqual(lines, ['hl.bind("SUPER + equal", hl.dsp.layout("taller"), { description = "stage-drawn: taller" })']);
        assert.match(Lua.loader(["/tmp/a \"b\".lua"]), /ipairs\(\{ "\/tmp\/a \\"b\\".lua" \}\)/);
        assert.match(Lua.loader(["/x.lua"], true), /^if banditshell_workshop then banditshell_workshop.registered = \{\} end\n/);
        assert.deepStrictEqual(Lua.failedNames("ok\n", ["a"], "/s"), []);
        assert.deepStrictEqual(Lua.failedNames("error: /s/b.lua:3: oops", ["a", "b"], "/s"), ["b"]);
        assert.deepStrictEqual(Lua.failedNames("error: hl.layout.register: layout 'lua:a' is already registered", ["a", "b"], "/s"), ["a"]);
    });

    test.it("reports a broken file and still loads the others", () => {
        const good = writeLayout(Model.stage());
        const dir = fs.mkdtempSync(path.join(os.tmpdir(), "layout-workshop-broken-"));
        const broken = path.join(dir, "broken.lua");
        fs.writeFileSync(broken, "local x = (");
        const runner = path.join(dir, "run.lua");
        fs.writeFileSync(runner, `
local registry = {}
hl = { layout = { register = function(name, p) registry[name] = p end } }
local ok, problem = pcall(load(${JSON.stringify(Lua.loader([broken, good]))}))
io.write(tostring(ok), " ", tostring(registry["stage-drawn"] ~= nil), " ", tostring(problem):find("broken.lua", 1, true) and "named" or "unnamed")
`);
        const run = spawnSync(LUA, [runner], { encoding: "utf8" });
        fs.rmSync(dir, { recursive: true, force: true });
        assert.strictEqual(run.stdout, "false true named", run.stderr);
    });
});

function seedRandom(seed) {
    let value = seed;
    return () => {
        value = (value * 1103515245 + 12345) % 2147483648;
        return value / 2147483648;
    };
}

function randomRegion(random, depth, counter) {
    counter.n += 1;
    const id = `r${counter.n}`;
    const rules = [
        () => ({ rule: "share", value: 0.5 + Math.floor(random() * 6) / 2 }),
        () => ({ rule: "aspect", width: [16, 4, 1, 21][Math.floor(random() * 4)], height: [9, 3, 1, 9][Math.floor(random() * 4)] }),
        () => ({ rule: "fraction", value: 0.1 + Math.floor(random() * 8) / 10 }),
        () => ({ rule: "pixels", value: 100 + Math.floor(random() * 900) })
    ];
    const size = rules[Math.floor(random() * rules.length)]();
    const collapse = random() < 0.3;
    if (depth < 3 && random() < 0.45) {
        const children = [];
        const many = 2 + Math.floor(random() * 3);
        for (let i = 0; i < many; i++)
            children.push(randomRegion(random, depth + 1, counter));
        return { id, kind: "split", axis: random() < 0.5 ? "row" : "column", size, collapse, children };
    }
    const kind = ["slot", "stack", "stack", "space"][Math.floor(random() * 4)];
    return { id, kind, axis: random() < 0.5 ? "row" : "column", size, collapse };
}

function randomModel(random, index) {
    const arrangements = [];
    const many = 1 + Math.floor(random() * 3);
    for (let a = 0; a < many; a++) {
        const root = randomRegion(random, 0, { n: 0 });
        const draft = Model.normalise({ arrangements: [{ root }] });
        const ids = Model.holderIds(draft.arrangements[0]);
        const pick = () => ids[Math.floor(random() * ids.length)];
        const first = [];
        const repeat = [];
        for (let i = Math.floor(random() * 3); i > 0; i--)
            first.push(pick());
        for (let i = Math.floor(random() * 3); i > 0; i--)
            repeat.push(pick());
        arrangements.push({
            root,
            order: { first, repeat },
            fit: random() < 0.5 ? 1 : 200 + Math.floor(random() * 600),
            when: {
                maxWindows: random() < 0.3 ? 1 + Math.floor(random() * 5) : 0,
                minWidth: random() < 0.2 ? 2000 : 0,
                maxWidth: random() < 0.2 ? 2000 : 0,
                minWindows: random() < 0.2 ? 2 : 0
            }
        });
    }
    return Model.normalise({ name: `random-${index}`, arrangements, messages: { step: 1.1 + random() } });
}
