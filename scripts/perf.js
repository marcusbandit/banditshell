#!/usr/bin/env node
"use strict";

const { spawn, spawnSync } = require("node:child_process");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");

function settingsPages() {
    try {
        const src = fs.readFileSync(path.join(ROOT, "modules/settings/catalogue.js"), "utf8").replace(/^\.pragma .*$/m, "");
        return new Function(`${src}\nreturn PAGES.map(p => p.id);`)();
    } catch (e) {
        return ["wifi", "output", "screens", "wallpaper", "launcher", "about"];
    }
}

function scenarios(menuKeys) {
    const panel = (id, target, open = ["toggle"], close = ["toggle"]) => ({
        id,
        steps: [[target, ...open], [target, ...close]]
    });
    const pages = settingsPages();
    const idle = id => ({ id, wait: 6000, steps: [["trace", "watch", id, "3000"]] });
    return [
        idle("idle at rest"),
        panel("launcher", "launcher"),
        {
            id: "launcher typing",
            steps: [["launcher", "open", ""], ...["f", "fi", "fir", "fire", "firef", "firefo", "firefox"].map(q => ["launcher", "open", q]), ["launcher", "close"]]
        },
        panel("clipboard", "clipboard"),
        panel("session", "session"),
        panel("calculator", "calculator"),
        panel("media", "media"),
        panel("hotkeys", "hotkeys", ["toggle", ""], ["toggle", ""]),
        panel("wallpapers", "wallpapers", ["toggle", ""], ["toggle", ""]),
        panel("keyboard", "keyboard", ["toggle", ""], ["toggle", ""]),
        panel("quick controls", "quickcontrols"),
        panel("island", "island", ["toggle", ""], ["toggle", ""]),
        panel("settings", "settings", ["open", "", ""], ["close"]),
        {
            id: "settings pages",
            steps: [["settings", "open", pages[0], ""], ...pages.slice(1).map(p => ["settings", "page", p]), ["settings", "close"]]
        },
        {
            id: "settings revisits",
            steps: [["settings", "open", "launcher", ""], ...["sidebar", "launcher", "windows", "sidebar", "launcher", "desktop", "launcher"].map(p => ["settings", "page", p]), ["settings", "close"]],
            rename: spans => {
                const seen = new Set(["launcher"]);
                return spans.map(span => {
                    const page = /^settings page (.+)$/.exec(span.name)?.[1];
                    const again = !!page && seen.has(page);
                    if (page)
                        seen.add(page);
                    const name = !page ? `${span.name}, revisits round` : again ? `settings page ${page} again` : `${span.name}, before going back`;
                    return Object.assign({}, span, { name });
                });
            }
        },
        {
            id: "menus",
            steps: [...menuKeys.map(key => ["menu", "open", key, ""]), ["menu", "close"]]
        },
        panel("files", "files", ["open", ""], ["close"]),
        {
            id: "config write",
            headless: true,
            steps: [],
            build: shell => {
                const kept = Number(shell.call("shell", "get", "clipboard.maxEntries").out);
                return Number.isInteger(kept) && kept > 1 ? [["shell", "set", "clipboard.maxEntries", String(kept - 1)], ["shell", "set", "clipboard.maxEntries", String(kept)]] : [];
            }
        },
        {
            id: "hotkey path",
            cli: true,
            steps: [["action", "panel.clipboard.toggle"], ["action", "panel.clipboard.toggle"]]
        },
        idle("idle after everything opened once")
    ];
}

function now() {
    return process.hrtime.bigint();
}

function schedstat(file) {
    try {
        return Number(fs.readFileSync(file, "utf8").split(" ")[0]) || 0;
    } catch (e) {
        return 0;
    }
}

function cpu(pid) {
    if (!pid)
        return null;
    let all = 0;
    try {
        for (const task of fs.readdirSync(`/proc/${pid}/task`))
            all += schedstat(`/proc/${pid}/task/${task}/schedstat`);
    } catch (e) {
        return null;
    }
    return { gui: schedstat(`/proc/${pid}/task/${pid}/schedstat`), all };
}

