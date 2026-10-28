.pragma library

function minutesFromChoice(text) {
    const said = String(text).trim().toLowerCase();
    const hit = /^(\d+(?:\.\d+)?)\s*(min|h)$/.exec(said);
    if (!hit)
        return 0;
    return Math.round(Number(hit[1]) * (hit[2] === "h" ? 60 : 1));
}

function choiceFromMinutes(minutes) {
    const m = Number(minutes);
    if (!(m > 0))
        return "never";
    return m % 60 === 0 ? `${m / 60} h` : `${m} min`;
}

function choiceFromSeconds(seconds) {
    const s = Number(seconds);
    if (!(s > 0))
        return "never";
    return s < 60 ? `${Math.round(s)} s` : choiceFromMinutes(Math.round(s / 60));
}
