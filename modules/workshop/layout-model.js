.pragma library

var KINDS = ["slot", "stack", "space", "split"];
var AXES = ["row", "column"];
var RULES = ["share", "aspect", "fraction", "pixels"];
var BUILT_IN_LAYOUTS = ["dwindle", "master", "scrolling", "monocle", "hy3"];

var MESSAGES = [
    { name: "taller", chord: "SUPER + equal", label: "taller" },
    { name: "shorter", chord: "SUPER + minus", label: "shorter" },
    { name: "wider", chord: "SUPER + SHIFT + equal", label: "wider" },
    { name: "narrower", chord: "SUPER + SHIFT + minus", label: "narrower" },
    { name: "promote", chord: "SUPER + SHIFT + RETURN", label: "promote" },
    { name: "reset", chord: "SUPER + SHIFT + 0", label: "reset sizes" }
];

var SHAPES = [
    { id: "ultrawide", label: "5120 × 1440", width: 5120, height: 1440 },
    { id: "rotated", label: "1200 × 1920", width: 1200, height: 1920 },
    { id: "wide", label: "2560 × 1440", width: 2560, height: 1440 },
    { id: "laptop", label: "1920 × 1200", width: 1920, height: 1200 }
];

function clone(value) {
    return JSON.parse(JSON.stringify(value));
}

function number(value, fallback) {
    var n = Number(value);
    return isFinite(n) ? n : fallback;
}

function clamp(value, low, high) {
    return Math.max(low, Math.min(value, high));
}

function cleanName(name) {
    var text = String(name || "").toLowerCase().replace(/[^a-z0-9_-]+/g, "-").replace(/^[^a-z]+/, "").replace(/-+$/, "");
    return text.slice(0, 40);
}

function nameProblem(name, taken) {
    if (!name)
        return "needs a name";
    if (name !== cleanName(name))
        return "letters, digits, - and _ only, starting with a letter";
    if (BUILT_IN_LAYOUTS.indexOf(name) >= 0)
        return "a built-in layout has that name";
    if ((taken || []).indexOf(name) >= 0)
        return "your Hyprland config already registers that name";
    return "";
}

function cleanSize(size) {
    var rule = size && RULES.indexOf(size.rule) >= 0 ? size.rule : "share";
    if (rule === "aspect")
        return { rule: rule, width: Math.max(1, number(size.width, 16)), height: Math.max(1, number(size.height, 9)) };
    if (rule === "fraction")
        return { rule: rule, value: clamp(number(size.value, 0.5), 0.05, 0.95) };
    if (rule === "pixels")
        return { rule: rule, value: Math.max(1, Math.round(number(size.value, 400))) };
    return { rule: rule, value: Math.max(0.05, number(size && size.value, 1)) };
}

function freshId(used, stem) {
    var n = 1;
    while (used[stem + "-" + n])
        n += 1;
    return stem + "-" + n;
}

function cleanRegion(region, used) {
    var source = region || {};
    var kind = KINDS.indexOf(source.kind) >= 0 ? source.kind : "stack";
    var children = kind === "split" && source.children && source.children.length ? source.children : null;
    if (kind === "split" && !children)
        kind = "stack";
    var id = String(source.id || "").toLowerCase().replace(/[^a-z0-9_-]+/g, "-");
    if (!id || used[id])
        id = freshId(used, kind === "split" ? "split" : kind);
    used[id] = true;
    var out = {
        id: id,
        kind: kind,
        axis: AXES.indexOf(source.axis) >= 0 ? source.axis : (kind === "split" ? "row" : "column"),
        size: cleanSize(source.size),
        collapse: !!source.collapse
    };
    if (children)
        out.children = children.map(function (child) {
            return cleanRegion(child, used);
        });
    return out;
}

function leaves(region, out) {
    var list = out || [];
    if (region.kind === "split")
        region.children.forEach(function (child) {
            leaves(child, list);
        });
    else
        list.push(region);
    return list;
}

function regionList(region, out) {
    var list = out || [];
    list.push(region);
    if (region.kind === "split")
        region.children.forEach(function (child) {
            regionList(child, list);
        });
    return list;
}

