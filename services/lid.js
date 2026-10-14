function internalOutput(name) {
    const text = String(name ?? "");
    return text.startsWith("eDP") || text.startsWith("LVDS") || text.startsWith("DSI");
}

function hasLid(sensed, outputs) {
    return !!sensed || outputs.some(output => internalOutput(output.name));
}

function externalScreens(outputs) {
    return outputs.filter(output => !output.disabled && !internalOutput(output.name)).length;
}

function chooseAction(situation, actions) {
    if (situation.external > 0)
        return actions.docked;
    return situation.onBattery ? actions.onBattery : actions.pluggedIn;
}

function closedFrom(line) {
    const heard = /'LidClosed': <(true|false)>/.exec(String(line ?? ""));
    if (heard)
        return heard[1] === "true";
    return String(line ?? "").includes("LidClosed") ? null : undefined;
}

function closedFromProperty(text) {
    try {
        const data = JSON.parse(text)?.data;
        return typeof data === "boolean" ? data : undefined;
    } catch (e) {
        return undefined;
    }
}
