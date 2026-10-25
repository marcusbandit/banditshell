.pragma library

var ORDER = ["launcher", "island", "sidebar", "hotkeys", "settings"];

var SUMMONS = {
    launcher: { ids: ["launcher.toggle", "launcher.open", "panel.launcher.toggle", "panel.launcher.open"], global: "launcher" },
    island: { ids: ["panel.island.toggle", "panel.island.open"] },
    hotkeys: { ids: ["panel.hotkeys.toggle", "panel.hotkeys.open"] },
    settings: { ids: ["panel.settings.toggle", "panel.settings.open"] }
};

var MODIFIERS = [
    { bit: 64, name: "Super" },
    { bit: 4, name: "Ctrl" },
    { bit: 8, name: "Alt" },
    { bit: 1, name: "Shift" }
];

var KEY_NAMES = {
    space: "Space", return: "Enter", escape: "Esc", slash: "/", question: "?", comma: ",", period: ".",
    minus: "-", equal: "=", plus: "+", grave: "`", backslash: "\\", semicolon: ";", apostrophe: "'", tab: "Tab"
};

function emptyState() {
    return { status: "none", done: [] };
}

function parseState(text) {
    var raw;
    try {
        raw = JSON.parse(String(text || ""));
    } catch (e) {
        return emptyState();
    }
    if (!raw || typeof raw !== "object" || Array.isArray(raw))
        return emptyState();
    var status = ["running", "done", "skipped"].indexOf(raw.status) >= 0 ? raw.status : "none";
    var done = Array.isArray(raw.done) ? raw.done.filter(function (id) {
        return ORDER.indexOf(id) >= 0;
    }) : [];
    return { status: status, done: done };
}

function formatState(state) {
    return JSON.stringify({ status: state.status, done: state.done || [] }) + "\n";
}

function shouldStart(fresh, state) {
    if (state.status === "running")
        return true;
    return fresh === true && state.status === "none";
}

function keyText(mask, key) {
    var parts = [];
    for (var i = 0; i < MODIFIERS.length; i++)
        if ((mask & MODIFIERS[i].bit) !== 0)
            parts.push(MODIFIERS[i].name);
    var k = String(key || "");
    if (!k)
        return "";
    var named = KEY_NAMES[k.toLowerCase()];
    parts.push(named || (k.length === 1 ? k.toUpperCase() : k.charAt(0).toUpperCase() + k.slice(1)));
    return parts.join(" + ");
}

function argvOf(id, rows) {
    for (var i = 0; i < (rows || []).length; i++)
        if (rows[i].id === id)
            return rows[i].argv;
    var star = /^panel\.([a-z]+)\.(toggle|open)$/.exec(id);
    return star ? "panel " + star[1] + " " + star[2] : "";
}

function escapeWords(text) {
    return String(text).replace(/[.*+?^${}()|[\]\\]/g, "\\$&").replace(/ /g, "\\s+");
}

function summons(step, bind, rows) {
    var want = SUMMONS[step];
    if (!want || !bind || bind.dynamic || bind.submap)
        return false;
    var expr = String(bind.expr || "").trim();
    var cmd = String(bind.cmd || "").trim();
    for (var i = 0; i < want.ids.length; i++) {
        var id = want.ids[i];
        if (expr === "bs." + id || expr.indexOf("bs.action(\"" + id + "\"") === 0)
            return true;
        var spoken = "(^|[/\\s])banditshell\\s+";
        if (new RegExp(spoken + "action\\s+" + escapeWords(id) + "\\s*$").test(cmd))
            return true;
        var argv = argvOf(id, rows);
        if (argv && new RegExp(spoken + escapeWords(argv) + "\\s*$").test(cmd))
            return true;
    }
    return !!want.global && expr === "hl.dsp.global(\"banditshell:" + want.global + "\")";
}

function chordFor(step, binds, rows) {
    for (var i = 0; i < (binds || []).length; i++) {
        var b = binds[i];
        if (!summons(step, b, rows))
            continue;
        var presses = b.presses && b.presses.length ? b.presses : [{ mask: b.mask, key: b.key }];
        for (var j = 0; j < presses.length; j++) {
            var p = presses[j];
            if (p && p.key && String(p.key).indexOf("mouse:") !== 0)
                return keyText(p.mask || 0, p.key);
        }
    }
    return "";
}

function plan(env) {
    var chords = env.chords || {};
    var steps = [];
    for (var i = 0; i < ORDER.length; i++) {
        var id = ORDER[i];
        var chord = chords[id] || "";
        var gesture = "";
        if (id === "launcher" && !env.bare)
            gesture = "edge";
        else if (id === "island" && !env.bare)
            gesture = "top";
        else if (id === "sidebar")
            gesture = env.sidebar === "rail" ? "rail" : env.sidebar === "full" ? "column" : "";
        else if (id === "settings")
            gesture = env.bare ? "launcher" : "corner";
        if (id === "sidebar" && !gesture)
            continue;
        steps.push({ id: id, chord: chord, gesture: gesture, button: !chord && !gesture });
    }
    return steps;
}

function current(steps, done) {
    for (var i = 0; i < steps.length; i++)
        if (done.indexOf(steps[i].id) < 0)
            return steps[i];
    return null;
}

function numberOf(steps, id) {
    for (var i = 0; i < steps.length; i++)
        if (steps[i].id === id)
            return i + 1;
    return steps.length;
}

function begin(done, steps) {
    var kept = (done || []).slice();
    return { phase: steps && !current(steps, kept) ? "finished" : "ask", done: kept };
}

