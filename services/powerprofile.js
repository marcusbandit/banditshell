const daemons = {
    ppd: { saver: "power-saver", balanced: "balanced", fast: "performance" },
    tuned: { saver: "powersave", balanced: "balanced", fast: "throughput-performance" }
};

const tunedFamilies = {
    "balanced-battery": "saver",
    desktop: "balanced",
    "latency-performance": "fast",
    "network-latency": "fast",
    "network-throughput": "fast",
    "accelerator-performance": "fast"
};

const order = ["saver", "balanced", "fast"];

function nameFor(daemon, profile) {
    return daemons[daemon]?.[profile] ?? "";
}

function profileFor(daemon, name) {
    const table = daemons[daemon];
    if (!table)
        return "";
    const known = order.find(profile => table[profile] === name);
    if (known)
        return known;
    if (daemon === "tuned" && tunedFamilies[name])
        return tunedFamilies[name];
    return name;
}

function parseProbe(text) {
    const lines = String(text ?? "").split("\n");
    const daemon = (lines.find(line => line.startsWith("daemon ")) ?? "").slice(7).trim();
    if (!daemons[daemon])
        return { daemon: "", names: [] };
    const names = lines.filter(line => line.startsWith("name ")).map(line => line.slice(5).trim()).filter(Boolean);
    return { daemon, names };
}

function parseActive(daemon, text) {
    const line = String(text ?? "").trim().split("\n")[0] ?? "";
    if (daemon === "tuned")
        return /^Current active profile:\s*(\S+)/.exec(line)?.[1] ?? "";
    return /^[\w-]+$/.test(line) ? line : "";
}

function choices(daemon, names) {
    const table = daemons[daemon];
    if (!table)
        return [];
    return order.filter(profile => names.length === 0 || names.includes(table[profile]));
}