class Shell {
    constructor(target, cli) {
        this.target = target;
        this.cli = cli;
        this.pid = target[0] === "--pid" ? target[1] : null;
        this.clock = [];
    }

    call(...args) {
        const start = now();
        const run = spawnSync("qs", ["ipc", ...this.target, "call", ...args], { encoding: "utf8", cwd: process.env.HOME || "/" });
        return { ns: Number(now() - start), out: (run.stdout || "").trim(), ok: run.status === 0 };
    }

    command(...args) {
        const start = now();
        const run = spawnSync("bash", [this.cli, ...args], { encoding: "utf8", cwd: process.env.HOME || "/" });
        return { ns: Number(now() - start), out: (run.stdout || "").trim(), ok: run.status === 0 };
    }

    settle(limitMs = 8000) {
        const until = Date.now() + limitMs;
        while (Date.now() < until) {
            const reply = this.call("trace", "pending");
            if (reply.ok && reply.out === "0")
                return true;
            sleep(25);
        }
        return false;
    }

    take() {
        const reply = this.call("trace", "take");
        try {
            const taken = JSON.parse(reply.out);
            this.clock.push(taken.now);
            return taken.spans;
        } catch (e) {
            return [];
        }
    }
}

function sleep(ms) {
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);
}

function drive(shell, options) {
    const keys = shell.call("menu", "list").out.split("\n").filter(Boolean);
    const chosen = scenarios(keys).filter(s => !options.only || options.only.test(s.id));
    const runs = [];
    shell.call("panels", "closeAll");
    shell.settle();
    const opening = shell.take();
    if (options.keep && opening.length) {
        let kept = [];
        try {
            kept = JSON.parse(fs.readFileSync(options.keep, "utf8"));
        } catch (e) {}
        fs.writeFileSync(options.keep, `${JSON.stringify([...kept, ...opening])}\n`);
    }
    if (options.profile && opening.length)
        runs.push({ scenario: "start of the profiled shell", run: 1, calls: [], spans: opening.map(span => Object.assign({}, span, { name: `${span.name}, profiled shell` })) });
    for (const scenario of chosen) {
        if ((scenario.cli && !shell.cli) || (scenario.headless && options.target))
            continue;
        process.stderr.write(`${scenario.id}: `);
        for (let run = 1; run <= options.runs; run++) {
            const calls = [];
            for (const step of scenario.build ? scenario.build(shell) : scenario.steps) {
                const before = cpu(shell.pid);
                const reply = scenario.cli ? shell.command(...step) : shell.call(...step);
                if (!shell.settle(scenario.wait ?? 8000))
                    process.stderr.write("(did not settle) ");
                const after = cpu(shell.pid);
                calls.push({
                    call: step.join(" "),
                    ns: reply.ns,
                    ok: reply.ok,
                    out: reply.out.slice(0, 200),
                    gui: before && after ? after.gui - before.gui : null,
                    all: before && after ? after.all - before.all : null
                });
                sleep(options.gap);
            }
            const spans = shell.take();
            runs.push({ scenario: scenario.id, run, calls, spans: scenario.rename ? scenario.rename(spans) : spans });
            process.stderr.write(`${run} `);
        }
        process.stderr.write("\n");
        shell.call("panels", "closeAll");
        shell.settle();
        shell.take();
    }
    return runs;
}

function alive(pid) {
    try {
        const stat = fs.readFileSync(`/proc/${pid}/stat`, "utf8");
        return stat.slice(stat.lastIndexOf(")") + 2, stat.lastIndexOf(")") + 3) !== "Z";
    } catch (e) {
        return false;
    }
}

const running = new Set();