function holders(arrangement) {
    return leaves(arrangement.root).filter(function (region) {
        return region.kind === "slot" || region.kind === "stack";
    });
}

function holderIds(arrangement) {
    return holders(arrangement).map(function (region) {
        return region.id;
    });
}

function cleanArrangement(arrangement) {
    var source = arrangement || {};
    var out = {
        root: cleanRegion(source.root || { id: "all", kind: "stack" }, {}),
        order: { first: [], repeat: [] },
        when: {},
        fit: Math.max(1, Math.round(number(source.fit, 1)))
    };
    if (!holderIds(out).length)
        leaves(out.root)[0].kind = "stack";
    var ids = holderIds(out);
    var order = source.order || {};
    out.order.first = (order.first || []).map(String).filter(function (id) {
        return ids.indexOf(id) >= 0;
    });
    out.order.repeat = (order.repeat || []).map(String).filter(function (id) {
        return ids.indexOf(id) >= 0;
    });
    if (!out.order.first.length && !out.order.repeat.length && ids.length)
        out.order.repeat = ids.slice();
    var when = source.when || {};
    ["minWindows", "maxWindows", "minWidth", "maxWidth"].forEach(function (key) {
        out.when[key] = Math.max(0, Math.round(number(when[key], 0)));
    });
    return out;
}

function normalise(model) {
    var source = model || {};
    var arrangements = (source.arrangements && source.arrangements.length ? source.arrangements : [{}]).map(cleanArrangement);
    var messages = source.messages || {};
    var smallest = clamp(number(messages.smallest, 0.25), 0.05, 1);
    return {
        name: cleanName(source.name) || "drawn",
        arrangements: arrangements,
        messages: {
            step: clamp(number(messages.step, 1.25), 1.05, 3),
            smallest: smallest,
            largest: clamp(number(messages.largest, 4), 1, 20)
        }
    };
}

function problems(model) {
    var out = [];
    model.arrangements.forEach(function (arrangement, index) {
        var where = index === 0 ? "main" : "fallback " + index;
        if (!arrangement.order.repeat.length && !holders(arrangement).some(function (region) {
            return region.kind === "stack" && arrangement.order.first.indexOf(region.id) >= 0;
        }))
            out.push(where + " repeats nothing, so windows past " + arrangement.order.first.length + " pile into the last region");
    });
    return out;
}

function dealing(arrangement, count) {
    var regions = {};
    holders(arrangement).forEach(function (region) {
        regions[region.id] = region;
    });
    var first = arrangement.order.first;
    var repeat = arrangement.order.repeat;
    var fallback = holderIds(arrangement)[0];
    var members = {};
    var assigned = [];
    var room = function (id) {
        return regions[id].kind === "stack" || !(members[id] && members[id].length);
    };
    var turn = 0;
    for (var i = 0; i < count; i++) {
        var chosen = i < first.length && room(first[i]) ? first[i] : "";
        var start = turn;
        while (!chosen && turn - start < repeat.length) {
            var tried = repeat[turn % repeat.length];
            turn += 1;
            if (room(tried))
                chosen = tried;
        }
        if (!chosen && repeat.length) {
            chosen = repeat[start % repeat.length];
            turn = start + 1;
        }
        if (!chosen)
            chosen = first[Math.min(i, first.length - 1)] || fallback;
        if (!members[chosen])
            members[chosen] = [];
        members[chosen].push(i);
        assigned.push(chosen);
    }
    return { members: members, assigned: assigned };
}

function heldUnder(region, members) {
    if (region.kind === "split") {
        var total = 0;
        region.children.forEach(function (child) {
            total += heldUnder(child, members);
        });
        return total;
    }
    return members[region.id] ? members[region.id].length : 0;
}

