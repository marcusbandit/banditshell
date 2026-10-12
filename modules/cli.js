.pragma library

var DAY_NAMES = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"];

function squeezed(text) {
    return String(text ?? "").trim().toLowerCase().replace(/\s+/g, "");
}

function duration(text) {
    const spec = squeezed(text);
    if (/^\d+(\.\d+)?$/.test(spec))
        return Math.round(parseFloat(spec) * 60);
    if (!/^(\d+(\.\d+)?[hms])+$/.test(spec))
        return 0;
    let total = 0;
    for (const part of spec.match(/\d+(\.\d+)?[hms]/g))
        total += parseFloat(part) * (part.endsWith("h") ? 3600 : part.endsWith("m") ? 60 : 1);
    return Math.round(total);
}

function timeOfDay(text) {
    const m = squeezed(text).match(/^(\d{1,2}):?(\d{2})?(am|pm)?$/);
    if (!m)
        return -1;
    let hour = Number(m[1]);
    const minute = m[2] === undefined ? 0 : Number(m[2]);
    if (m[3]) {
        if (hour < 1 || hour > 12)
            return -1;
        hour = (hour % 12) + (m[3] === "pm" ? 12 : 0);
    }
    return hour > 23 || minute > 59 ? -1 : hour * 60 + minute;
}

function hhmm(hour, minute) {
    return `${String(hour).padStart(2, "0")}:${String(minute).padStart(2, "0")}`;
}

function repeatDays(spec) {
    const want = squeezed(spec);
    const all = DAY_NAMES.map((name, i) => i);
    if (!want || want === "once" || want === "never")
        return [];
    if (want === "daily" || want === "everyday" || want === "all")
        return all;
    if (want === "weekdays")
        return all.slice(0, DAY_NAMES.indexOf("sat"));
    if (want === "weekends" || want === "weekend")
        return all.slice(DAY_NAMES.indexOf("sat"));
    const out = [];
    for (const part of want.split(",")) {
        const ends = part.split("-").map(word => DAY_NAMES.indexOf(word.slice(0, 3)));
        if (ends.length > 2 || ends.some(i => i < 0))
            return null;
        for (let i = ends[0]; ; i = (i + 1) % all.length) {
            if (!out.includes(i))
                out.push(i);
            if (i === ends[ends.length - 1])
                break;
        }
    }
    return out.sort((a, b) => a - b);
}

function dayWords(days) {
    const list = Array.isArray(days) ? days : [];
    const sat = DAY_NAMES.indexOf("sat");
    if (list.length === 0)
        return "once";
    if (list.length === DAY_NAMES.length)
        return "daily";
    if (list.length === sat && list.every(d => d < sat))
        return "weekdays";
    if (list.length === DAY_NAMES.length - sat && list.every(d => d >= sat))
        return "weekends";
    return list.map(d => DAY_NAMES[d]).join(",");
}

function columns(rows) {
    const width = [];
    for (const row of rows)
        row.forEach((cell, i) => width[i] = Math.max(width[i] ?? 0, String(cell).length));
    return rows.map(row => row.map((cell, i) => i === row.length - 1 ? String(cell) : String(cell).padEnd(width[i])).join("  ")).join("\n");
}

function zoneKey(text) {
    return String(text ?? "").trim().toLowerCase().replace(/[\s_]+/g, "_");
}

function zoneMatches(text, zones) {
    const want = zoneKey(text);
    const exact = zones.filter(id => zoneKey(id) === want);
    return exact.length > 0 ? exact : zones.filter(id => zoneKey(id).includes(want));
}
