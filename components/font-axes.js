.pragma library

const progressSteps = 16;

function between(from, to, progress) {
    const held = Math.round(Math.max(0, Math.min(1, progress)) * progressSteps) / progressSteps;
    return from + (to - from) * held;
}

function opticalSize(value) {
    return Math.round(value);
}
