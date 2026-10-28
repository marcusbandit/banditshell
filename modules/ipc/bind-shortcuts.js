.pragma library

var VERBS = ["toggle", "open", "close"];
var BARE = ["session", "clipboard", "media", "calculator", "quickcontrols"];
var SCREENED = ["keyboard", "notifications", "island", "hotkeys", "files", "wallpaper"];
var MENUS = ["audio", "network", "bluetooth", "battery", "calendar", "clock", "update"];

function served(name) {
    return name === "launcher" || BARE.indexOf(name) >= 0 || SCREENED.indexOf(name) >= 0 || MENUS.indexOf(name) >= 0;
}

function shortcutFor(id) {
    if (id === "panel.close")
        return "panel.close";
    var parts = String(id).split(".");
    var name = "";
    var verb = "";
    if (parts.length === 2 && parts[0] === "launcher") {
        name = "launcher";
        verb = parts[1];
    } else if (parts.length === 3 && parts[0] === "panel") {
        name = parts[1];
        verb = parts[2];
    }
    if (VERBS.indexOf(verb) < 0 || !served(name))
        return "";
    if (name === "launcher")
        return verb === "toggle" ? "launcher" : "launcher." + verb;
    return "panel." + name + "." + verb;
}

function names() {
    var out = ["panel.close", "launcher", "launcher.open", "launcher.close"];
    var all = BARE.concat(SCREENED, MENUS);
    for (var i = 0; i < all.length; i++)
        for (var j = 0; j < VERBS.length; j++)
            out.push("panel." + all[i] + "." + VERBS[j]);
    return out;
}

function callsFor(shortcut) {
    if (shortcut === "panel.close")
        return [["panels", "closeAll"], ["files", "close"], ["penmap", "cancel"]];
    if (shortcut === "launcher")
        return [["launcher", "toggle"]];
    if (shortcut === "launcher.open")
        return [["launcher", "open", ""]];
    if (shortcut === "launcher.close")
        return [["launcher", "close"]];
    var parts = String(shortcut).split(".");
    if (parts.length !== 3 || parts[0] !== "panel" || VERBS.indexOf(parts[2]) < 0)
        return [];
    var name = parts[1];
    var verb = parts[2];
    if (BARE.indexOf(name) >= 0)
        return [[name, verb]];
    if (SCREENED.indexOf(name) >= 0) {
        var target = name === "wallpaper" ? "wallpapers" : name;
        return [verb === "close" ? [target, "close"] : [target, verb, ""]];
    }
    if (MENUS.indexOf(name) >= 0)
        return [verb === "close" ? ["menu", "close"] : ["menu", verb, name, ""]];
    return [];
}
