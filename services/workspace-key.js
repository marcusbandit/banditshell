.pragma library

function isSpecial(ws) {
    if (!ws)
        return false;
    var name = String(ws.name || "");
    return ws.type === "special" || name.indexOf("special:") === 0 || (typeof ws.id === "number" && ws.id < 0);
}

function keyOf(ws) {
    if (!ws)
        return "";
    if (isSpecial(ws))
        return ws.name ? String(ws.name) : (typeof ws.id === "number" && ws.id < 0 ? "special#" + ws.id : "");
    return typeof ws.id === "number" && ws.id !== 0 ? String(ws.id) : "";
}

function shownKeys(activeId, specialName) {
    var out = [];
    if (typeof activeId === "number" && activeId !== 0)
        out.push(String(activeId));
    if (specialName)
        out.push(String(specialName));
    return out;
}

function visibleKey(activeId, specialName) {
    if (specialName)
        return String(specialName);
    return typeof activeId === "number" && activeId !== 0 ? String(activeId) : "";
}

function specialNames(workspaces, clients, monitors) {
    var out = [];
    function note(ws) {
        var key = isSpecial(ws) ? keyOf(ws) : "";
        if (key && out.indexOf(key) < 0)
            out.push(key);
    }
    var i;
    for (i = 0; i < (workspaces || []).length; i++)
        note(workspaces[i]);
    for (i = 0; i < (clients || []).length; i++)
        note(clients[i] && clients[i].workspace);
    for (i = 0; i < (monitors || []).length; i++)
        note(monitors[i] && monitors[i].specialWorkspace);
    return out;
}
