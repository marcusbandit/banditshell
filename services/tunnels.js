const KINDS = {
    ".conf": "wireguard",
    ".ovpn": "openvpn"
};

function tunnelsFrom(connections) {
    return connections.filter(connection => connection.type === "vpn" || connection.type === "wireguard").map(connection => ({
            name: connection.name,
            uuid: connection.uuid,
            kind: connection.type === "wireguard" ? "wireguard" : "vpn",
            on: connection.active
        }));
}

function merge(tunnels, wanted, troubles) {
    return tunnels.map(tunnel => {
        const target = wanted[tunnel.uuid];
        return Object.assign({}, tunnel, {
            busy: target !== undefined,
            on: target !== undefined ? target : tunnel.on,
            trouble: troubles[tunnel.uuid] ?? ""
        });
    });
}

function switchCommand(tunnel, on) {
    return on ? ["nmcli", "--wait", "30", "connection", "up", "uuid", tunnel.uuid] : ["nmcli", "connection", "down", "uuid", tunnel.uuid];
}

function explainSwitch(message, on) {
    const said = String(message ?? "");
    if (/secrets were required|no secrets|password|passphrase/i.test(said))
        return "it needs a password, and nothing here can ask for one";
    if (/not authorized|insufficient privileges/i.test(said))
        return "you are not allowed to switch it";
    if (/timeout|timed out/i.test(said))
        return "it took too long to answer";
    if (/no suitable device|no active connection|not active/i.test(said))
        return on ? "there is no connection for it to run over" : "it was not running";
    return on ? "NetworkManager could not bring it up" : "NetworkManager could not take it down";
}

function resolvePath(path, home) {
    const trimmed = String(path ?? "").trim();
    if (trimmed === "~")
        return home;
    return trimmed.startsWith("~/") ? `${home}${trimmed.slice(1)}` : trimmed;
}

function importKind(path) {
    const dot = String(path ?? "").lastIndexOf(".");
    return dot < 0 ? "" : KINDS[path.slice(dot).toLowerCase()] ?? "";
}

function importProblem(path) {
    if (!String(path ?? "").trim())
        return "type where the file is first";
    if (!importKind(path))
        return "that is not a .conf or .ovpn file";
    return "";
}

function importCommand(path) {
    return ["nmcli", "connection", "import", "type", importKind(path), "file", path];
}

function importedName(output) {
    const match = String(output ?? "").match(/Connection '(.*)' \([0-9a-f-]+\) successfully added/);
    return match ? match[1] : "";
}

function explainImport(message, kind) {
    const said = String(message ?? "");
    if (/no such file|does not exist|cannot open|not found/i.test(said))
        return "there is no file at that path";
    if (/permission denied/i.test(said))
        return "you are not allowed to read that file";
    if (/plugin|no .*vpn.*service|unknown vpn/i.test(said))
        return `NetworkManager has no ${kind} support installed`;
    if (/already exists|duplicate/i.test(said))
        return "a tunnel with that name is already there";
    if (/invalid|not valid|failed to (import|read|parse)|could not|unable to/i.test(said))
        return `NetworkManager could not read that as a ${kind} file`;
    return "NetworkManager would not import it";
}
