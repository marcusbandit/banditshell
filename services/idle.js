.pragma library

const MINUTE_MS = 60 * 1000;

function plan(minutes, onBattery) {
    const steps = [];
    for (const name of ["lock", "screensOff", "sleep"]) {
        const after = Number(minutes[name]);
        if (!(after > 0))
            continue;
        if (name === "sleep" && !onBattery)
            continue;
        steps.push({
            name,
            seconds: after * 60
        });
    }
    return steps.sort((a, b) => a.seconds - b.seconds);
}

const IDLE_DAEMONS = ["hypridle", "swayidle", "xidlehook", "xss-lock"];

function handlerOf(pgrepOutput) {
    for (const line of String(pgrepOutput ?? "").split("\n")) {
        const name = line.trim().split(/\s+/)[1] ?? "";
        if (IDLE_DAEMONS.includes(name))
            return name;
    }
    return "";
}
