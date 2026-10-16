.pragma library

var ADDRESS = /^[0-9A-Fa-f.:]+$/;
var USER = /^[A-Za-z_][A-Za-z0-9_.-]{0,31}$/;
var SYSTEM_BINARY = /^\/(?:usr\/)?(?:local\/)?s?bin\/tailscale$/;
var SYSTEM_PKEXEC = /^\/(?:usr\/)?s?bin\/pkexec$/;

function label(node) {
    var dns = String(node && node.DNSName || "");
    var first = dns.split(".")[0];
    return first || String(node && node.HostName || "");
}

function peerFrom(node) {
    var addresses = node.TailscaleIPs || [];
    return {
        id: String(node.ID || ""),
        name: label(node),
        host: String(node.HostName || ""),
        dns: String(node.DNSName || "").replace(/\.$/, ""),
        address: String(addresses[0] || ""),
        os: String(node.OS || ""),
        online: !!node.Online,
        exitOption: !!node.ExitNodeOption,
        exitActive: !!node.ExitNode
    };
}

function comparePeers(a, b) {
    if (a.exitActive !== b.exitActive)
        return a.exitActive ? -1 : 1;
    if (a.online !== b.online)
        return a.online ? -1 : 1;
    return a.name.localeCompare(b.name);
}

function parseStatus(text) {
    var data = null;
    try {
        data = JSON.parse(String(text || ""));
    } catch (e) {
        return null;
    }
    if (!data || typeof data !== "object")
        return null;
    var peers = [];
    var map = data.Peer || {};
    for (var key in map) {
        if (Object.prototype.hasOwnProperty.call(map, key) && map[key])
            peers.push(peerFrom(map[key]));
    }
    peers.sort(comparePeers);
    var self = data.Self ? peerFrom(data.Self) : null;
    var state = String(data.BackendState || "");
    var exit = peers.filter(function (p) {
        return p.exitActive;
    })[0] || null;
    return {
        state: state,
        running: state === "Running",
        self: self,
        tailnet: String(data.CurrentTailnet && data.CurrentTailnet.Name || ""),
        authUrl: String(data.AuthURL || ""),
        exitNode: exit ? exit.id : "",
        peers: peers,
        health: (data.Health || []).map(String)
    };
}

function stateText(state) {
    switch (state) {
    case "Running":
        return "connected";
    case "Stopped":
        return "off";
    case "Starting":
        return "starting";
    case "NeedsLogin":
        return "signed out";
    case "NeedsMachineAuth":
        return "waiting for an admin to approve this device";
    case "NoState":
        return "starting";
    }
    return state ? state.toLowerCase() : "";
}

function explain(text) {
    var said = String(text || "");
    if (/access denied|checkprefs|use 'sudo tailscale|--operator=|not permitted|permission denied/i.test(said))
        return { operator: true, text: "only root or the Tailscale operator may change it" };
    if (/failed to connect to local tailscale|tailscaled.*not running|connection refused|no such file or directory/i.test(said))
        return { operator: false, text: "tailscaled is not running" };
    if (/not (?:an|a valid) exit node|invalid exit node|no node found|does not advertise/i.test(said))
        return { operator: false, text: "that device does not offer itself as an exit node" };
    if (/needs ?login|not logged in|log in/i.test(said))
        return { operator: false, text: "signed out" };
    var line = said.split("\n").map(function (l) {
        return l.trim();
    }).filter(Boolean)[0] || "";
    return { operator: false, text: line.length > 80 ? line.slice(0, 79) + "…" : line };
}

function authUrlIn(text) {
    var m = /https:\/\/login\.tailscale\.com\/[^\s"']+/.exec(String(text || ""));
    return m ? m[0] : "";
}

function exitNodeCommand(address) {
    if (address && !ADDRESS.test(address))
        return [];
    return ["tailscale", "set", "--exit-node=" + (address || "")];
}

function operatorCommand(binary, user, pkexec) {
    if (!USER.test(String(user || "")) || !SYSTEM_BINARY.test(String(binary || "")) || !SYSTEM_PKEXEC.test(String(pkexec || "")))
        return [];
    return [pkexec, binary, "set", "--operator=" + user];
}

function matches(peer, words) {
    var want = String(words || "").toLowerCase();
    if (!want)
        return true;
    return peer.name.toLowerCase().indexOf(want) >= 0 || peer.host.toLowerCase().indexOf(want) >= 0 || peer.address.indexOf(want) === 0;
}