function launch(shellQml, log, port = 0) {
    const pidFile = `${log}.pid`;
    fs.rmSync(pidFile, { force: true });
    const out = fs.openSync(log, "a");
    const wall = Date.now();
    const start = now();
    const child = spawn("gamescope", ["--backend", "headless", "-W", "1920", "-H", "1080", "--expose-wayland", "--", "bash", "-c", 'echo $$ >"$0"; cd "$HOME" && exec env QT_QPA_PLATFORM=wayland BANDITSHELL_TRACE=1 qs -p "$1" "${@:2}"', pidFile, shellQml, ...(port ? ["--debug", String(port), "--waitfordebug"] : [])], {
        detached: true,
        stdio: ["ignore", out, out]
    });
    const run = { group: child.pid, pid: null, wall, start };
    running.add(run);
    const until = Date.now() + 20000;
    while (Date.now() < until && !run.pid) {
        try {
            run.pid = Number(fs.readFileSync(pidFile, "utf8").trim()) || null;
        } catch (e) {}
        if (!run.pid)
            sleep(20);
    }
    if (!run.pid)
        throw new Error(`gamescope did not start the shell (log: ${log})`);
    return run;
}

function halt(run) {
    if (run.pid && alive(run.pid)) {
        process.kill(run.pid, "SIGTERM");
        const dead = Date.now() + 5000;
        while (alive(run.pid) && Date.now() < dead)
            sleep(50);
    }
    try {
        process.kill(-run.group, "SIGKILL");
    } catch (e) {}
    running.delete(run);
}

function failed(log) {
    try {
        return /Failed to load configuration/.test(fs.readFileSync(log, "utf8"));
    } catch (e) {
        return false;
    }
}

function bootOnce(shellQml, log) {
    const run = launch(shellQml, log);
    const shell = new Shell(["--pid", String(run.pid)]);
    const result = { wall: run.wall, answered: -1, spans: [] };
    const until = Date.now() + 60000;
    let boot = null;
    while (Date.now() < until && !boot && alive(run.pid) && !failed(log)) {
        const reply = shell.call("trace", "pending");
        if (reply.ok) {
            if (result.answered < 0)
                result.answered = Number(now() - run.start);
            result.spans.push(...shell.take());
            boot = result.spans.find(s => s.name === "boot");
        }
        if (!boot)
            sleep(100);
    }
    if (boot) {
        sleep(5000);
        shell.settle();
        result.spans.push(...shell.take());
        result.offset = (boot.wall - boot.start / 1e6 - run.wall) * 1e6;
    }
    halt(run);
    return result;
}

async function boots(shellQml, count, out) {
    const results = [];
    for (let i = 1; i <= count; i++) {
        process.stderr.write(`boot ${i}: `);
        const result = bootOnce(shellQml, path.join(out, `boot-${i}.log`));
        await new Promise(resolve => setTimeout(resolve, 500));
        if (result.spans.some(s => s.name === "boot")) {
            process.stderr.write("done\n");
        } else {
            process.stderr.write(`no boot trace (log: ${path.join(out, `boot-${i}.log`)})\n`);
            if (failed(path.join(out, `boot-${i}.log`)))
                throw new Error(`the shell did not load:\n${fs.readFileSync(path.join(out, `boot-${i}.log`), "utf8").replace(/\x1b\[[0-9;]*m/g, "").split("\n").filter(l => /ERROR/.test(l)).join("\n")}`);
        }
        results.push(Object.assign({ run: i }, result));
    }
    return results;
}

const PROFILER = "/usr/lib/qt6/bin/qmlprofiler";

function profileStart(port, qtd, log) {
    const out = fs.openSync(log, "a");
    return spawn(PROFILER, ["--interactive", "-a", "localhost", "-p", String(port), "-o", qtd, "--include", "javascript,binding,creating,handlingsignal,compiling"], {
        stdio: ["pipe", out, out]
    });
}

async function profileStop(profiler, qtd) {
    const pause = ms => new Promise(resolve => setTimeout(resolve, ms));
    profiler.stdin.write("r\n");
    await pause(4000);
    profiler.stdin.write("o\n");
    const until = Date.now() + 120000;
    let size = -1;
    while (Date.now() < until) {
        await pause(2000);
        const now = fs.existsSync(qtd) ? fs.statSync(qtd).size : 0;
        if (now > 0 && now === size)
            break;
        size = now;
    }
    profiler.stdin.write("q\n");
    await pause(1000);
    profiler.kill("SIGKILL");
}

