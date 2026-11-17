var HEARD = 0.001;
var FLOOR_DB = -60;

var PLAIN_TITLES = /^(?:-|playback|audio stream|audio|sound|output|input|capture|record(?:ing)?|alsa (?:playback|capture)|pipewire alsa .*|simple dsp|webrtc.*)$/i;

function text(value) {
    return value === undefined || value === null ? "" : String(value);
}

function isPlumbing(props) {
    var p = props || {};
    if (/\/Internal$/.test(text(p["media.class"])))
        return true;
    return text(p["node.virtual"]) === "true" && text(p["node.passive"]) === "true";
}

function wrapped(name) {
    var m = /^PipeWire ALSA \[(.+)\]$/.exec(text(name));
    return m ? m[1] : "";
}

function identity(props) {
    var p = props || {};
    var raw = text(p["application.name"]);
    var inner = wrapped(raw);
    var binary = text(p["application.process.binary"]) || inner;
    var name = inner || raw || text(p["node.description"]) || text(p["node.name"]) || binary || "Unknown app";
    var named = !!raw && !inner && raw.toLowerCase() !== binary.toLowerCase();
    var pid = named ? "" : text(p["application.process.id"]);
    return {
        key: [binary, name, pid].join("|").toLowerCase(),
        binary: binary,
        name: name,
        named: named
    };
}

function title(props, appName) {
    var t = text((props || {})["media.name"]).trim();
    if (!t || PLAIN_TITLES.test(t))
        return "";
    var lower = t.toLowerCase();
    var app = text(appName).toLowerCase();
    var who = identity(props);
    if (lower === app || lower === who.name.toLowerCase() || lower === who.binary.toLowerCase())
        return "";
    return t;
}

function corked(props) {
    return text((props || {})["pulse.corked"]) === "true";
}

function group(streams) {
    var byKey = {};
    var order = [];
    for (var i = 0; i < streams.length; i++) {
        var s = streams[i];
        var who = identity(s.props);
        var app = byKey[who.key];
        if (!app) {
            app = byKey[who.key] = {
                key: who.key,
                binary: who.binary,
                name: who.name,
                named: who.named,
                streams: []
            };
            order.push(app);
        }
        app.streams.push(s);
    }
    return order;
}

function byName(apps, nameOf) {
    return apps.slice().sort(function (a, b) {
        var x = text(nameOf(a)).toLowerCase();
        var y = text(nameOf(b)).toLowerCase();
        return x < y ? -1 : x > y ? 1 : a.key < b.key ? -1 : a.key > b.key ? 1 : 0;
    });
}

function volumeOf(streams) {
    var most = 0;
    for (var i = 0; i < streams.length; i++)
        most = Math.max(most, streams[i].volume || 0);
    return most;
}

function mutedAll(streams) {
    if (!streams.length)
        return false;
    for (var i = 0; i < streams.length; i++)
        if (!streams[i].muted)
            return false;
    return true;
}

function state(streams, heard, watching) {
    if (!streams.length)
        return "gone";
    if (mutedAll(streams))
        return "muted";
    var audible = [];
    for (var i = 0; i < streams.length; i++)
        if (!streams[i].muted && (streams[i].volume || 0) > 0)
            audible.push(streams[i]);
    if (!audible.length)
        return "silent";
    var paused = true;
    for (var j = 0; j < audible.length; j++) {
        if (watching && heard[audible[j].id])
            return "sound";
        if (!corked(audible[j].props))
            paused = false;
    }
    if (paused)
        return "paused";
    return watching ? "silent" : "open";
}

var OUTPUT_LABELS = {
    sound: "Making sound",
    silent: "Silent",
    paused: "Paused",
    muted: "Muted",
    open: "Open",
    gone: "Gone"
};

var INPUT_LABELS = {
    sound: "Hearing sound",
    silent: "Listening",
    paused: "Paused",
    muted: "Muted",
    open: "Listening",
    gone: "Gone"
};

function label(st, listening) {
    return (listening ? INPUT_LABELS : OUTPUT_LABELS)[st] || "";
}

function names(list) {
    if (!list.length)
        return "";
    if (list.length === 1)
        return list[0];
    if (list.length === 2)
        return list[0] + " and " + list[1];
    return list[0] + ", " + list[1] + " and " + (list.length - 2) + " more";
}

function headline(sounding, total) {
    if (!total)
        return "No app has sound open";
    if (!sounding.length)
        return "Nothing is making sound";
    return names(sounding) + (sounding.length === 1 ? " is" : " are") + " making sound";
}

function summary(states) {
    var counts = { sound: 0, muted: 0, paused: 0 };
    for (var i = 0; i < states.length; i++)
        if (counts[states[i]] !== undefined)
            counts[states[i]]++;
    var parts = [];
    parts.push(states.length === 1 ? "1 app" : states.length + " apps");
    if (counts.sound)
        parts.push(counts.sound + " making sound");
    if (counts.muted)
        parts.push(counts.muted + " muted");
    if (counts.paused)
        parts.push(counts.paused + " paused");
    return parts.join(" · ");
}

function meter(peak) {
    var p = Number(peak) || 0;
    if (p <= HEARD)
        return 0;
    var db = 20 * Math.log(p) / Math.LN10;
    return Math.max(0, Math.min(1, (db - FLOOR_DB) / -FLOOR_DB));
}

function percent(v) {
    return Math.round((Number(v) || 0) * 100) + "%";
}

function routeCommand(id, sinkName) {
    if (sinkName)
        return ["pw-metadata", "-n", "default", String(id), "target.object", sinkName];
    return ["pw-metadata", "-n", "default", "-d", String(id), "target.object"];
}

