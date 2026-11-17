.pragma library

function nextTick(position, length, rate, steps) {
    if (!(length > 0) || !(steps > 0))
        return 1000;
    const speed = rate > 0 ? rate : 1;
    const toSecond = Math.floor(position) + 1 - position;
    const step = length / steps;
    const toStep = (Math.floor(position / step) + 1) * step - position;
    return Math.max(50, Math.round(Math.min(toSecond, toStep) / speed * 1000) + 20);
}

function pixelOf(progress, travel, ratio) {
    return Math.floor(progress * travel * ratio) / ratio;
}
