.pragma library

function gap(x, y, left, top, right, bottom) {
    const dx = Math.max(0, left - x, x - right);
    const dy = Math.max(0, top - y, y - bottom);
    return Math.sqrt(dx * dx + dy * dy);
}

function nextCheck(distance, fastest, slowest, speed) {
    if (!(distance > 0) || !(speed > 0))
        return fastest;
    return Math.max(fastest, Math.min(slowest, Math.round(distance / speed * 1000)));
}
