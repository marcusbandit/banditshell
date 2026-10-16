.pragma library

var MONTHS = [["jan", "january", "januar"], ["feb", "february", "februar"], ["mar", "march", "marts"], ["apr", "april"], ["may", "maj"], ["jun", "june", "juni"], ["jul", "july", "juli"], ["aug", "august"], ["sep", "sept", "september"], ["oct", "october", "okt", "oktober"], ["nov", "november"], ["dec", "december"]];

var WEEKDAYS = [["sun", "sunday", "søndag", "sondag"], ["mon", "monday", "mandag"], ["tue", "tues", "tuesday", "tirsdag"], ["wed", "wednesday", "onsdag"], ["thu", "thur", "thurs", "thursday", "torsdag"], ["fri", "friday", "fredag"], ["sat", "saturday", "lørdag", "lordag"]];

var DAY = 86400000;

function day(y, m, d) {
    return new Date(y, m, d);
}

function startOf(now) {
    return day(now.getFullYear(), now.getMonth(), now.getDate());
}

function plusDays(date, n) {
    return day(date.getFullYear(), date.getMonth(), date.getDate() + n);
}

function plusMonths(date, n) {
    const want = date.getMonth() + n;
    const last = day(date.getFullYear(), want + 1, 0).getDate();
    return day(date.getFullYear(), want, Math.min(date.getDate(), last));
}

function between(a, b) {
    return Math.round((startOf(b) - startOf(a)) / DAY);
}

function monthOf(word) {
    const w = String(word || "").toLowerCase().replace(/\.$/, "");
    return MONTHS.findIndex(names => names.indexOf(w) >= 0);
}

function weekdayOf(word) {
    const w = String(word || "").toLowerCase();
    return WEEKDAYS.findIndex(names => names.indexOf(w) >= 0);
}

function easter(y) {
    const a = y % 19, b = Math.floor(y / 100), c = y % 100, d = Math.floor(b / 4), e = b % 4;
    const f = Math.floor((b + 8) / 25), g = Math.floor((b - f + 1) / 3);
    const h = (19 * a + b - d - g + 15) % 30, i = Math.floor(c / 4), k = c % 4;
    const l = (32 + 2 * e + 2 * i - h - k) % 7, m = Math.floor((a + 11 * h + 22 * l) / 451);
    const month = Math.floor((h + l - 7 * m + 114) / 31);
    return day(y, month - 1, (h + l - 7 * m + 114) % 31 + 1);
}

var HOLIDAYS = {
    "christmas eve": (y => day(y, 11, 24)),
    "christmas": (y => day(y, 11, 25)),
    "xmas": (y => day(y, 11, 25)),
    "jul": (y => day(y, 11, 24)),
    "juleaften": (y => day(y, 11, 24)),
    "new year's eve": (y => day(y, 11, 31)),
    "new years eve": (y => day(y, 11, 31)),
    "nytårsaften": (y => day(y, 11, 31)),
    "new year": (y => day(y, 0, 1)),
    "new year's": (y => day(y, 0, 1)),
    "new years": (y => day(y, 0, 1)),
    "halloween": (y => day(y, 9, 31)),
    "valentine's": (y => day(y, 1, 14)),
    "valentines": (y => day(y, 1, 14)),
    "valentine's day": (y => day(y, 1, 14)),
    "valentines day": (y => day(y, 1, 14)),
    "easter": easter,
    "påske": easter
};

function valid(y, m, d) {
    const date = day(y, m, d);
    return date.getFullYear() === y && date.getMonth() === m && date.getDate() === d ? date : null;
}

function parseDate(text, now) {
    const t = String(text || "").trim().toLowerCase().replace(/\s+/g, " ").replace(/,/g, "");
    const today = startOf(now);
    if (!t)
        return null;
    if (t === "today" || t === "now" || t === "i dag")
        return {
            date: today,
            fixed: true
        };
    if (t === "tomorrow" || t === "i morgen")
        return {
            date: plusDays(today, 1),
            fixed: true
        };
    if (t === "yesterday" || t === "i går")
        return {
            date: plusDays(today, -1),
            fixed: true
        };
    let m = /^(next|last|this|på|sidste|næste) (\S+)$/.exec(t);
    if (m && weekdayOf(m[2]) >= 0) {
        const want = weekdayOf(m[2]);
        const back = m[1] === "last" || m[1] === "sidste";
        let step = back ? (today.getDay() - want + 7) % 7 || 7 : (want - today.getDay() + 7) % 7;
        if (!back && (m[1] === "next" || m[1] === "næste") && step === 0)
            step = 7;
        return {
            date: plusDays(today, back ? -step : step),
            fixed: true
        };
    }
    m = /^(\d{4})-(\d{1,2})-(\d{1,2})$/.exec(t);
    if (m) {
        const date = valid(+m[1], +m[2] - 1, +m[3]);
        return date ? {
            date: date,
            fixed: true
        } : null;
    }
    m = /^(\d{1,2})[./](\d{1,2})(?:[./](\d{2}|\d{4}))?$/.exec(t);
    if (m) {
        let d = +m[1], mo = +m[2];
        if (mo > 12 && d <= 12)
            [d, mo] = [mo, d];
        const y = m[3] ? (m[3].length === 2 ? 2000 + +m[3] : +m[3]) : today.getFullYear();
        const date = valid(y, mo - 1, d);
        return date ? {
            date: date,
            fixed: !!m[3]
        } : null;
    }
    m = /^(\d{1,2})(?:st|nd|rd|th|\.)? (?:of )?([a-zæøå]+\.?)(?: (\d{4}))?$/.exec(t) || /^([a-zæøå]+\.?) (\d{1,2})(?:st|nd|rd|th)?(?: (\d{4}))?$/.exec(t);
    if (m) {
        const dayFirst = /^\d/.test(m[1]);
        const month = monthOf(dayFirst ? m[2] : m[1]);
        const d = +(dayFirst ? m[1] : m[2]);
        if (month < 0)
            return null;
        const date = valid(m[3] ? +m[3] : today.getFullYear(), month, d);
        return date ? {
            date: date,
            fixed: !!m[3]
        } : null;
    }
    m = /^(.+?)(?: (\d{4}))?$/.exec(t);
    const holiday = m && HOLIDAYS[m[1]];
    if (holiday)
        return {
            date: holiday(m[2] ? +m[2] : today.getFullYear()),
            fixed: !!m[2],
            yearly: m[2] ? null : holiday
        };
    return null;
}

