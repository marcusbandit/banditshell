.pragma library

const BREAK_MS = 5 * 60 * 1000;
const SHADER_UNSET = "[[EMPTY]]";

function beginClock(now) {
    return {
        unbrokenSince: now,
        lastSeen: now,
        nudges: 0
    };
}

function advanceClock(clock, now, idleSince, everyMinutes, enabled) {
    let unbrokenSince = clock.unbrokenSince;
    let nudges = clock.nudges;
    const everyMs = Math.max(1, everyMinutes) * 60 * 1000;

    const away = now - clock.lastSeen >= BREAK_MS || (idleSince !== null && now - idleSince >= BREAK_MS);
    if (away) {
        unbrokenSince = now;
        nudges = 0;
    }

    const unbrokenMs = now - unbrokenSince;
    const due = Math.floor(unbrokenMs / everyMs);
    let nudge = false;
    if (!enabled) {
        nudges = due;
    } else if (due > nudges) {
        nudges = due;
        nudge = true;
    }

    return {
        clock: {
            unbrokenSince,
            lastSeen: now,
            nudges
        },
        nudge,
        unbrokenMs
    };
}

function overCap(usedMinutes, capHours) {
    return usedMinutes > capHours * 60;
}

const SHADER_SUFFIX = "/assets/shaders/desaturate.frag";

function shaderOwner(optionJson, ours) {
    let current = "";
    try {
        current = String(JSON.parse(optionJson).str ?? "");
    } catch (e) {
        return "unknown";
    }
    if (current === "" || current === SHADER_UNSET)
        return "free";
    return current === ours || current.endsWith(SHADER_SUFFIX) ? "ours" : "foreign";
}

function breakNote(unbrokenMs) {
    const minutes = Math.round(unbrokenMs / 60000);
    return `${minutes} minutes without a break. stand up, look somewhere far away for a bit.`;
}
