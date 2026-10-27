.pragma library

var SEARCH_AT = 0.4;
var LOWEST = 0.1;
var HIGHEST = 0.6;

function searchAt(value) {
    var at = Number(value);
    if (typeof value !== "number" || !isFinite(at))
        return SEARCH_AT;
    return Math.max(LOWEST, Math.min(HIGHEST, at));
}

function restTop(height, value, barOffset, inset, room) {
    var top = height * searchAt(value) - barOffset;
    return Math.max(inset, Math.min(height - inset - room, top));
}
