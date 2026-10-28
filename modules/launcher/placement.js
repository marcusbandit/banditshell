.pragma library

var LOWEST = 0.1;
var HIGHEST = 0.6;

function searchAt(value) {
    return Math.max(LOWEST, Math.min(HIGHEST, value));
}

function restTop(height, value, barOffset, inset, room, gap) {
    var top = height * searchAt(value) - barOffset;
    return Math.max(inset, Math.min(height - inset - gap - room, top));
}

function roomBelow(height, top, inset, gap) {
    return Math.max(0, height - inset - gap - top);
}

function bornAt(from, lift, open) {
    var t = Math.max(0, Math.min(1, lift / Math.max(1, open)));
    return from * (1 - t * t * (3 - 2 * t));
}
