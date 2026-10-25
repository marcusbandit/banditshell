.pragma library

var LOW_BATTERY_PERCENT = 20;
var TONES = { alarm: 0, accent: 1, dim: 2 };
var LIMIT = 4;
var UPDATE = { menu: "update" };
var SOUND = { menu: "audio" };

function updateEntry(state) {
    if (state.updateMode === "never")
        return null;
    if (state.update === "downloaded")
        return { key: "update", icon: "download_done", tone: "accent", title: "Update ready", opens: UPDATE };
    if (state.update === "downloading")
        return { key: "update", icon: "cloud_download", tone: "accent", title: "Update downloading", opens: UPDATE };
    if (state.update === "failed" || (state.update === "available" && state.diverged))
        return { key: "update", icon: "sync_problem", tone: "alarm", title: "Update stuck", opens: UPDATE };
    if (state.update === "available")
        return { key: "update", icon: "system_update_alt", tone: "accent", title: "Update available", opens: UPDATE };
    return null;
}

function batteryEntry(state) {
    if (!state.battery || !(state.batteryPercent < LOW_BATTERY_PERCENT))
        return null;
    var percent = Math.max(0, Math.round(state.batteryPercent));
    return {
        key: "battery",
        icon: state.batteryIcon || "battery_alert",
        tone: state.charging ? "accent" : "alarm",
        title: "Battery " + percent + (state.charging ? " percent, charging" : " percent"),
        opens: { menu: "battery" }
    };
}

function micEntry(state) {
    if (!state.micShown || !state.micStreams)
        return null;
    if (state.micMuted)
        return { key: "mic", icon: "mic_off", tone: "accent", title: "Microphone muted while something listens", opens: SOUND };
    return { key: "mic", icon: "mic", tone: "alarm", title: "Microphone in use", opens: SOUND };
}

function airplaneOn(state) {
    return !!state.wifiAvailable && !state.wifiOn && (!state.bluetoothAvailable || !state.bluetoothOn);
}

function found(state) {
    var s = state || {};
    return [
        batteryEntry(s),
        micEntry(s),
        s.recording ? { key: "recording", icon: "fiber_manual_record", tone: "alarm", title: "Recording the screen, click to stop", opens: { stops: "recording" } } : null,
        s.vpn ? { key: "vpn", icon: "vpn_lock", tone: "accent", title: "VPN is up", opens: { settings: "vpn", row: "tunnels" } } : null,
        s.awake ? { key: "awake", icon: "coffee", tone: "accent", title: "Keeping awake, click to stop", opens: { stops: "awake" } } : null,
        airplaneOn(s) ? { key: "airplane", icon: "flight", tone: "accent", title: "Airplane mode", opens: { menu: "network" } } : null,
        s.modeIcon ? { key: "mode", icon: s.modeIcon, tone: "accent", title: "Mode on", opens: { settings: "modes" } } : null,
        s.quiet && !s.modeIcon ? { key: "quiet", icon: "do_not_disturb_on", tone: "accent", title: "Do not disturb", opens: { settings: "modes", row: "dnd" } } : null,
        updateEntry(s)
    ].filter(function (e) {
        return e !== null;
    });
}

function kept(all) {
    return all.map(function (e, i) {
        return { entry: e, rank: TONES[e.tone], at: i };
    }).sort(function (a, b) {
        return a.rank - b.rank || a.at - b.at;
    }).slice(0, LIMIT).map(function (r) {
        return r.entry;
    });
}

function list(state) {
    var all = found(state);
    var keep = kept(all);
    return all.filter(function (e) {
        return keep.indexOf(e) >= 0;
    });
}

function dropped(state) {
    var all = found(state);
    var keep = kept(all);
    return all.filter(function (e) {
        return keep.indexOf(e) < 0;
    });
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
