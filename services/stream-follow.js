.pragma library

function step(state, event, enabled, screen) {
    if (event === "loaded")
        return { seen: true, action: !enabled && screen !== "" ? "on" : "none" };
    return { seen: false, action: state.seen && enabled ? "off" : "none" };
}
