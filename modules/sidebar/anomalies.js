.pragma library

var LOW_BATTERY_PERCENT = 20;
var TONES = { alarm: 0, accent: 1, dim: 2 };
var LIMIT = 4;

function updateEntry(state) {
    if (state.updateMode === "never")
        return null;
    if (state.update === "downloaded")
        return { key: "update", icon: "download_done", tone: "accent", title: "update ready" };
    if (state.update === "downloading")
        return { key: "update", icon: "cloud_download", tone: "accent", title: "update downloading" };
    if (state.update === "failed" || (state.update === "available" && state.diverged))
        return { key: "update", icon: "sync_problem", tone: "alarm", title: "update stuck" };
    if (state.update === "available")
        return { key: "update", icon: "system_update_alt", tone: "accent", title: "update available" };
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
        title: "battery " + percent + (state.charging ? " percent, charging" : " percent")
    };
}

function micEntry(state) {
    if (!state.micShown || !state.micStreams)
        return null;
    if (state.micMuted)
        return { key: "mic", icon: "mic_off", tone: "accent", title: "microphone muted while something listens" };
    return { key: "mic", icon: "mic", tone: "alarm", title: "microphone in use" };
}

function airplaneOn(state) {
    return !!state.wifiAvailable && !state.wifiOn && (!state.bluetoothAvailable || !state.bluetoothOn);
}

function list(state) {
    var s = state || {};
    var found = [
        batteryEntry(s),
        micEntry(s),
        s.recording ? { key: "recording", icon: "fiber_manual_record", tone: "alarm", title: "recording the screen" } : null,
        s.vpn ? { key: "vpn", icon: "vpn_lock", tone: "accent", title: "vpn is up" } : null,
        airplaneOn(s) ? { key: "airplane", icon: "flight", tone: "accent", title: "airplane mode" } : null,
        s.modeIcon ? { key: "mode", icon: s.modeIcon, tone: "accent", title: "mode on" } : null,
        s.quiet && !s.modeIcon ? { key: "quiet", icon: "do_not_disturb_on", tone: "accent", title: "quiet" } : null,
        s.layout ? { key: "layout", text: s.layout, tone: "accent", title: "keyboard " + (s.layoutName || s.layout) } : null,
        updateEntry(s)
    ].filter(function (e) {
        return e !== null;
    });

    var ranked = found.map(function (e, i) {
        return { entry: e, rank: TONES[e.tone], at: i };
    }).sort(function (a, b) {
        return a.rank - b.rank || a.at - b.at;
    });

    var kept = ranked.slice(0, LIMIT).map(function (r) {
        return r.entry;
    });

    return found.filter(function (e) {
        return kept.indexOf(e) >= 0;
    });
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
