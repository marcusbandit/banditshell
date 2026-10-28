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

function hypridleConfigPath(pgrepOutput, configHome) {
    for (const line of String(pgrepOutput ?? "").split("\n")) {
        const words = line.trim().split(/\s+/).slice(1);
        if (!/(^|\/)hypridle$/.test(words[0] ?? ""))
            continue;
        for (let i = 1; i < words.length; i++) {
            const given = (words[i] === "-c" || words[i] === "--config") ? words[i + 1] ?? "" : words[i].startsWith("--config=") ? words[i].slice("--config=".length) : null;
            if (given !== null)
                return given.startsWith("/") ? given : "";
        }
    }
    return `${configHome}/hypr/hypridle.conf`;
}

const IDLE_ROLES = [["sleep", /suspend|hibernate|hybrid-sleep/], ["screensOff", /dpms|power-off-monitors/], ["lock", /lock/]];

function roleOf(command) {
    const found = IDLE_ROLES.find(([, pattern]) => pattern.test(command));
    return found ? found[0] : "";
}

function hypridleTimes(text) {
    if (typeof text !== "string")
        return null;
    const vars = {};
    const listeners = [];
    let open = null;
    let sourced = false;
    for (const raw of text.split("\n")) {
        const line = raw.replace(/(^|\s)#.*$/, "").trim();
        if (/^listener\s*\{$/.test(line)) {
            open = {};
            continue;
        }
        if (line === "}" && open) {
            listeners.push(open);
            open = null;
            continue;
        }
        const pair = /^([$\w-]+)\s*=\s*(.*)$/.exec(line);
        if (!pair)
            continue;
        const value = pair[2].replace(/\$(\w+)/g, (all, name) => vars[name] ?? all);
        if (open)
            open[pair[1]] = value;
        else if (pair[1].startsWith("$"))
            vars[pair[1].slice(1)] = value;
        else if (pair[1] === "source")
            sourced = true;
    }
    const times = { lock: sourced ? null : 0, screensOff: sourced ? null : 0, sleep: sourced ? null : 0 };
    for (const l of listeners) {
        const role = roleOf(l["on-timeout"] ?? "");
        const seconds = Number(l.timeout);
        if (role && seconds > 0 && !(times[role] > 0 && times[role] <= seconds))
            times[role] = seconds;
    }
    return times;
}
