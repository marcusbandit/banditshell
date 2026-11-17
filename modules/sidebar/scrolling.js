.pragma library

var brightnessStep = 0.05;

function scrolled(level, angleDeltaY, natural, step, ceiling, floor) {
    var notches = angleDeltaY / 120 * (natural ? -1 : 1);
    var next = level + notches * step;
    return Math.max(floor || 0, Math.min(ceiling, Math.round(next * 1000) / 1000));
}
