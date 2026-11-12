function slotFor(light) {
    return light ? "lightTheme" : "darkTheme";
}

function wantedTheme(colour, light, fromWallpaper, active, available) {
    if (fromWallpaper)
        return "";
    var name = String((colour || {})[slotFor(light)] || "");
    if (!name || name === active || available.indexOf(name) < 0)
        return "";
    return name;
}

function slotToKeep(colour, light, picked) {
    var slot = slotFor(light);
    return (colour || {})[slot] ? { key: slot, value: picked } : null;
}
