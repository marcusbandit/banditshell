.pragma library

var MINUTES = "(\\d{1,3})(?:\\s*(?:m|min|mins|minutes?))?";

var CLOCK_WORDS = "(?:until|till|til)\\s+(.+?)";

var ASKS = [
    {
        pattern: new RegExp(`^(?:focus|work)\\s+${CLOCK_WORDS}(?:\\s*,\\s*(.+))?$`, "i"),
        phase: "focus",
        until: true
    },
    {
        pattern: /^(?:focus|work)\s+on\s+(.+)$/i,
        phase: "focus",
        goalOnly: true
    },
    {
        pattern: new RegExp(`^(?:pomodoro|pomo|tomato)(?:\\s+${MINUTES}(?:\\s+${MINUTES})?)?$`, "i"),
        phase: "pomodoro"
    },
    {
        pattern: new RegExp(`^(?:focus|work)(?:\\s+for)?\\s+${MINUTES}(?:\\s+(?:on\\s+)?(\\D.*))?$`, "i"),
        phase: "focus"
    },
    {
        pattern: new RegExp(`^(?:take\\s+a\\s+)?(?:long\\s+)?break(?:\\s+for)?(?:\\s+${MINUTES})?$`, "i"),
        phase: "break"
    }
];

var LONG = /long/i;

function pomodoroAsk(text) {
    var t = String(text || "").trim();
    for (var i = 0; i < ASKS.length; i++) {
        var m = ASKS[i].pattern.exec(t);
        if (!m)
            continue;
        if (ASKS[i].until)
            return {
                phase: "focus",
                minutes: 0,
                breakMinutes: 0,
                long: false,
                until: m[1].trim(),
                goal: (m[2] || "").trim()
            };
        if (ASKS[i].goalOnly)
            return {
                phase: "focus",
                minutes: 0,
                breakMinutes: 0,
                long: false,
                goal: m[1].trim()
            };
        var first = m[1] ? Math.min(480, Number(m[1])) : 0;
        var second = m[2] ? Math.min(480, Number(m[2])) : 0;
        if (m[1] && first <= 0)
            return null;
        return {
            phase: ASKS[i].phase,
            minutes: first,
            breakMinutes: second,
            long: ASKS[i].phase === "break" && LONG.test(t),
            goal: ASKS[i].phase === "focus" ? (m[2] || "").trim() : ""
        };
    }
    return null;
}

function minutesToClock(clock, at) {
    var target = new Date(at);
    target.setHours(clock.hour, clock.minute, 0, 0);
    var minutes = Math.ceil((target.getTime() - at) / 60000);
    return minutes > 0 ? Math.min(480, minutes) : 0;
}

function nextRound(state, settings) {
    if (state.phase === "focus") {
        var longBreak = state.round % Math.max(1, settings.rounds) === 0;
        return {
            phase: longBreak ? "long" : "break",
            round: state.round,
            minutes: longBreak ? settings.longBreak : state.breakMinutes || settings.breakMinutes
        };
    }
    return {
        phase: "focus",
        round: state.phase === "long" ? 1 : state.round + 1,
        minutes: state.focusMinutes || settings.focus
    };
}

function phaseName(phase) {
    return phase === "focus" ? "Focus" : phase === "long" ? "Long break" : "Break";
}

function roundLabel(state, settings) {
    if (state.phase === "focus")
        return state.goal ? `Focus round ${state.round}: ${state.goal}` : `Focus round ${state.round}`;
    return phaseName(state.phase);
}

function minutesText(minutes) {
    return minutes === 1 ? "1 minute" : `${minutes} minutes`;
}

function notice(finished, next) {
    if (finished.phase === "focus")
        return {
            summary: finished.goal ? `Focus round ${finished.round} done: ${finished.goal}` : `Focus round ${finished.round} done`,
            body: `${phaseName(next.phase)} for ${minutesText(next.minutes)}`
        };
    return {
        summary: `${phaseName(finished.phase)} over`,
        body: `Focus round ${next.round} for ${minutesText(next.minutes)}`
    };
}

function readState(text) {
    var parsed = null;
    try {
        parsed = JSON.parse(text);
    } catch (e) {
        return null;
    }
    if (!parsed || typeof parsed.timer !== "string" || ["focus", "break", "long"].indexOf(parsed.phase) < 0)
        return null;
    return {
        timer: parsed.timer,
        phase: parsed.phase,
        round: Math.max(0, Math.round(Number(parsed.round) || 0)),
        focusMinutes: Math.max(0, Math.round(Number(parsed.focusMinutes) || 0)),
        breakMinutes: Math.max(0, Math.round(Number(parsed.breakMinutes) || 0)),
        goal: typeof parsed.goal === "string" ? parsed.goal : ""
    };
}
