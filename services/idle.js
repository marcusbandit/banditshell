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

function handledBy(pgrepOutput) {
    return String(pgrepOutput).trim() !== "";
}