function sizesAlong(children, length, cross, axis, scales) {
    var sizes = [];
    var fixed = 0;
    var totalWeight = 0;
    var lastShare = -1;
    for (var i = 0; i < children.length; i++) {
        var size = children[i].size;
        var scale = scales[children[i].id] || 1;
        if (size.rule === "share") {
            totalWeight += size.value * scale;
            lastShare = i;
            sizes.push(0);
            continue;
        }
        var want = 0;
        if (size.rule === "aspect")
            want = Math.floor(axis === "row" ? cross * (size.width / size.height) : cross * (size.height / size.width));
        else if (size.rule === "fraction")
            want = Math.floor(length * clamp(size.value * scale, 0.05, 0.95));
        else
            want = Math.floor(size.value);
        var got = Math.max(0, Math.min(want, Math.floor(length - fixed)));
        sizes.push(got);
        fixed += got;
    }
    var free = Math.max(0, length - fixed);
    if (lastShare < 0 && children.length)
        sizes[children.length - 1] += free;
    var given = 0;
    for (var j = 0; j < children.length; j++) {
        if (children[j].size.rule !== "share")
            continue;
        if (j === lastShare) {
            sizes[j] = free - given;
        } else {
            sizes[j] = Math.floor(free * (children[j].size.value * (scales[children[j].id] || 1)) / totalWeight);
            given += sizes[j];
        }
    }
    return sizes;
}

function placeStack(box, axis, windows, weights, out) {
    var total = 0;
    for (var i = 0; i < windows.length; i++)
        total += weights[windows[i]] || 1;
    var row = axis === "row";
    var start = row ? box.x : box.y;
    var length = row ? box.w : box.h;
    var position = start;
    for (var k = 0; k < windows.length; k++) {
        var part = k === windows.length - 1 ? (start + length - position) : Math.floor(length * (weights[windows[k]] || 1) / total);
        out[windows[k]] = row ? { x: position, y: box.y, w: part, h: box.h } : { x: box.x, y: position, w: box.w, h: part };
        position += part;
    }
}

function layoutRegion(region, box, members, state, parent, regions, windows) {
    var record = {
        id: region.id,
        kind: region.kind,
        axis: region.axis,
        rule: region.size.rule,
        parent: parent ? parent.id : "",
        parentAxis: parent ? parent.axis : "",
        x: box.x,
        y: box.y,
        w: box.w,
        h: box.h,
        windows: region.kind === "split" ? [] : (members[region.id] || []).slice()
    };
    regions.push(record);
    if (region.kind === "split") {
        var live = region.children.filter(function (child) {
            return !(child.collapse && heldUnder(child, members) === 0);
        });
        var row = region.axis === "row";
        var sizes = sizesAlong(live, row ? box.w : box.h, row ? box.h : box.w, region.axis, state.scales || {});
        var position = row ? box.x : box.y;
        for (var i = 0; i < live.length; i++) {
            var childBox = row ? { x: position, y: box.y, w: sizes[i], h: box.h } : { x: box.x, y: position, w: box.w, h: sizes[i] };
            layoutRegion(live[i], childBox, members, state, region, regions, windows);
            position += sizes[i];
        }
    } else if (record.windows.length) {
        placeStack(box, region.kind === "stack" ? region.axis : "column", record.windows, state.weights || {}, windows);
    }
}

function passes(arrangement, area, count) {
    var when = arrangement.when;
    if (when.minWindows && count < when.minWindows)
        return false;
    if (when.maxWindows && count > when.maxWindows)
        return false;
    if (when.minWidth && area.w < when.minWidth)
        return false;
    if (when.maxWidth && area.w > when.maxWidth)
        return false;
    return true;
}

function fits(arrangement, regions) {
    for (var i = 0; i < regions.length; i++) {
        var region = regions[i];
        if ((region.kind === "slot" || region.kind === "stack") && (region.w < arrangement.fit || region.h < arrangement.fit))
            return false;
    }
    return true;
}

function arrangeWith(model, index, area, count, state) {
    var arrangement = model.arrangements[index];
    var dealt = dealing(arrangement, count);
    var regions = [];
    var windows = [];
    layoutRegion(arrangement.root, { x: area.x, y: area.y, w: area.w, h: area.h }, dealt.members, state || {}, null, regions, windows);
    return { index: index, regions: regions, windows: windows, assigned: dealt.assigned };
}

function arrange(model, area, count, state) {
    var last = model.arrangements.length - 1;
    for (var i = 0; i < last; i++) {
        if (!passes(model.arrangements[i], area, count))
            continue;
        var tried = arrangeWith(model, i, area, count, state);
        if (fits(model.arrangements[i], tried.regions))
            return tried;
    }
    return arrangeWith(model, last, area, count, state);
}

