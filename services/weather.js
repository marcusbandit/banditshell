var MINIMUM_RAIN = 20;

function wttrIcon(code, dark) {
    if (code === 113)
        return dark ? "clear_night" : "sunny";
    if (code === 116)
        return dark ? "partly_cloudy_night" : "partly_cloudy_day";
    if ([119, 122].indexOf(code) >= 0)
        return "cloud";
    if ([143, 248, 260].indexOf(code) >= 0)
        return "foggy";
    if ([200, 386, 389, 392, 395].indexOf(code) >= 0)
        return "thunderstorm";
    if ([179, 227, 230, 323, 326, 329, 332, 335, 338, 368, 371].indexOf(code) >= 0)
        return "weather_snowy";
    if ([182, 185, 281, 284, 311, 314, 317, 320, 350, 362, 365, 374, 377].indexOf(code) >= 0)
        return "weather_mix";
    if ([299, 302, 305, 308, 356, 359].indexOf(code) >= 0)
        return "rainy_heavy";
    if ([176, 263, 266, 293, 296, 353].indexOf(code) >= 0)
        return "rainy";
    return "cloud";
}

const WMO = [
    [[0], "sunny", "Clear sky"],
    [[1], "sunny", "Mainly clear"],
    [[2], "partly_cloudy_day", "Partly cloudy"],
    [[3], "cloud", "Overcast"],
    [[45, 48], "foggy", "Fog"],
    [[51, 53, 55], "rainy", "Drizzle"],
    [[56, 57], "weather_mix", "Freezing drizzle"],
    [[61, 63, 80, 81], "rainy", "Rain"],
    [[65, 82], "rainy_heavy", "Heavy rain"],
    [[66, 67], "weather_mix", "Freezing rain"],
    [[71, 73, 75, 77, 85, 86], "weather_snowy", "Snow"],
    [[95, 96, 99], "thunderstorm", "Thunderstorm"]
];

function wmo(code) {
    for (let i = 0; i < WMO.length; i++)
        if (WMO[i][0].indexOf(code) >= 0)
            return { icon: WMO[i][1], summary: WMO[i][2] };
    return { icon: "cloud", summary: "Cloudy" };
}

function number(value) {
    const n = Number(value);
    return isFinite(n) ? n : NaN;
}

function placeOf(data) {
    const area = data && data.nearest_area && data.nearest_area[0];
    const name = area && area.areaName && area.areaName[0] && area.areaName[0].value;
    return name ? String(name).trim() : "";
}

function coordsOf(data) {
    const area = data && data.nearest_area && data.nearest_area[0];
    if (!area)
        return null;
    const latitude = number(area.latitude);
    const longitude = number(area.longitude);
    if (isNaN(latitude) || isNaN(longitude))
        return null;
    return { latitude: latitude, longitude: longitude };
}

function middayOf(hourly) {
    if (!hourly || !hourly.length)
        return null;
    for (let i = 0; i < hourly.length; i++)
        if (String(hourly[i].time) === "1200")
            return hourly[i];
    return hourly[Math.floor(hourly.length / 2)];
}

function wttrDays(data, imperial) {
    const list = data && data.weather;
    const days = [];
    if (!list)
        return days;
    for (let i = 0; i < list.length; i++) {
        const day = list[i];
        const high = number(imperial ? day.maxtempF : day.maxtempC);
        const low = number(imperial ? day.mintempF : day.mintempC);
        if (!day.date || isNaN(high) || isNaN(low))
            continue;
        const noon = middayOf(day.hourly);
        const desc = noon && noon.weatherDesc && noon.weatherDesc[0] && noon.weatherDesc[0].value;
        let rain = -1;
        const hours = day.hourly || [];
        for (let j = 0; j < hours.length; j++) {
            const chance = number(hours[j].chanceofrain);
            if (!isNaN(chance))
                rain = Math.max(rain, chance);
        }
        days.push({
            date: String(day.date),
            high: Math.round(high),
            low: Math.round(low),
            icon: wttrIcon(noon ? number(noon.weatherCode) : 0, false),
            summary: desc ? String(desc).trim() : "",
            rain: rain
        });
    }
    return days;
}

