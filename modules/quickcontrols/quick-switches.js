.pragma library

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

function networkState(wifi, enabled, name, wired) {
    if (wifi && enabled && name)
        return name;
    if (wired)
        return "Ethernet";
    return wifi && !enabled ? "Off" : "Not connected";
}

function powerDetail(mode, battery, percent) {
    if (!battery)
        return mode;
    const level = `${Math.round(percent)}%`;
    return mode ? `${level}, ${mode}` : level;
}
