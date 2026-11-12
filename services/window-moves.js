var NUDGE_STEP = 40;

var DIRECTIONS = {
    l: { x: -1, y: 0 },
    r: { x: 1, y: 0 },
    u: { x: 0, y: -1 },
    d: { x: 0, y: 1 }
};

function nudgeTarget(client, direction, step) {
    var way = DIRECTIONS[direction];
    if (!client || !client.floating || !way || !client.at)
        return null;
    var by = step > 0 ? step : NUDGE_STEP;
    return { x: client.at[0] + way.x * by, y: client.at[1] + way.y * by };
}

function remembered(client) {
    if (!client || !client.at || !client.size || client.fullscreen)
        return null;
    return { floating: !!client.floating, x: client.at[0], y: client.at[1], w: client.size[0], h: client.size[1] };
}

function restoreRect(saved) {
    if (!saved || !saved.floating || !(saved.w > 0) || !(saved.h > 0))
        return null;
    return { x: saved.x, y: saved.y, w: saved.w, h: saved.h };
}

function sameWorkspace(client, id) {
    return !!client.workspace && client.workspace.id === id;
}

function presetFrom(name, layout, mon, clients) {
    var id = mon && mon.activeWorkspace ? mon.activeWorkspace.id : null;
    var windows = [];
    for (var i = 0; i < (clients || []).length; i++) {
        var c = clients[i];
        if (c.mapped === false || !c.class || !sameWorkspace(c, id) || !c.at || !c.size)
            continue;
        windows.push({
            class: c.class,
            floating: !!c.floating,
            x: c.at[0] - mon.x,
            y: c.at[1] - mon.y,
            w: c.size[0],
            h: c.size[1]
        });
    }
    return { name: String(name || "").trim(), layout: layout || "", windows: windows };
}

function presetPlan(preset, mon, clients) {
    var id = mon && mon.activeWorkspace ? mon.activeWorkspace.id : null;
    var free = (clients || []).filter(function (c) {
        return c.mapped !== false && sameWorkspace(c, id);
    });
    var plan = [];
    var windows = (preset && preset.windows) || [];
    for (var i = 0; i < windows.length; i++) {
        var want = windows[i];
        var at = -1;
        for (var j = 0; j < free.length; j++)
            if (free[j].class === want.class) {
                at = j;
                break;
            }
        if (at < 0)
            continue;
        var client = free.splice(at, 1)[0];
        plan.push({
            address: client.address,
            floating: !!want.floating,
            rect: want.floating ? { x: mon.x + want.x, y: mon.y + want.y, w: want.w, h: want.h } : null
        });
    }
    return plan;
}

function presetId(name) {
    return String(name || "").trim().toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
}

function withPreset(list, preset) {
    var id = presetId(preset.name);
    var kept = (list || []).filter(function (p) {
        return p && presetId(p.name) !== id;
    });
    return kept.concat([Object.assign({ id: id }, preset)]);
}

function withoutPreset(list, id) {
    return (list || []).filter(function (p) {
        return p && p.id !== id;
    });
}
