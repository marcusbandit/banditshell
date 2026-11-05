.pragma library

var FLICK_SPEED = 0.3;
var STILL_AFTER = 100;
var SMOOTHING = 15;
var NOTCH_HOLD = 400;
var HIT_REACH = 24;

function stride(base, gap, reach) {
    return Math.max(gap, reach - base);
}

function eased(speed, step, elapsed) {
    var span = Math.max(1, Math.min(100, elapsed));
    return speed + (step / span - speed) * (1 - Math.exp(-span / SMOOTHING));
}

function settled(speed, idle) {
    return idle > STILL_AFTER ? 0 : speed;
}

function flickDirection(speed) {
    if (Math.abs(speed) < FLICK_SPEED)
        return 0;
    return speed > 0 ? 1 : -1;
}

function accumulate(rest, delta, idle) {
    var carried = idle > NOTCH_HOLD || rest * delta < 0 ? 0 : rest;
    var total = carried + delta / 120;
    var whole = (total < 0 ? Math.ceil(total) : Math.floor(total)) || 0;
    return { whole: whole, rest: total - whole };
}

function notchTarget(active, pending, pendingAt, now, notches, first, last) {
    var from = pending !== null && now - pendingAt < NOTCH_HOLD ? pending : active;
    return Math.max(first, Math.min(last, from + notches));
}

function markRow(y, slot, pitch, rows) {
    var row = Math.floor((y - (slot - pitch) / 2) / pitch);
    return row >= 0 && row < rows ? row : -1;
}
