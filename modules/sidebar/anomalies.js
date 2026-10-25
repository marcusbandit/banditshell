.pragma library

var LOW_BATTERY_PERCENT = 20;
var UPDATE = { menu: "update" };
var SOUND = { menu: "audio" };
var DETAILS = "click for details";

function updateEntry(state) {
    if (state.updateMode === "never")
        return null;
    if (state.update === "downloaded")
        return { key: "update", icon: "download_done", tone: "notice", title: "Update ready", hint: DETAILS, rank: 8, opens: UPDATE };
    if (state.update === "downloading")
        return { key: "update", icon: "cloud_download", tone: "notice", title: "Update downloading", hint: DETAILS, rank: 8, opens: UPDATE };
    if (state.update === "failed" || (state.update === "available" && state.diverged))
        return { key: "update", icon: "sync_problem", tone: "warning", title: "Update stuck", hint: DETAILS, rank: 4, opens: UPDATE };
    if (state.update === "available")
        return { key: "update", icon: "system_update_alt", tone: "notice", title: "Update available", hint: DETAILS, rank: 8, opens: UPDATE };
    return null;
}

function batteryEntry(state) {
    if (!state.battery || !(state.batteryPercent < LOW_BATTERY_PERCENT))
        return null;
    var percent = Math.max(0, Math.round(state.batteryPercent));
    return {
        key: "battery",
        icon: state.batteryIcon || "battery_alert",
        tone: state.batteryLow && !state.charging ? "warning" : "notice",
        title: "Battery " + percent + (state.charging ? " percent, charging" : " percent"),
        hint: DETAILS,
        rank: state.charging ? 8 : 2,
        opens: { menu: "battery" }
    };
}

function micEntry(state) {
    if (!state.micShown || !state.micStreams)
        return null;
    if (state.micMuted)
        return { key: "mic", icon: "mic_off", tone: "notice", title: "Microphone muted while something listens", hint: "click for sound", rank: 0, opens: SOUND };
    return { key: "mic", icon: "mic", tone: "alarm", title: "Microphone in use", hint: "click for sound", rank: 0, opens: SOUND };
}

function airplaneOn(state) {
    return !!state.wifiAvailable && !state.wifiOn && (!state.bluetoothAvailable || !state.bluetoothOn);
}

function found(state) {
    var s = state || {};
    return [
        batteryEntry(s),
        micEntry(s),
        s.recording ? { key: "recording", icon: "fiber_manual_record", tone: "alarm", title: "Recording the screen", hint: "click to stop", rank: 1, opens: { stops: "recording" } } : null,
        s.vpn ? { key: "vpn", icon: "vpn_lock", tone: "notice", title: "VPN on", hint: "click for settings", rank: 5, opens: { settings: "vpn" } } : null,
        s.awake ? { key: "awake", icon: "coffee", tone: "notice", title: "Keeping awake", hint: "click to stop", rank: 7, opens: { stops: "awake" } } : null,
        airplaneOn(s) ? { key: "airplane", icon: "flight", tone: "notice", title: "Airplane mode", hint: "click for network", rank: 6, opens: { menu: "network" } } : null,
        s.modeIcon ? { key: "mode", icon: s.modeIcon, tone: "notice", title: "Mode on", hint: "click for modes", rank: 3, opens: { settings: "modes" } } : null,
        s.quiet && !s.modeIcon ? { key: "quiet", icon: "do_not_disturb_on", tone: "notice", title: "Do not disturb", hint: "click for settings", rank: 3, opens: { settings: "modes", row: "dnd" } } : null,
        updateEntry(s)
    ].filter(function (e) {
        return e !== null;
    });
}

function slotsIn(height, pitch) {
    return pitch > 0 ? Math.max(1, Math.floor(height / pitch)) : Infinity;
}

function kept(all, slots) {
    var room = slots === undefined ? Infinity : slots;
    var take = all.length <= room ? all.length : room - 1;
    return all.map(function (e, i) {
        return { entry: e, rank: e.rank, at: i };
    }).sort(function (a, b) {
        return a.rank - b.rank || a.at - b.at;
    }).slice(0, take).map(function (r) {
        return r.entry;
    });
}

function split(state, slots) {
    var all = found(state);
    var keep = kept(all, slots);
    return {
        kept: all.filter(function (e) {
            return keep.indexOf(e) >= 0;
        }),
        dropped: all.filter(function (e) {
            return keep.indexOf(e) < 0;
        })
    };
}

function list(state, slots) {
    return split(state, slots).kept;
}

function tip(entry) {
    if (!entry)
        return "";
    return entry.hint ? entry.title + ", " + entry.hint : entry.title;
}

function droppedTitle(entries) {
    if (entries.length === 0)
        return "";
    return entries.length + " more: " + entries.map(function (e) {
        return e.title;
    }).join(" · ");
}

function merge(held, wanted) {
    var next = [];
    for (var i = 0; i < held.length; i++) {
        var fresh = null;
        for (var j = 0; j < wanted.length; j++)
            if (wanted[j].key === held[i].key)
                fresh = wanted[j];
        next.push(fresh ? Object.assign({}, fresh, { present: true }) : Object.assign({}, held[i], { present: false }));
    }
    for (var k = 0; k < wanted.length; k++) {
        var known = false;
        for (var m = 0; m < held.length; m++)
            if (held[m].key === wanted[k].key)
                known = true;
        if (!known)
            next.push(Object.assign({}, wanted[k], { present: true }));
    }
    return next;
}

function without(held, key) {
    return held.filter(function (e) {
        return e.key !== key || e.present;
    });
}