function outlookUrl(coords, imperial) {
    return "https://api.open-meteo.com/v1/forecast?latitude=" + coords.latitude + "&longitude=" + coords.longitude + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max&timezone=auto&forecast_days=7" + (imperial ? "&temperature_unit=fahrenheit" : "");
}

function outlookDays(data) {
    const daily = data && data.daily;
    const days = [];
    if (!daily || !daily.time)
        return days;
    for (let i = 0; i < daily.time.length; i++) {
        const high = number(daily.temperature_2m_max && daily.temperature_2m_max[i]);
        const low = number(daily.temperature_2m_min && daily.temperature_2m_min[i]);
        if (isNaN(high) || isNaN(low))
            continue;
        const info = wmo(number(daily.weather_code && daily.weather_code[i]));
        const rain = daily.precipitation_probability_max ? daily.precipitation_probability_max[i] : null;
        days.push({
            date: String(daily.time[i]),
            high: Math.round(high),
            low: Math.round(low),
            icon: info.icon,
            summary: info.summary,
            rain: rain === null || rain === undefined || isNaN(number(rain)) ? -1 : Math.round(number(rain))
        });
    }
    return days;
}

function dateOf(text) {
    const parts = String(text).split("-");
    return new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
}

function weekRange(days) {
    if (!days.length)
        return { min: 0, max: 0 };
    let min = days[0].low;
    let max = days[0].high;
    for (let i = 1; i < days.length; i++) {
        min = Math.min(min, days[i].low);
        max = Math.max(max, days[i].high);
    }
    return { min: min, max: max };
}

function barOf(day, range) {
    const span = range.max - range.min;
    if (span <= 0)
        return { from: 0, to: 1 };
    return {
        from: Math.max(0, Math.min(1, (day.low - range.min) / span)),
        to: Math.max(0, Math.min(1, (day.high - range.min) / span))
    };
}

function rainText(day) {
    return day.rain >= MINIMUM_RAIN ? day.rain + "%" : "";
}

function readWttr(output) {
    const text = String(output || "");
    const cut = text.lastIndexOf("\n");
    const tail = text.slice(cut + 1).trim().split(/\s+/);
    const status = tail[0] || "";
    const exit = Number(tail[1] || 0);
    const body = cut >= 0 ? text.slice(0, cut) : "";
    if (status === "" || status === "000")
        return { failure: [5, 6, 7].indexOf(exit) >= 0 || !tail[1] ? "offline" : "service" };
    if (status !== "200")
        return { failure: /location not found|unknown location/i.test(body) ? "place" : "service" };
    let data = null;
    try {
        data = JSON.parse(body);
    } catch (e) {
        return { failure: "service" };
    }
    if (!data || !data.current_condition || !data.current_condition[0])
        return { failure: "service" };
    return { data: data };
}

function failureLook(failure) {
    if (failure === "place")
        return { icon: "wrong_location", title: "Place not found", detail: "Fix the spelling of the town in Settings", note: "", retry: false, fix: "weather.location" };
    if (failure === "service")
        return { icon: "cloud_off", title: "No answer", detail: "The weather service did not reply", note: "the weather service did not reply", retry: true };
    return { icon: "wifi_off", title: "You're offline", detail: "The weather loads when you're back online", note: "offline, updates when you're back online", retry: false };
}

function ago(then, now) {
    const minutes = Math.max(0, Math.round((now - then) / 60000));
    if (minutes < 1)
        return "just now";
    if (minutes < 60)
        return minutes + " min ago";
    const hours = Math.round(minutes / 60);
    if (hours < 24)
        return hours + " h ago";
    const days = Math.round(hours / 24);
    return days === 1 ? "yesterday" : days + " days ago";
}

