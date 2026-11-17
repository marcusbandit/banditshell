function slotFor(light) {
    return light ? "lightTheme" : "darkTheme";
}

function slotOf(colour, light) {
    return String((colour || {})[slotFor(light)] || "");
}

function targetFor(colour, light, neutral, active, available) {
    var name = slotOf(colour, light) || String(neutral || "");
    if (!name || name === active || available.indexOf(name) < 0)
        return "";
    return name;
}

function neutralAfter(colour, light, neutral, active) {
    return slotOf(colour, light) ? String(neutral || "") : String(active || "");
}

function slotToKeep(colour, light, picked) {
    var slot = slotFor(light);
    return (colour || {})[slot] ? { key: slot, value: picked } : null;
}
