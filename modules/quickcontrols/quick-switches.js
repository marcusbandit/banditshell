.pragma library

const powerModes = {
    saver: { label: "Energy saver", icon: "eco" },
    balanced: { label: "Balanced", icon: "balance" },
    fast: { label: "Performance", icon: "speed" }
};

function powerLabel(profile) {
    return powerModes[profile]?.label ?? "Power mode";
}

function powerIcon(profile) {
    return powerModes[profile]?.icon ?? "bolt";
}

function nextProfile(choices, profile) {
    const list = Array.isArray(choices) ? choices : [];
    if (!list.length)
        return "";
    const at = list.indexOf(profile);
    return list[(at + 1) % list.length];
}

function powerRaised(profile) {
    return !!profile && profile !== "balanced";
}
