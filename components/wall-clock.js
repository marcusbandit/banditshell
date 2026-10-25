.pragma library

function floorTo(now, span) {
    const offset = span > 60000 ? new Date(now).getTimezoneOffset() * 60000 : 0;
    return now - (now - offset) % span;
}

function after(now, span) {
    return floorTo(now, span) + span;
}
