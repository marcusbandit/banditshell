.pragma library

const weightStep = 25;
const fillSteps = 10;

function weight(value) {
    return Math.round(value / weightStep) * weightStep;
}

function fill(value) {
    return Math.round(Math.max(0, Math.min(1, value)) * fillSteps) / fillSteps;
}

function opticalSize(value) {
    return Math.round(value);
}
