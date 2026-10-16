.pragma library

var BACKENDS = ["wf-recorder", "wl-screenrec", "gpu-screen-recorder"];
var GEOMETRY = /^(-?\d+),(-?\d+) (\d+)x(\d+)$/;
var OUTPUT = /^[A-Za-z0-9_.-]+$/;

function isRecorderName(comm) {
    var name = String(comm || "").trim();
    for (var i = 0; i < BACKENDS.length; i++) {
        if (name && name === BACKENDS[i].slice(0, 15))
            return true;
    }
    return false;
}

function pad(n) {
    return (n < 10 ? "0" : "") + n;
}

function fileName(date) {
    return "Recording " + date.getFullYear() + "-" + pad(date.getMonth() + 1) + "-" + pad(date.getDate()) + " " + pad(date.getHours()) + "." + pad(date.getMinutes()) + "." + pad(date.getSeconds()) + ".mp4";
}

function folderFor(configured, videos, home) {
    var chosen = String(configured || "").trim();
    if (chosen === "~")
        return home;
    if (chosen.indexOf("~/") === 0)
        return home + chosen.slice(1);
    if (chosen.charAt(0) === "/")
        return chosen.replace(/\/+$/, "") || "/";
    if (chosen)
        return home + "/" + chosen.replace(/\/+$/, "");
    var base = String(videos || "").trim() || home + "/Videos";
    return base.replace(/\/+$/, "") + "/Recordings";
}

function pickBackend(found) {
    for (var i = 0; i < BACKENDS.length; i++) {
        if (found.indexOf(BACKENDS[i]) >= 0)
            return BACKENDS[i];
    }
    return "";
}

function geometryParts(geometry) {
    var m = GEOMETRY.exec(String(geometry || "").trim());
    if (!m || !(parseInt(m[3], 10) > 0) || !(parseInt(m[4], 10) > 0))
        return null;
    return {
        x: parseInt(m[1], 10),
        y: parseInt(m[2], 10),
        width: parseInt(m[3], 10),
        height: parseInt(m[4], 10)
    };
}

function evenGeometry(geometry) {
    var g = geometryParts(geometry);
    if (!g)
        return "";
    var width = Math.max(2, g.width - g.width % 2);
    var height = Math.max(2, g.height - g.height % 2);
    return g.x + "," + g.y + " " + width + "x" + height;
}

function recorderCommand(backend, file, target, sound) {
    var geometry = target && target.geometry ? evenGeometry(target.geometry) : "";
    var output = target && target.output && OUTPUT.test(target.output) ? target.output : "";
    if (!file || !geometry && !output)
        return [];
    switch (backend) {
    case "wf-recorder":
        return ["wf-recorder", "-y", "-f", file].concat(geometry ? ["-g", geometry] : ["-o", output], sound ? ["--audio=@DEFAULT_MONITOR@"] : []);
    case "wl-screenrec":
        return ["wl-screenrec", "-f", file].concat(geometry ? ["-g", geometry] : ["-o", output], sound ? ["--audio", "--audio-device", "@DEFAULT_MONITOR@"] : []);
    case "gpu-screen-recorder":
        {
            var g = geometryParts(geometry);
            var where = g ? ["-w", "region", "-region", g.width + "x" + g.height + "+" + g.x + "+" + g.y] : ["-w", output];
            return ["gpu-screen-recorder"].concat(where, ["-f", "60", "-c", "mp4", "-o", file], sound ? ["-a", "default_output"] : []);
        }
    }
    return [];
}

function visibleWorkspaces(monitors) {
    var ids = [];
    for (var i = 0; i < (monitors || []).length; i++) {
        var m = monitors[i];
        if (m && m.activeWorkspace)
            ids.push(m.activeWorkspace.id);
        if (m && m.specialWorkspace && m.specialWorkspace.id)
            ids.push(m.specialWorkspace.id);
    }
    return ids;
}

function boxOf(client) {
    var at = client.at || [];
    var size = client.size || [];
    if (!(size[0] > 0) || !(size[1] > 0))
        return "";
    return at[0] + "," + at[1] + " " + size[0] + "x" + size[1];
}

function windowBoxes(clients, monitors) {
    var visible = visibleWorkspaces(monitors);
    return (clients || []).filter(function (c) {
        return c && c.mapped !== false && !c.hidden && c.workspace && visible.indexOf(c.workspace.id) >= 0 && boxOf(c);
    }).sort(function (a, b) {
        return (a.focusHistoryID || 0) - (b.focusHistoryID || 0);
    }).map(boxOf);
}

function windowBox(clients, address) {
    var want = String(address || "").replace(/^0x/, "");
    if (!want)
        return "";
    for (var i = 0; i < (clients || []).length; i++) {
        if (String(clients[i].address || "").replace(/^0x/, "") === want)
            return boxOf(clients[i]);
    }
    return "";
}

function splitDocuments(text) {
    var parts = String(text || "").split("\u001e");
    var out = [];
    for (var i = 0; i < parts.length; i++) {
        try {
            out.push(JSON.parse(parts[i]));
        } catch (e) {
            out.push(null);
        }
    }
    return out;
}

function parseState(text) {
    var lines = String(text || "").split("\n");
    var pid = parseInt(lines[0], 10);
    var started = Number(lines[1]);
    var file = lines[2] || "";
    if (!(pid > 1) || !(started > 0) || file.charAt(0) !== "/")
        return null;
    return {
        pid: pid,
        started: started,
        file: file,
        mode: lines[3] || "screen",
        sound: lines[4] === "sound"
    };
}

function parseResult(text) {
    var lines = String(text || "").split("\n");
    var status = parseInt(lines[0], 10);
    return {
        status: isFinite(status) ? status : -1,
        file: lines[1] || "",
        size: Number(lines[2]) || 0,
        complaint: lines.slice(3).map(function (l) {
            return l.trim();
        }).filter(Boolean).pop() || ""
    };
}

function modeLabel(mode) {
    return mode === "area" ? "an area" : mode === "window" ? "a window" : "the screen";
}
