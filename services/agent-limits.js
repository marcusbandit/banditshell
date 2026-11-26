.pragma library

var PROVIDER_ORDER = ["claude", "antigravity", "codex"];

var PROVIDER_META = {
    claude: { name: "Claude", color: "#d97757" },
    antigravity: { name: "Antigravity", color: "#8c7bd1" },
    codex: { name: "Codex", color: "" }
};

function enabledProviders(cfg) {
    if (!cfg)
        return [];
    var list = [];
    for (var i = 0; i < PROVIDER_ORDER.length; i++) {
        var id = PROVIDER_ORDER[i];
        if (cfg[id])
            list.push(id);
    }
    return list;
}

function parseOutput(text) {
    if (!text || typeof text !== "string")
        return [];
    var trimmed = text.trim();
    if (!trimmed)
        return [];
    try {
        var parsed = JSON.parse(trimmed);
        return Array.isArray(parsed.providers) ? parsed.providers : [];
    } catch (e) {
        return [];
    }
}

function mergeReadings(previous, incoming, wanted) {
    var prevById = {};
    for (var i = 0; i < (previous || []).length; i++)
        prevById[previous[i].id] = previous[i];
    var nextById = {};
    for (var j = 0; j < (incoming || []).length; j++)
        nextById[incoming[j].id] = incoming[j];

    var out = [];
    for (var k = 0; k < wanted.length; k++) {
        var id = wanted[k];
        var fresh = nextById[id];
        var old = prevById[id];
        if (fresh && (!fresh.error || (fresh.primary && fresh.primary.length > 0)))
            out.push(fresh);
        else if (old && old.primary && old.primary.length > 0)
            out.push({
                id: old.id,
                name: old.name,
                primary: old.primary,
                extra: old.extra || [],
                error: fresh ? (fresh.error || "") : ""
            });
        else if (fresh)
            out.push(fresh);
    }
    return out;
}

function remainingPercent(usedPercent) {
    var n = Number(usedPercent);
    if (!isFinite(n))
        return 0;
    return Math.round(Math.max(0, Math.min(100, 100 - n)));
}

function remainingFraction(usedPercent) {
    var n = Number(usedPercent);
    if (!isFinite(n))
        return 0;
    return Math.max(0, Math.min(1, (100 - n) / 100));
}

function paceFraction(resetsAt, durationMins, nowMs) {
    if (!resetsAt || !durationMins || durationMins <= 0)
        return -1;
    var resetMs = Date.parse(resetsAt);
    if (!isFinite(resetMs))
        return -1;
    var durationMs = durationMins * 60000;
    var leftMs = resetMs - nowMs;
    if (leftMs <= 0)
        return 0;
    if (leftMs >= durationMs)
        return 1;
    return Math.max(0, Math.min(1, leftMs / durationMs));
}

function formatReset(resetsAt, nowMs) {
    if (!resetsAt)
        return "";
    var resetMs = Date.parse(resetsAt);
    if (!isFinite(resetMs))
        return "";
    var diffMs = Math.max(0, resetMs - nowMs);
    var totalMins = Math.floor(diffMs / 60000);
    var days = Math.floor(totalMins / 1440);
    var hours = Math.floor((totalMins % 1440) / 60);
    var mins = totalMins % 60;
    if (days > 0)
        return days + "d " + hours + "h";
    if (hours > 0)
        return hours + "h " + mins + "m";
    return Math.max(1, mins) + "m";
}

function compactEntries(providers) {
    var out = [];
    for (var i = 0; i < (providers || []).length; i++) {
        var p = providers[i];
        var primary = p.primary || [];
        if (primary.length === 0)
            continue;
        out.push({
            id: p.id,
            name: p.name || (PROVIDER_META[p.id] ? PROVIDER_META[p.id].name : p.id),
            color: PROVIDER_META[p.id] ? PROVIDER_META[p.id].color : "",
            windows: primary
        });
    }
    return out;
}

function providerColor(id, fallback) {
    var meta = PROVIDER_META[id];
    return meta && meta.color ? meta.color : fallback;
}
