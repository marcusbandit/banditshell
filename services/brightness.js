.pragma library

function parseBacklights(text) {
    var found = [];
    var lines = String(text || "").split("\n");
    for (var i = 0; i < lines.length; i++) {
        var parts = lines[i].trim().split(",");
        if (parts.length < 5 || parts[1] !== "backlight" || !/^[A-Za-z0-9_.:-]+$/.test(parts[0]))
            continue;
        var current = parseInt(parts[2], 10);
        var max = parseInt(parts[4], 10);
        if (!(max > 0) || !(current >= 0))
            continue;
        found.push({
            name: parts[0],
            current: current,
            max: max
        });
    }
    return found;
}

function lowestFraction(lowestPercent) {
    var percent = Number(lowestPercent);
    return Math.max(1, Math.min(50, isFinite(percent) ? percent : 5)) / 100;
}

function clamp(fraction, lowestPercent) {
    var value = Number(fraction);
    if (!isFinite(value))
        value = 1;
    return Math.max(lowestFraction(lowestPercent), Math.min(1, value));
}

function stepped(fraction, direction, lowestPercent) {
    var tenths = Math.round(Number(fraction) * 1000) / 100;
    var next = direction > 0 ? Math.floor(tenths + 1) : Math.ceil(tenths - 1);
    return clamp(next / 10, lowestPercent);
}

function rawLevel(fraction, max) {
    return Math.max(1, Math.round(fraction * max));
}

function percentText(fraction) {
    return fraction >= 0 ? Math.round(fraction * 100) + "%" : "";
}
