.pragma library

const settle = 1500;

const pause = 3000;

const tries = 3;

function mayLook(s) {
    if (!s.ready || !s.active || s.opening || s.sleeping || s.looking || !s.sealedAt)
        return false;
    if (s.asked)
        return true;
    if (s.now - s.sealedAt < settle || s.misses >= tries)
        return false;
    return s.now - s.endedAt >= pause;
}

function waitLeft(retryAt, span, now) {
    if (!(span > 0) || retryAt <= now)
        return 0;
    return Math.min(1, (retryAt - now) / span);
}

function wanted(value) {
    if (value === true)
        return "auto";
    if (value === false)
        return "off";
    return ["auto", "gaze", "howdy", "off"].indexOf(value) >= 0 ? value : "auto";
}

function choose(want, found, order) {
    const have = order.filter(face => found.indexOf(face) >= 0);
    if (want === "auto")
        return have;
    return have.indexOf(want) >= 0 ? [want] : [];
}