function ahead(parsed, now) {
    const today = startOf(now);
    if (parsed.fixed || parsed.date >= today)
        return parsed.date;
    return parsed.yearly ? parsed.yearly(today.getFullYear() + 1) : day(parsed.date.getFullYear() + 1, parsed.date.getMonth(), parsed.date.getDate());
}

function behind(parsed, now) {
    const today = startOf(now);
    if (parsed.fixed || parsed.date <= today)
        return parsed.date;
    return parsed.yearly ? parsed.yearly(today.getFullYear() - 1) : day(parsed.date.getFullYear() - 1, parsed.date.getMonth(), parsed.date.getDate());
}

var UNITS = {
    d: "days",
    day: "days",
    days: "days",
    dage: "days",
    dag: "days",
    w: "weeks",
    week: "weeks",
    weeks: "weeks",
    uge: "weeks",
    uger: "weeks",
    month: "months",
    months: "months",
    måned: "months",
    måneder: "months",
    y: "years",
    year: "years",
    years: "years",
    år: "years"
};

function shifted(today, n, unit) {
    return unit === "days" ? plusDays(today, n) : unit === "weeks" ? plusDays(today, 7 * n) : unit === "months" ? plusMonths(today, n) : plusMonths(today, 12 * n);
}

function isoWeek(date) {
    const d = day(date.getFullYear(), date.getMonth(), date.getDate() + 3 - (date.getDay() + 6) % 7);
    const first = day(d.getFullYear(), 0, 4);
    return 1 + Math.round(((d - first) / DAY - 3 + (first.getDay() + 6) % 7) / 7);
}

function dateAsk(text, now) {
    const t = String(text || "").trim().toLowerCase().replace(/\s+/g, " ").replace(/\?$/, "");
    const today = startOf(now);
    let m = /^(?:how many |hvor mange )?(days|weeks|dage|uger) (?:until|till|til|to|before|left until|left till) (.+)$/.exec(t);
    if (m) {
        const at = parseDate(m[2], now);
        return at ? {
            kind: "until",
            unit: UNITS[m[1]],
            date: ahead(at, now),
            days: between(today, ahead(at, now))
        } : null;
    }
    m = /^(?:how many |hvor mange )?(days|weeks|dage|uger) (?:since|from|siden|fra) (.+?)(?: (?:to|until|till|til) (.+))?$/.exec(t) || /^(?:how many |hvor mange )?(days|weeks|dage|uger) (?:between|mellem) (.+?) (?:and|og) (.+)$/.exec(t);
    if (m) {
        const a = parseDate(m[2], now);
        if (!a)
            return null;
        if (m[3]) {
            const b = parseDate(m[3], now);
            return b ? {
                kind: "between",
                unit: UNITS[m[1]],
                date: a.date,
                end: b.date,
                days: between(a.date, b.date)
            } : null;
        }
        return {
            kind: "since",
            unit: UNITS[m[1]],
            date: behind(a, now),
            days: between(behind(a, now), today)
        };
    }
    m = /^(\S+) in (\d+) (weeks?|uger?)$/.exec(t);
    if (m && weekdayOf(m[1]) >= 0) {
        const week = plusDays(today, 7 * +m[2]);
        return {
            kind: "date",
            date: plusDays(week, (weekdayOf(m[1]) + 6) % 7 - (week.getDay() + 6) % 7)
        };
    }
    m = /^(?:in|om) (\d+) (\S+)$/.exec(t) || /^(\d+) (\S+) (from now|from today|later|fra nu)$/.exec(t) || /^(\d+) (\S+) (ago|siden)$/.exec(t);
    if (m && UNITS[m[2]]) {
        const back = m[3] === "ago" || m[3] === "siden";
        return {
            kind: "date",
            date: shifted(today, back ? -m[1] : +m[1], UNITS[m[2]])
        };
    }
    if (/^(?:week|week number|what week is it|which week is it|uge|ugenummer|hvilken uge)$/.test(t))
        return {
            kind: "week",
            date: today,
            week: isoWeek(today)
        };
    m = /^(?:week (?:number )?of|what week is|which week is|uge) (.+)$/.exec(t);
    if (m) {
        const at = parseDate(m[1], now);
        return at ? {
            kind: "week",
            date: at.date,
            week: isoWeek(at.date)
        } : null;
    }
    m = /^(?:what day is|what day was|which day is|hvilken dag er) (.+)$/.exec(t);
    const plain = parseDate(m ? m[1] : t, now);
    if (plain && (m || !/^(today|now|i dag)$/.test(t)))
        return {
            kind: "date",
            date: m ? plain.date : ahead(plain, now),
            bare: !m
        };
    return null;
}
