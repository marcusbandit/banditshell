.pragma library

var ASK = /^(?:speed ?test|internet speed|test (?:my )?(?:internet|connection|speed)|how fast is my (?:internet|connection))$/i;
var HOSTED = /^Hosted by (.+?) \[[^\]]*\]: ([\d.]+) ms/;
var RESULT = /^(Download|Upload): ([\d.]+) (\S+)/;
var DOWNLOADING = /^Testing download/;
var UPLOADING = /^Testing upload/;
var PINGING = /^Selecting best server|^Retrieving speedtest/;
var FAILED = /^Cannot|^ERROR|error:/i;

function ask(input) {
    return ASK.test(String(input || "").trim());
}

function fresh() {
    return {
        phase: "starting",
        server: "",
        ping: -1,
        down: -1,
        up: -1,
        unit: "Mbit/s",
        failed: ""
    };
}

function readLine(state, line) {
    var next = Object.assign({}, state);
    var text = String(line || "").trim();
    var hosted = HOSTED.exec(text);
    if (hosted) {
        next.server = hosted[1];
        next.ping = parseFloat(hosted[2]);
        next.phase = "download";
        return next;
    }
    var result = RESULT.exec(text);
    if (result) {
        next[result[1] === "Download" ? "down" : "up"] = parseFloat(result[2]);
        next.unit = result[3];
        next.phase = result[1] === "Upload" ? "done" : "upload";
        return next;
    }
    if (DOWNLOADING.test(text))
        next.phase = "download";
    else if (UPLOADING.test(text))
        next.phase = "upload";
    else if (PINGING.test(text))
        next.phase = "pinging";
    else if (FAILED.test(text))
        next.failed = text;
    return next;
}

function speed(value) {
    if (value < 0)
        return "";
    return value >= 100 ? String(Math.round(value)) : value.toFixed(1);
}

function parts(state) {
    var out = [];
    if (state.ping >= 0)
        out.push("ping " + Math.round(state.ping) + " ms");
    if (state.down >= 0)
        out.push("down " + speed(state.down) + " " + state.unit);
    if (state.up >= 0)
        out.push("up " + speed(state.up) + " " + state.unit);
    return out;
}

function summary(state) {
    return parts(state).join(" · ");
}

function headline(state) {
    if (state.down < 0 || state.up < 0)
        return "";
    return speed(state.down) + " down · " + speed(state.up) + " up";
}