function regionById(placed, id) {
    for (var i = 0; i < placed.regions.length; i++)
        if (placed.regions[i].id === id)
            return placed.regions[i];
    return null;
}

function message(model, area, count, state, active, name) {
    var next = { weights: Object.assign({}, state.weights || {}), scales: Object.assign({}, state.scales || {}) };
    if (name === "reset")
        return { weights: {}, scales: {} };
    var grows = { taller: true, wider: true }[name];
    var axis = { taller: "column", shorter: "column", wider: "row", narrower: "row" }[name];
    if (!axis || active < 0 || active >= count)
        return next;
    var limits = model.messages;
    var factor = grows ? limits.step : 1 / limits.step;
    var placed = arrange(model, area, count, state);
    var holder = regionById(placed, placed.assigned[active]);
    if (holder.kind === "stack" && holder.axis === axis) {
        next.weights[active] = Math.max(limits.smallest, Math.min((next.weights[active] || 1) * factor, limits.largest));
        return next;
    }
    var walk = holder;
    while (walk) {
        if (walk.parentAxis === axis && (walk.rule === "share" || walk.rule === "fraction")) {
            next.scales[walk.id] = Math.max(limits.smallest, Math.min((next.scales[walk.id] || 1) * factor, limits.largest));
            return next;
        }
        walk = walk.parent ? regionById(placed, walk.parent) : null;
    }
    return next;
}

function findRegion(region, id, parent) {
    if (region.id === id)
        return { region: region, parent: parent || null };
    if (region.kind !== "split")
        return null;
    for (var i = 0; i < region.children.length; i++) {
        var found = findRegion(region.children[i], id, region);
        if (found)
            return found;
    }
    return null;
}

function usedIds(arrangement) {
    var used = {};
    regionList(arrangement.root).forEach(function (region) {
        used[region.id] = true;
    });
    return used;
}

function edited(model, index, change) {
    var next = clone(model);
    change(next.arrangements[index], next);
    return normalise(next);
}

function setRegion(model, index, id, fields) {
    return edited(model, index, function (arrangement) {
        var found = findRegion(arrangement.root, id);
        if (!found)
            return;
        Object.keys(fields).forEach(function (key) {
            found.region[key] = fields[key];
        });
        if (found.region.kind === "split" && !found.region.children) {
            var used = usedIds(arrangement);
            found.region.children = [
                { id: freshId(used, "stack"), kind: "stack", axis: "column", size: { rule: "share", value: 1 } }
            ];
        }
        if (found.region.kind !== "split")
            delete found.region.children;
    });
}

function split(model, index, id, axis) {
    var made = "";
    var next = edited(model, index, function (arrangement) {
        var found = findRegion(arrangement.root, id);
        if (!found)
            return;
        var used = usedIds(arrangement);
        var region = found.region;
        made = freshId(used, "stack");
        var added = { id: made, kind: "stack", axis: axis === "row" ? "column" : "row", size: { rule: "share", value: 1 } };
        if (found.parent && found.parent.axis === axis) {
            var at = found.parent.children.indexOf(region);
            found.parent.children.splice(at + 1, 0, added);
        } else {
            var inner = clone(region);
            inner.size = { rule: "share", value: 1 };
            var wrapper = { id: freshId(used, "split"), kind: "split", axis: axis, size: region.size, collapse: region.collapse, children: [inner, added] };
            if (found.parent)
                found.parent.children[found.parent.children.indexOf(region)] = wrapper;
            else
                arrangement.root = wrapper;
        }
        arrangement.order.repeat = arrangement.order.repeat.concat([made]);
    });
    return { model: next, made: made };
}

function remove(model, index, id) {
    return edited(model, index, function (arrangement) {
        var found = findRegion(arrangement.root, id);
        if (!found || !found.parent)
            return;
        var parent = found.parent;
        parent.children.splice(parent.children.indexOf(found.region), 1);
        if (parent.children.length === 1) {
            var only = parent.children[0];
            only.size = parent.size;
            only.collapse = parent.collapse;
            var above = findRegion(arrangement.root, parent.id);
            if (above.parent)
                above.parent.children[above.parent.children.indexOf(parent)] = only;
            else
                arrangement.root = only;
        }
    });
}

