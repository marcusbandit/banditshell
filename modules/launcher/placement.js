.pragma library

var LOWEST = 0.1;
var HIGHEST = 0.6;

function searchAt(value) {
    return Math.max(LOWEST, Math.min(HIGHEST, value));
}

function restTop(height, value, barOffset, inset, room) {
    var top = height * searchAt(value) - barOffset;
    return Math.max(inset, Math.min(height - inset - room, top));
}
