.pragma library

function number(value) {
    const n = Number(value);
    return value === null || value === undefined || value === "" || !isFinite(n) ? NaN : n;
}

function whole(n) {
    const r = Math.round(n);
    return r === 0 ? 0 : r;
}

function facts(current, imperial) {
    if (!current)
        return null;
    const feels = number(imperial ? current.FeelsLikeF : current.FeelsLikeC);
    const wind = number(imperial ? current.windspeedMiles : current.windspeedKmph);
    const humidity = number(current.humidity);
    const direction = String(current.winddir16Point || "").trim();
    return {
        feels: isNaN(feels) ? "" : `${whole(feels)}°`,
        wind: isNaN(wind) ? "" : `${whole(wind)} ${imperial ? "mph" : "km/h"}${direction ? " " + direction : ""}`,
        humidity: isNaN(humidity) ? "" : `${whole(humidity)}%`
    };
}

function slotTime(day, time) {
    const parts = String(day).split("-").map(Number);
    const clock = number(time);
    if (parts.length !== 3 || parts.some(p => !isFinite(p)) || isNaN(clock))
        return NaN;
    return new Date(parts[0], parts[1] - 1, parts[2], Math.floor(clock / 100), clock % 100).getTime();
}

function hours(data, now, imperial, count) {
    const days = data && data.weather;
    const out = [];
    if (!Array.isArray(days))
        return out;
    for (const day of days) {
        for (const slot of day.hourly || []) {
            const at = slotTime(day.date, slot.time);
            const temp = number(imperial ? slot.tempF : slot.tempC);
            if (isNaN(at) || isNaN(temp) || at < now - 90 * 60000)
                continue;
            const rain = number(slot.chanceofrain);
            out.push({
                at,
                hour: new Date(at).getHours(),
                temp: whole(temp),
                code: isNaN(number(slot.weatherCode)) ? 0 : number(slot.weatherCode),
                rain: isNaN(rain) ? -1 : whole(rain)
            });
            if (out.length >= count)
                return out;
        }
    }
    return out;
}
