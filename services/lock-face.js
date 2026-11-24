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
