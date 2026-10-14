const LANGUAGES = [
    { id: "en_GB.UTF-8", label: "English (UK)" },
    { id: "en_US.UTF-8", label: "English (US)" },
    { id: "da_DK.UTF-8", label: "Dansk" }
];

const FORMATS = [
    { id: "da_DK.UTF-8", label: "Denmark" },
    { id: "en_GB.UTF-8", label: "United Kingdom" },
    { id: "en_US.UTF-8", label: "United States" }
];

const FORMAT_VARIABLES = ["LC_NUMERIC", "LC_MONETARY", "LC_MEASUREMENT", "LC_PAPER"];

const COMMON_ZONES = [
    "Pacific/Honolulu",
    "America/Anchorage",
    "America/Los_Angeles",
    "America/Denver",
    "America/Chicago",
    "America/New_York",
    "America/Sao_Paulo",
    "Atlantic/Reykjavik",
    "Europe/London",
    "Europe/Berlin",
    "Europe/Copenhagen",
    "Europe/Helsinki",
    "Europe/Moscow",
    "Africa/Johannesburg",
    "Asia/Dubai",
    "Asia/Kolkata",
    "Asia/Bangkok",
    "Asia/Shanghai",
    "Asia/Tokyo",
    "Australia/Sydney",
    "Pacific/Auckland"
];

const NOT_SET_UP = "not set up on this machine";

function degrees(sign, whole, minutes, seconds) {
    const value = Number(whole) + Number(minutes) / 60 + Number(seconds || 0) / 3600;
    return sign === "-" ? -value : value;
}

function parseZoneTable(text) {
    const out = [];
    const seen = new Set();
    for (const raw of String(text || "").split("\n")) {
        if (!raw || raw.startsWith("#"))
            continue;
        const cells = raw.split("\t");
        if (cells.length < 3)
            continue;
        const at = cells[1].match(/^([+-])(\d{2})(\d{2})(\d{2})?([+-])(\d{3})(\d{2})(\d{2})?$/);
        if (!at || seen.has(cells[2]))
            continue;
        seen.add(cells[2]);
        out.push({
            zone: cells[2],
            countries: cells[0].split(","),
            lat: degrees(at[1], at[2], at[3], at[4]),
            lon: degrees(at[5], at[6], at[7], at[8])
        });
    }
    return out;
}

function distanceKm(a, b) {
    const radians = d => d * Math.PI / 180;
    const dLat = radians(b.lat - a.lat);
    const dLon = radians(b.lon - a.lon);
    const h = Math.sin(dLat / 2) ** 2 + Math.cos(radians(a.lat)) * Math.cos(radians(b.lat)) * Math.sin(dLon / 2) ** 2;
    return 6371 * 2 * Math.asin(Math.min(1, Math.sqrt(h)));
}

function nearestZone(table, place) {
    let best = null;
    let bestDistance = Infinity;
    for (const row of table) {
        const d = distanceKm(row, place);
        if (d < bestDistance) {
            best = row;
            bestDistance = d;
        }
    }
    return best ? { zone: best.zone, km: bestDistance } : null;
}

function placeOfZone(table, zone) {
    const row = table.find(r => r.zone === zone);
    return row ? { lat: row.lat, lon: row.lon } : null;
}

function parseWhereAmI(text) {
    const lat = String(text || "").match(/Latitude:\s*(-?\d+(?:[.,]\d+)?)/);
    const lon = String(text || "").match(/Longitude:\s*(-?\d+(?:[.,]\d+)?)/);
    if (!lat || !lon)
        return null;
    const place = { lat: Number(lat[1].replace(",", ".")), lon: Number(lon[1].replace(",", ".")) };
    return Math.abs(place.lat) <= 90 && Math.abs(place.lon) <= 180 ? place : null;
}

function parseLocaleStatus(text) {
    const out = {};
    for (const line of String(text || "").split("\n")) {
        const m = line.match(/^\s*(?:System Locale:)?\s*(LANG|LANGUAGE|LC_[A-Z_]+)=(\S*)\s*$/);
        if (m)
            out[m[1]] = m[2];
    }
    return out;
}

function parseLocales(text) {
    return String(text || "").split("\n").map(l => l.trim()).filter(Boolean);
}

function normalLocale(id) {
    return String(id || "").toLowerCase().replace(/utf-8/g, "utf8");
}

function hasLocale(available, id) {
    const want = normalLocale(id);
    return available.some(l => normalLocale(l) === want);
}

function languageOf(locale) {
    return locale.LANG || "";
}

function formatsOf(locale) {
    return locale.LC_NUMERIC || locale.LANG || "";
}

function sameLocale(a, b) {
    return normalLocale(a) === normalLocale(b);
}

function choices(options, available) {
    return options.map(o => [o.id, hasLocale(available, o.id) ? o.label : `${o.label} · ${NOT_SET_UP}`]);
}

function currentChoice(options, current) {
    const hit = options.find(o => sameLocale(o.id, current));
    return hit ? hit.id : current;
}

function labelOf(options, id) {
    const hit = options.find(o => sameLocale(o.id, id));
    return hit ? hit.label : id;
}

function localeArguments(locale, change) {
    const next = Object.assign({}, locale);
    if (change.language)
        next.LANG = change.language;
    if (change.formats) {
        if (!next.LANG)
            next.LANG = change.formats;
        for (const variable of FORMAT_VARIABLES)
            next[variable] = change.formats;
    }
    return Object.keys(next).filter(k => next[k]).map(k => `${k}=${next[k]}`);
}

function zoneChoices(current, places, known) {
    const out = [];
    const add = id => {
        if (id && out.indexOf(id) < 0 && (known.length === 0 || known.indexOf(id) >= 0 || id === current))
            out.push(id);
    };
    add(current);
    for (const id of places)
        add(id);
    for (const id of COMMON_ZONES)
        add(id);
    return out;
}