function where(file) {
    const m = /(?:^|\/)((?:modules|services|components|config|previews)\/[^?#]*|shell\.qml)$/.exec(file || "");
    return m ? m[1] : (file || "").replace(/^.*\//, "");
}

function readProfile(qtd) {
    const text = fs.readFileSync(qtd, "utf8");
    const field = (block, name) => {
        const m = new RegExp(`<${name}>([\\s\\S]*?)</${name}>`).exec(block);
        return m ? m[1].replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&apos;/g, "'").replace(/&amp;/g, "&") : "";
    };
    const events = [];
    for (const m of text.matchAll(/<event index="(\d+)">([\s\S]*?)<\/event>/g)) {
        const block = m[2];
        const type = field(block, "type");
        const details = field(block, "details").replace(/\s+/g, " ").slice(0, 80);
        events[Number(m[1])] = {
            type,
            what: `${where(field(block, "filename"))}:${field(block, "line")}`,
            name: type === "Javascript" ? details : type === "Binding" || type === "HandlingSignal" ? details : field(block, "displayname").slice(0, 80)
        };
    }
    const ranges = [];
    for (const m of text.matchAll(/<range ([^>]*?)\/?>/g)) {
        const attrs = {};
        for (const a of m[1].matchAll(/(\w+)="([^"]*)"/g))
            attrs[a[1]] = a[2];
        if (attrs.startTime === undefined || attrs.eventIndex === undefined)
            continue;
        ranges.push({ start: Number(attrs.startTime), duration: Number(attrs.duration || 0), event: Number(attrs.eventIndex), child: 0 });
    }
    ranges.sort((a, b) => a.start - b.start || b.duration - a.duration);
    const stack = [];
    for (const r of ranges) {
        while (stack.length && stack[stack.length - 1].start + stack[stack.length - 1].duration <= r.start)
            stack.pop();
        if (stack.length)
            stack[stack.length - 1].child += r.duration;
        stack.push(r);
    }
    for (const r of ranges)
        r.self = Math.max(0, r.duration - r.child);
    return { events, ranges };
}

function alignment(profile, clock) {
    const takes = profile.ranges.filter(r => {
        const e = profile.events[r.event];
        return e && e.type === "Javascript" && e.name === "take" && /TraceIpc\.qml/.test(e.what);
    });
    const offsets = [];
    for (let i = 0; i < Math.min(takes.length, clock.length); i++)
        offsets.push(clock[i] - (takes[i].start + takes[i].duration / 2));
    return offsets.length ? stats(offsets).median : null;
}

function breakdown(runs, profile, offset, top = 12) {
    const starts = profile.ranges.map(r => r.start);
    const first = at => {
        let lo = 0;
        let hi = starts.length;
        while (lo < hi) {
            const mid = (lo + hi) >> 1;
            if (starts[mid] < at)
                lo = mid + 1;
            else
                hi = mid;
        }
        return lo;
    };
    const byOp = new Map();
    for (const record of runs) {
        const seen = {};
        for (const span of record.spans) {
            seen[span.name] = (seen[span.name] ?? 0) + 1;
            const key = seen[span.name] > 1 ? `${span.name} #${seen[span.name]}` : span.name;
            const total = span.steps.length ? span.steps[span.steps.length - 1][1] : 0;
            const from = span.start - offset;
            const to = from + total + 1e6;
            if (!byOp.has(key))
                byOp.set(key, { instances: 0, sums: new Map() });
            const entry = byOp.get(key);
            entry.instances++;
            for (let i = first(from); i < profile.ranges.length && profile.ranges[i].start < to; i++) {
                const r = profile.ranges[i];
                if (/(^|\/)(Trace|TraceFrames|TraceIpc)\.qml:/.test(profile.events[r.event]?.what ?? ""))
                    continue;
                const sum = entry.sums.get(r.event) ?? { self: 0, count: 0 };
                sum.self += r.self;
                sum.count++;
                entry.sums.set(r.event, sum);
            }
        }
    }
    const out = {};
    for (const [key, entry] of byOp) {
        out[key] = [...entry.sums.entries()]
            .map(([event, sum]) => Object.assign({}, profile.events[event] ?? { type: "?", what: "?", name: "" }, { self: sum.self / entry.instances, count: sum.count / entry.instances }))
            .sort((a, b) => b.self - a.self)
            .slice(0, top);
    }
    return out;
}

function stats(values) {
    const present = values.filter(v => typeof v === "number" && Number.isFinite(v));
    if (present.length === 0)
        return null;
    const sorted = present.slice().sort((a, b) => a - b);
    const mid = Math.floor(sorted.length / 2);
    return {
        n: present.length,
        first: values[0] ?? null,
        last: values[values.length - 1] ?? null,
        mean: present.reduce((a, b) => a + b, 0) / present.length,
        median: sorted.length % 2 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2,
        min: sorted[0],
        max: sorted[sorted.length - 1]
    };
}

function labelled(steps) {
    const seen = {};
    return steps.map(([label, at]) => {
        seen[label] = (seen[label] ?? 0) + 1;
        return [seen[label] > 1 ? `${label} #${seen[label]}` : label, at];
    });
}

function intervals(steps) {
    const rows = [];
    let previous = 0;
    for (const [label, at] of labelled(steps)) {
        rows.push({ label, at, delta: at - previous });
        previous = at;
    }
    return rows;
}

function aggregate(runs) {
    const ops = new Map();
    const order = [];
    const op = (key, scenario, kind) => {
        if (!ops.has(key)) {
            ops.set(key, { name: key, scenario, kind, runs: [], rows: new Map(), at: new Map(), detail: {} });
            order.push(key);
        }
        return ops.get(key);
    };
    const put = (entry, row, run, value) => {
        if (!entry.rows.has(row))
            entry.rows.set(row, []);
        entry.rows.get(row)[run] = value;
    };
    for (const record of runs) {
        const seen = {};
        record.calls.forEach((call, i) => {
            const entry = op(`${record.scenario}, call ${i + 1}: ${call.call}`.replace(/ +$/, ""), record.scenario, "call");
            const index = entry.runs.length;
            entry.runs.push(record.run);
            put(entry, record.scenario === "hotkey path" ? "whole command, client side" : "ipc round trip, client side", index, call.ns);
            if (call.gui !== null && call.gui !== undefined) {
                put(entry, "shell gui thread cpu", index, call.gui);
                put(entry, "shell cpu, all threads", index, call.all);
            }
        });
        for (const span of record.spans) {
            seen[span.name] = (seen[span.name] ?? 0) + 1;
            const key = seen[span.name] > 1 ? `${span.name} #${seen[span.name]}` : span.name;
            const entry = op(key, record.scenario, "span");
            entry.from = span.from ?? "begin";
            const index = entry.runs.length;
            entry.runs.push(record.run);
            for (const { label, at, delta } of intervals(span.steps)) {
                const row = `> ${label}`;
                put(entry, row, index, delta);
                if (!entry.at.has(row))
                    entry.at.set(row, []);
                entry.at.get(row).push(at);
            }
            put(entry, "total", index, span.steps.length ? span.steps[span.steps.length - 1][1] : 0);
            put(entry, "frames", index, span.frames);
            put(entry, "worst frame gap", index, span.worstGap);
            put(entry, "still animating at the cap", index, span.capped ? 1 : 0);
            if (span.detail)
                entry.detail[index] = span.detail;
        }
    }
    const median = list => stats(list)?.median ?? 0;
    return order.map(key => {
        const entry = ops.get(key);
        const width = entry.runs.length;
        const stepRows = [...entry.at.keys()].sort((a, b) => median(entry.at.get(a)) - median(entry.at.get(b)));
        const rest = [...entry.rows.keys()].filter(row => !entry.at.has(row));
        return {
            name: entry.name,
            scenario: entry.scenario,
            kind: entry.kind,
            from: entry.from,
            runs: entry.runs,
            detail: entry.detail,
            rows: [...stepRows, ...rest].map(row => {
                const values = Array.from({ length: width }, (_, i) => entry.rows.get(row)[i] ?? null);
                return { row, values, stats: stats(values) };
            })
        };
    });
}

function aggregateBoots(results) {
    const records = results.map(result => {
        const spans = result.spans.map(span => {
            if (span.name !== "boot")
                return span;
            const offset = result.offset ?? 0;
            const steps = [["trace started", 0], ...span.steps];
            if (result.answered >= 0)
                steps.push(["ipc answers", result.answered - offset]);
            return Object.assign({}, span, {
                from: "process started",
                steps: steps.map(([l, at]) => [l, at + offset]).sort((a, b) => a[1] - b[1])
            });
        });
        return { scenario: "boot", run: result.run, calls: [], spans };
    });
    return aggregate(records);
}

function aggregateLive(spans) {
    const byName = new Map();
    for (const span of spans) {
        if (!byName.has(span.name))
            byName.set(span.name, []);
        byName.get(span.name).push(span);
    }
    return [...byName.values()].flatMap(list => aggregate(list.map((span, i) => ({ scenario: "live", run: i + 1, calls: [], spans: [span] }))));
}

function ms(ns, raw) {
    if (ns === null || ns === undefined)
        return "-";
    if (raw)
        return String(Math.round(ns));
    return (ns / 1e6).toFixed(3);
}

function table(ops, raw) {
    const lines = [];
    const unit = raw ? "ns" : "ms";
    const cols = ["first", "last", "mean", "median", "min", "max"];
    for (const op of ops) {
        lines.push("");
        lines.push(`${op.name}  (${op.runs.length} runs, ${unit}${op.kind === "span" ? `, each step timed from the one before it, the first from ${op.from}` : ""})`);
        const width = Math.max(28, ...op.rows.map(r => r.row.length + 2));
        lines.push(`  ${"".padEnd(width)}${cols.map(c => c.padStart(12)).join("")}`);
        for (const { row, stats: s } of op.rows) {
            if (!s)
                continue;
            const count = row === "frames" || row === "still animating at the cap";
            const fmt = v => (count ? (v === null ? "-" : (Math.round(v * 10) / 10).toString()) : ms(v, raw));
            lines.push(`  ${row.padEnd(width)}${cols.map(c => fmt(s[c]).padStart(12)).join("")}`);
        }
        if (op.inside?.length) {
            lines.push(`  inside it, by own time per run (${unit}, calls per run):`);
            for (const item of op.inside)
                lines.push(`    ${ms(item.self, raw).padStart(10)}  ${String(Math.round(item.count * 10) / 10).padStart(6)}x  ${item.type.padEnd(14)} ${item.what}${item.name ? `  ${item.name}` : ""}`);
        }
    }
    return lines.join("\n");
}

function html(report) {
    const data = JSON.stringify(report).replace(/</g, "\\u003c");
    return `<!doctype html>
<meta charset="utf-8">
<title>banditshell timings</title>
<style>
body { font: 13px/1.45 ui-monospace, monospace; background: #15161a; color: #d6d6dc; margin: 24px; }
h1 { font-size: 18px; margin: 0 0 4px; } h2 { font-size: 14px; margin: 28px 0 6px; color: #fff; }
.meta { color: #8a8a96; } table { border-collapse: collapse; margin-top: 4px; }
td, th { padding: 2px 10px; text-align: right; white-space: nowrap; } th { color: #8a8a96; font-weight: normal; }
td:first-child, th:first-child { text-align: left; } tr:hover td { background: #22232a; }
.bar { height: 10px; display: flex; width: 640px; margin: 6px 0 2px; background: #22232a; }
.bar span { height: 100%; } .slow { color: #ff8a7a; } .legend span { margin-right: 14px; }
</style>
<h1>banditshell timings</h1>
<div class="meta" id="meta"></div>
<div id="ops"></div>
<script>
const report = ${data};
const hues = ["#7aa2f7", "#9ece6a", "#e0af68", "#bb9af7", "#7dcfff", "#f7768e", "#73daca", "#ff9e64"];
const msOf = ns => ns === null ? "-" : (ns / 1e6).toFixed(3);
document.getElementById("meta").textContent = report.when + ", " + report.where + ", " + report.runs + " runs each; hover a value for nanoseconds";
const root = document.getElementById("ops");
for (const op of report.ops) {
  const h = document.createElement("h2"); h.textContent = op.name; root.appendChild(h);
  const steps = op.rows.filter(r => r.row.startsWith("> ") && r.stats);
  const total = op.rows.find(r => r.row === "total")?.stats;
  if (steps.length && total && total.max > 0) {
    for (const which of ["first", "mean"]) {
      const bar = document.createElement("div"); bar.className = "bar"; bar.title = which;
      const scale = Math.max(total.first ?? 0, total.mean) || 1;
      steps.forEach((r, i) => { const v = r.stats[which] ?? 0; const s = document.createElement("span");
        s.style.width = (640 * v / scale) + "px"; s.style.background = hues[i % hues.length]; s.title = which + ": " + r.row + " " + msOf(v) + " ms"; bar.appendChild(s); });
      root.appendChild(bar);
    }
    const legend = document.createElement("div"); legend.className = "legend meta";
    steps.forEach((r, i) => { const s = document.createElement("span"); s.innerHTML = '<b style="color:' + hues[i % hues.length] + '">&#9632;</b> ' + r.row; legend.appendChild(s); });
    root.appendChild(legend);
  }
  const t = document.createElement("table");
  t.innerHTML = "<tr><th></th><th>first</th><th>last</th><th>mean</th><th>median</th><th>min</th><th>max</th><th>every run</th></tr>";
  for (const r of op.rows) {
    if (!r.stats) continue;
    const tr = document.createElement("tr");
    const count = r.row === "frames" || r.row === "still animating at the cap";
    const cell = v => { const td = document.createElement("td"); td.textContent = count ? (v === null ? "-" : String(Math.round(v * 10) / 10)) : msOf(v);
      if (!count && v !== null) td.title = Math.round(v) + " ns"; if (!count && v > 16.7e6 && r.row !== "total") td.className = "slow"; return td; };
    const name = document.createElement("td"); name.textContent = r.row; tr.appendChild(name);
    for (const c of ["first", "last", "mean", "median", "min", "max"]) tr.appendChild(cell(r.stats[c]));
    const all = document.createElement("td"); all.textContent = r.values.map(v => count ? (v ?? "-") : msOf(v)).join("  "); tr.appendChild(all);
    t.appendChild(tr);
  }
  root.appendChild(t);
}
</script>
`;
}

function parseArgs(argv) {
    const options = { runs: 5, boots: 0, gap: 120, only: null, out: process.cwd(), target: null, shell: null, cli: null, raw: false, where: "headless", profile: false, port: 47311 };
    for (let i = 0; i < argv.length; i++) {
        const a = argv[i];
        const next = () => argv[++i];
        if (a === "--runs") options.runs = Math.max(1, parseInt(next(), 10) || 5);
        else if (a === "--boots") options.boots = Math.max(0, parseInt(next(), 10) || 0);
        else if (a === "--gap") options.gap = Math.max(0, parseInt(next(), 10) || 0);
        else if (a === "--only") options.only = new RegExp(next(), "i");
        else if (a === "--out") options.out = next();
        else if (a === "--pid") options.target = ["--pid", next()];
        else if (a === "--path") options.target = ["-p", next()];
        else if (a === "--shell") options.shell = next();
        else if (a === "--cli") options.cli = next();
        else if (a === "--where") options.where = next();
        else if (a === "--ns") options.raw = true;
        else if (a === "--keep") options.keep = next();
        else if (a === "--profile") options.profile = true;
        else if (a === "--port") options.port = parseInt(next(), 10) || 47311;
        else options.command = options.command ?? a;
    }
    return options;
}

function write(options, ops) {
    const report = { when: new Date().toISOString(), where: options.where, runs: options.runs, ops };
    fs.mkdirSync(options.out, { recursive: true });
    fs.writeFileSync(path.join(options.out, "timings.json"), `${JSON.stringify(report, null, 1)}\n`);
    fs.writeFileSync(path.join(options.out, "timings.html"), html(report));
    return report;
}

async function main() {
    const options = parseArgs(process.argv.slice(2));
    fs.mkdirSync(options.out, { recursive: true });
    if (options.command === "report") {
        const report = JSON.parse(fs.readFileSync(path.join(options.out, "timings.json"), "utf8"));
        console.log(table(report.ops, options.raw));
        return;
    }
    if (options.command === "live-report") {
        let spans = [];
        try {
            spans = JSON.parse(fs.readFileSync(0, "utf8")).spans ?? [];
        } catch (e) {
            console.error("perf: the shell gave no trace (is it running this version?)");
        }
        if (options.keep) {
            let kept = [];
            try {
                kept = JSON.parse(fs.readFileSync(options.keep, "utf8"));
            } catch (e) {}
            spans = [...kept, ...spans];
            fs.writeFileSync(options.keep, `${JSON.stringify(spans)}\n`);
        }
        if (spans.length === 0) {
            console.log("nothing recorded yet: banditshell dev trace on, use the shell, then report");
            return;
        }
        const report = write(Object.assign(options, { runs: spans.length, where: "live session" }), aggregateLive(spans));
        console.log(table(report.ops, options.raw));
        console.log(`\n${path.join(options.out, "timings.html")}`);
        return;
    }
    let runs = [];
    let bootOps = [];
    let clock = [];
    if (options.boots > 0 && options.shell)
        bootOps = aggregateBoots(await boots(options.shell, options.boots, options.out));
    if (options.command !== "boot") {
        let child = null;
        let profiler = null;
        let shell;
        if (options.target) {
            shell = new Shell(options.target, options.cli);
        } else if (options.shell) {
            child = launch(options.shell, path.join(options.out, "shell.log"), options.profile ? options.port : 0);
            if (options.profile)
                profiler = profileStart(options.port, path.join(options.out, "trace.qtd"), path.join(options.out, "profiler.log"));
            shell = new Shell(["--pid", String(child.pid)], options.cli);
            const until = Date.now() + 60000;
            while (Date.now() < until && !shell.call("trace", "pending").ok)
                sleep(200);
            sleep(6000);
            shell.settle(20000);
        } else {
            throw new Error("give --pid, --path or --shell");
        }
        const was = shell.call("trace", "status").out;
        shell.call("trace", "on");
        runs = drive(shell, options);
        if (!/^recording/.test(was))
            shell.call("trace", "off");
        if (profiler) {
            process.stderr.write("profile: collecting\n");
            await profileStop(profiler, path.join(options.out, "trace.qtd"));
            clock = shell.clock;
        }
        if (child)
            halt(child);
    }
    fs.writeFileSync(path.join(options.out, "runs.json"), `${JSON.stringify(runs)}\n`);
    const ops = [...bootOps, ...aggregate(runs)];
    if (options.profile && fs.existsSync(path.join(options.out, "trace.qtd"))) {
        const profile = readProfile(path.join(options.out, "trace.qtd"));
        const offset = alignment(profile, clock);
        if (offset === null) {
            process.stderr.write("profile: could not line the profiler's clock up with the trace\n");
        } else {
            const inside = breakdown(runs, profile, offset);
            for (const op of ops)
                if (inside[op.name])
                    op.inside = inside[op.name];
        }
    }
    const report = write(options, ops);
    console.log(table(report.ops, options.raw));
    console.log(`\n${path.join(options.out, "timings.html")}`);
}

if (require.main === module)
    main().catch(e => {
        console.error(`perf: ${e.message}`);
        process.exit(1);
    });

module.exports = { stats, intervals, labelled, aggregate, aggregateBoots, aggregateLive, table, scenarios, parseArgs, readProfile, alignment, breakdown, where };