function moveRegion(model, index, id, step) {
    return edited(model, index, function (arrangement) {
        var found = findRegion(arrangement.root, id);
        if (!found || !found.parent)
            return;
        var list = found.parent.children;
        var at = list.indexOf(found.region);
        var to = clamp(at + step, 0, list.length - 1);
        list.splice(at, 1);
        list.splice(to, 0, found.region);
    });
}

function setOrder(model, index, first, repeat) {
    return edited(model, index, function (arrangement) {
        arrangement.order = { first: first.slice(), repeat: repeat.slice() };
    });
}

function setWhen(model, index, key, value) {
    return edited(model, index, function (arrangement) {
        if (key === "fit")
            arrangement.fit = value;
        else
            arrangement.when[key] = value;
    });
}

function addFallback(model, from) {
    var next = clone(model);
    next.arrangements.push(clone(next.arrangements[from]));
    return normalise(next);
}

function removeArrangement(model, index) {
    if (model.arrangements.length < 2)
        return model;
    var next = clone(model);
    next.arrangements.splice(index, 1);
    return normalise(next);
}

function rename(model, name) {
    var next = clone(model);
    next.name = cleanName(name);
    return normalise(next);
}

function setMessages(model, fields) {
    var next = clone(model);
    Object.keys(fields).forEach(function (key) {
        next.messages[key] = fields[key];
    });
    return normalise(next);
}

function describeSize(size) {
    if (size.rule === "aspect")
        return size.width + ":" + size.height;
    if (size.rule === "fraction")
        return Math.round(size.value * 100) + "%";
    if (size.rule === "pixels")
        return size.value + " px";
    return "share " + (Math.round(size.value * 100) / 100);
}

function whenText(arrangement, index, total) {
    var parts = [];
    var when = arrangement.when;
    if (when.minWindows)
        parts.push(when.minWindows + "+ windows");
    if (when.maxWindows)
        parts.push("up to " + when.maxWindows + " windows");
    if (when.minWidth)
        parts.push("from " + when.minWidth + " px wide");
    if (when.maxWidth)
        parts.push("up to " + when.maxWidth + " px wide");
    if (index < total - 1 && arrangement.fit > 1)
        parts.push("regions " + arrangement.fit + " px or more");
    if (index === total - 1 && index > 0 && !parts.length)
        return "otherwise";
    return parts.join(" · ") || "when everything fits";
}

function blank(name) {
    return normalise({
        name: name || "drawn",
        arrangements: [
            {
                root: {
                    id: "root",
                    kind: "split",
                    axis: "row",
                    children: [
                        { id: "main", kind: "slot", size: { rule: "fraction", value: 0.6 } },
                        { id: "side", kind: "stack", axis: "column", collapse: true }
                    ]
                },
                order: { first: ["main"], repeat: ["side"] }
            }
        ]
    });
}

function stage(name) {
    return normalise({
        name: name || "stage-drawn",
        arrangements: [
            {
                root: {
                    id: "root",
                    kind: "split",
                    axis: "row",
                    children: [
                        { id: "left", kind: "stack", axis: "column", size: { rule: "share", value: 1 } },
                        { id: "main", kind: "slot", size: { rule: "aspect", width: 16, height: 9 } },
                        { id: "right", kind: "stack", axis: "column", size: { rule: "share", value: 1 } }
                    ]
                },
                order: { first: ["main"], repeat: ["right", "left"] }
            },
            {
                root: { id: "all", kind: "stack", axis: "column" },
                order: { first: [], repeat: ["all"] }
            }
        ],
        messages: { step: 1.25, smallest: 0.25, largest: 4 }
    });
}

function columns(name) {
    return normalise({
        name: name || "columns",
        arrangements: [
            {
                root: { id: "all", kind: "stack", axis: "row" },
                order: { first: [], repeat: ["all"] },
                when: { minWidth: 1600 }
            },
            {
                root: { id: "rows", kind: "stack", axis: "column" },
                order: { first: [], repeat: ["rows"] }
            }
        ]
    });
}

var STARTERS = [
    { id: "stage", label: "stage", make: stage },
    { id: "main", label: "main and side", make: blank },
    { id: "columns", label: "columns", make: columns }
];
