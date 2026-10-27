.pragma library

let phase = 0;
let lastAt = -Infinity;
let anchorAt = 0;

function phaseAt(now, period) {
    if (now - lastAt > 250)
        anchorAt = now - phase * period;
    lastAt = now;
    phase = (now - anchorAt) / period % 1;
    return phase;
}