function sidebarOf(layouts) {
    var kinds = [];
    for (var name in layouts)
        kinds.push(layouts[name]);
    return kinds.indexOf("rail") >= 0 ? "rail" : kinds.indexOf("full") >= 0 ? "full" : "none";
}

function observe(machine, steps, before, after) {
    if (machine.phase === "finished")
        return machine;
    var next = { phase: machine.phase, done: machine.done.slice() };
    var here = current(steps, next.done);
    for (var i = 0; i < steps.length; i++) {
        var id = steps[i].id;
        var rose = !before[id] && !!after[id];
        if (!rose || next.done.indexOf(id) >= 0)
            continue;
        if (here && id === here.id)
            next.phase = "seen";
        else if (here && numberOf(steps, id) > numberOf(steps, here.id))
            next.done.push(id);
    }
    if (here && next.phase === "seen" && !after[here.id]) {
        next.done.push(here.id);
        next.phase = "ask";
    }
    if (!current(steps, next.done))
        next.phase = "finished";
    return next;
}

function pass(machine, steps) {
    var here = current(steps, machine.done);
    var done = machine.done.slice();
    if (here)
        done.push(here.id);
    return { phase: current(steps, done) ? "ask" : "finished", done: done };
}

function words(step, facts) {
    var f = facts || {};
    var key = step.chord;
    switch (step.id) {
    case "launcher":
        return {
            title: "The launcher",
            payoff: f.apps > 0 ? "One search for apps, files, settings and sums. " + f.apps + " apps are already in it." : "One search for apps, files, settings and sums.",
            ask: key && step.gesture ? "Press " + key + ", or drag up from the bottom edge." : key ? "Press " + key + "." : step.gesture ? "Drag up from the bottom edge." : "",
            away: "Esc puts it away again."
        };
    case "island":
        return {
            title: "The island",
            payoff: "Notifications, music, timers and the clock arrive at the top centre.",
            ask: key && step.gesture ? "Rest the pointer at the top centre, or press " + key + "." : key ? "Press " + key + "." : step.gesture ? "Rest the pointer at the top centre." : "",
            away: "Move away and it folds back up; if it stays, press Esc."
        };
    case "sidebar":
        return {
            title: step.gesture === "rail" ? "The rail" : "The sidebar",
            payoff: (f.workspaces > 0 ? "Your " + f.workspaces + " workspaces" : "Your workspaces") + ", and a mark only when something needs you.",
            ask: step.gesture === "rail" ? "Rest the pointer on the strip at the left edge." : "Press a mark in the column on the left.",
            away: step.gesture === "rail" ? "It grows into the full column. Move away and it rests again." : "Press it again, or Esc, to close the menu."
        };
    case "hotkeys":
        return {
            title: "The hotkey sheet",
            payoff: f.binds > 0 ? "All " + f.binds + " of your keys in one place, on a drawn keyboard." : "Every key you bind, in one place, on a drawn keyboard.",
            ask: key ? "Press " + key + "." : "It has no key yet. Give it one in Settings, Keys.",
            away: "Esc puts it away again."
        };
    case "settings":
        return {
            title: "Settings",
            payoff: "Theme, screens, keys and every switch, each with a preview of what it does.",
            ask: step.gesture === "corner" ? (key ? "Point into the bottom right corner and press, or press " + key + "." : "Point into the bottom right corner and press.") : key ? "Press " + key + ", or type settings in the launcher." : "Type settings in the launcher.",
            away: "The X, or the corner again, closes it."
        };
    }
    return { title: "", payoff: "", ask: "", away: "" };
}

function overlaps(a, b) {
    return a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h;
}

function place(card, target, bounds, sides, avoid, gap) {
    var clampX = function (x) {
        return Math.max(bounds.x, Math.min(x, bounds.x + bounds.w - card.w));
    };
    var clampY = function (y) {
        return Math.max(bounds.y, Math.min(y, bounds.y + bounds.h - card.h));
    };
    var midX = target.x + (target.w - card.w) / 2;
    var midY = target.y + (target.h - card.h) / 2;
    var spots = {
        right: { x: target.x + target.w + gap, y: clampY(midY) },
        left: { x: target.x - gap - card.w, y: clampY(midY) },
        above: { x: clampX(midX), y: target.y - gap - card.h },
        below: { x: clampX(midX), y: target.y + target.h + gap },
        rightTop: { x: target.x + target.w + gap, y: clampY(target.y) },
        rightBottom: { x: target.x + target.w + gap, y: clampY(target.y + target.h - card.h) },
        leftTop: { x: target.x - gap - card.w, y: clampY(target.y) },
        leftBottom: { x: target.x - gap - card.w, y: clampY(target.y + target.h - card.h) },
        centre: { x: clampX(bounds.x + (bounds.w - card.w) / 2), y: clampY(bounds.y + (bounds.h - card.h) / 2) }
    };
    var blocked = [target].concat(avoid || []);
    var first = null;
    for (var i = 0; i < sides.length; i++) {
        var s = spots[sides[i]];
        if (!s)
            continue;
        var rect = { x: s.x, y: s.y, w: card.w, h: card.h };
        if (!first)
            first = { x: clampX(s.x), y: clampY(s.y), side: sides[i] };
        var inside = rect.x >= bounds.x && rect.y >= bounds.y && rect.x + rect.w <= bounds.x + bounds.w && rect.y + rect.h <= bounds.y + bounds.h;
        var clear = blocked.every(function (b) {
            return !b || b.w <= 0 || b.h <= 0 || !overlaps(rect, b);
        });
        if (inside && clear)
            return { x: rect.x, y: rect.y, side: sides[i] };
    }
    return first || { x: clampX(bounds.x), y: clampY(bounds.y), side: "" };
}
