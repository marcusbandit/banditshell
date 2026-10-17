.pragma library

function scrolled(level, angleDeltaY, natural, step, ceiling) {
    var notches = angleDeltaY / 120 * (natural ? -1 : 1);
    var next = level + notches * step;
    return Math.max(0, Math.min(ceiling, Math.round(next * 1000) / 1000));
}