var SUGGESTION_DEPTH = 6;

var FEATURE_RANK = { PPLC: 4, PPLA: 3, PPLA2: 2, PPLA3: 1 };

function placeName(location) {
    return String(location || "").split(",")[0].trim();
}

function suggestionQueries(location) {
    const name = placeName(location);
    const queries = [];
    if (name.length < 3)
        return queries;
    queries.push(name);
    for (let n = name.length - 1; n >= Math.max(3, name.length - SUGGESTION_DEPTH); n--) {
        const part = name.slice(0, n).trim();
        if (part.length >= 3 && queries.indexOf(part) < 0)
            queries.push(part);
    }
    return queries;
}

function geocodeUrl(name) {
    return "https://geocoding-api.open-meteo.com/v1/search?name=" + encodeURIComponent(name) + "&count=20&language=en&format=json";
}

function suggestionCommand(location) {
    const queries = suggestionQueries(location);
    if (!queries.length)
        return [];
    return ["curl", "-sS", "--max-time", "10", "-w", "\n"].concat(queries.map(geocodeUrl));
}

function folded(text) {
    let s = String(text || "").trim().toLowerCase();
    if (typeof s.normalize === "function")
        s = s.normalize("NFD").replace(/[̀-ͯ]/g, "");
    return s;
}

function editDistance(a, b) {
    const rows = [];
    for (let i = 0; i <= a.length; i++) {
        rows.push([i]);
        for (let j = 1; j <= b.length; j++) {
            if (i === 0) {
                rows[0].push(j);
                continue;
            }
            const cost = a[i - 1] === b[j - 1] ? 0 : 1;
            let best = Math.min(rows[i - 1][j] + 1, rows[i][j - 1] + 1, rows[i - 1][j - 1] + cost);
            if (i > 1 && j > 1 && a[i - 1] === b[j - 2] && a[i - 2] === b[j - 1])
                best = Math.min(best, rows[i - 2][j - 2] + 1);
            rows[i].push(best);
        }
    }
    return rows[a.length][b.length];
}

function geocodeResults(output) {
    const lines = String(output || "").split("\n");
    const results = [];
    for (let i = 0; i < lines.length; i++) {
        if (!lines[i].trim())
            continue;
        let data = null;
        try {
            data = JSON.parse(lines[i]);
        } catch (e) {
            continue;
        }
        const list = data && data.results;
        if (list && list.length)
            for (let j = 0; j < list.length; j++)
                results.push(list[j]);
    }
    return results;
}

function suggestPlace(location, results) {
    const typed = folded(placeName(location));
    const hint = folded(String(location || "").split(",").slice(1).join(","));
    if (typed.length < 3)
        return null;
    const allowance = typed.length <= 4 ? 1 : typed.length <= 8 ? 2 : 3;
    const candidates = [];
    for (let i = 0; i < results.length; i++) {
        const r = results[i];
        if (!r || !r.name || !/^PPL/.test(String(r.feature_code || "")))
            continue;
        const distance = editDistance(typed, folded(r.name));
        if (distance > allowance)
            continue;
        candidates.push({
            name: String(r.name),
            country: String(r.country || ""),
            text: r.country ? r.name + ", " + r.country : String(r.name),
            distance: distance,
            named: hint !== "" && (folded(r.country) === hint || folded(r.country_code) === hint),
            population: Number(r.population) || 0,
            rank: FEATURE_RANK[r.feature_code] || 0,
            order: i
        });
    }
    const anyNamed = candidates.some(c => c.named);
    const pool = candidates.filter(c => c.named || !anyNamed);
    if (pool.some(c => folded(c.text) === folded(location)))
        return null;
    const kept = pool.filter(c => c.distance > 0 || hint === "" || c.named);
    kept.sort((x, y) => x.distance - y.distance || y.population - x.population || y.rank - x.rank || x.order - y.order);
    const best = kept[0];
    return best ? { name: best.name, country: best.country, text: best.text } : null;
}
