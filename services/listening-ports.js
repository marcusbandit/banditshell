.pragma library

var LIST = /^(?:(tcp|udp|all)\s+)?(?:open\s+|listening\s+)?ports?(?:\s+(.*))?$/i;
var LISTENING = /^(?:listening|listeners)(?:\s+(.*))?$/i;
var WHO = /^(?:who|what)(?:'s|\s+is|\s+are)?\s+(?:using|uses|use|on|listening\s+on|listens\s+on|holding|holds|has|owns)\s+(?:(tcp|udp)\s+)?port\s+(\d{1,5})(?:\s+(tcp|udp))?\s*\??$/i;
var FREE = /^(?:kill|free|close|stop)\s+(?:(tcp|udp)\s+)?port\s+(\d{1,5})(?:\s+(tcp|udp))?$/i;
var COLON = /^:(\d{1,5})$/;
var NETIDS = ["tcp", "udp", "tcp6", "udp6", "raw", "sctp", "mptcp"];
var OWNER = /\("((?:[^"\\]|\\.)*)",pid=(\d+)/g;
var UID = /\buid:(\d+)/;
var CGROUP = /\bcgroup:(\S+)/;

function protocolOf(word) {
    return String(word || "").toLowerCase();
}

function fromWords(rest, base) {
    var out = {
        port: base.port || "",
        words: "",
        udp: !!base.udp,
        tcp: base.tcp !== false,
        quit: !!base.quit
    };
    var words = [];
    var tokens = String(rest || "").trim().split(/\s+/).filter(Boolean);
    for (var i = 0; i < tokens.length; i++) {
        var t = tokens[i].toLowerCase();
        if (t === "udp") {
            out.udp = true;
            out.tcp = false;
        } else if (t === "tcp") {
            out.tcp = true;
            out.udp = false;
        } else if (t === "all" || t === "both") {
            out.tcp = true;
            out.udp = true;
        } else if (/^:?\d{1,5}$/.test(t) && !out.port) {
            out.port = t.replace(":", "");
        } else {
            words.push(tokens[i]);
        }
    }
    out.words = words.join(" ");
    return out;
}

function withProtocol(base, word) {
    var p = protocolOf(word);
    if (p === "udp")
        return Object.assign(base, {
            udp: true,
            tcp: false
        });
    if (p === "tcp")
        return Object.assign(base, {
            udp: false,
            tcp: true
        });
    if (p === "all")
        return Object.assign(base, {
            udp: true,
            tcp: true
        });
    return base;
}

function ask(text) {
    var t = String(text || "").trim();
    var m = WHO.exec(t);
    if (m)
        return withProtocol({
            port: m[2],
            words: "",
            udp: false,
            tcp: true,
            quit: false,
            exact: true
        }, m[1] || m[3]);
    m = FREE.exec(t);
    if (m)
        return withProtocol({
            port: m[2],
            words: "",
            udp: false,
            tcp: true,
            quit: true,
            exact: true
        }, m[1] || m[3]);
    m = COLON.exec(t);
    if (m)
        return {
            port: m[1],
            words: "",
            udp: false,
            tcp: true,
            quit: false,
            exact: true
        };
    m = LIST.exec(t);
    if (m)
        return fromWords(m[2], withProtocol({
            tcp: true
        }, m[1]));
    m = LISTENING.exec(t);
    if (m)
        return fromWords(m[1], {
            tcp: true
        });
    return null;
}

function command(udp) {
    return ["ss", udp ? "-ltunpeH" : "-ltnpeH"];
}

function unescape(name) {
    return name.replace(/\\(.)/g, "$1");
}

function hostOf(local) {
    var cut = local.lastIndexOf(":");
    var host = cut < 0 ? local : local.slice(0, cut);
    return host.replace(/%[^\]]*/, "");
}

function unitOf(cgroup) {
    var parts = String(cgroup || "").split("/").filter(Boolean);
    var last = parts.length ? parts[parts.length - 1] : "";
    return {
        unit: /\.(?:service|scope)$/.test(last) ? last : "",
        system: parts[0] === "system.slice"
    };
}

function readListeners(text, fallbackProtocol) {
    var found = {};
    var order = [];
    var all = String(text || "").split("\n");
    for (var i = 0; i < all.length; i++) {
        var line = all[i].trim();
        if (!line)
            continue;
        var fields = line.split(/\s+/);
        var protocol = fallbackProtocol || "tcp";
        if (NETIDS.indexOf(fields[0].toLowerCase()) >= 0)
            protocol = fields.shift().toLowerCase().replace("6", "");
        if (fields.length < 4)
            continue;
        var local = fields[3];
        var cut = local.lastIndexOf(":");
        var port = cut < 0 ? NaN : parseInt(local.slice(cut + 1), 10);
        if (!(port > 0))
            continue;
        var owners = [];
        OWNER.lastIndex = 0;
        var m;
        while ((m = OWNER.exec(line)) !== null) {
            var pid = parseInt(m[2], 10);
            if (!owners.some(function (o) {
                    return o.pid === pid;
                }))
                owners.push({
                    name: unescape(m[1]),
                    pid: pid
                });
        }
        var uidMatch = UID.exec(line);
        var cgroupMatch = CGROUP.exec(line);
        var place = unitOf(cgroupMatch ? cgroupMatch[1] : "");
        var key = protocol + ":" + port + ":" + (owners.length ? owners.map(function (o) {
            return o.pid;
        }).join(",") : place.unit);
        var host = hostOf(local);
        if (found[key]) {
            if (found[key].addresses.indexOf(host) < 0)
                found[key].addresses.push(host);
            continue;
        }
        found[key] = {
            key: key,
            protocol: protocol,
            port: port,
            addresses: [host],
            owners: owners,
            uid: uidMatch ? parseInt(uidMatch[1], 10) : 0,
            unit: place.unit,
            systemUnit: place.system && /\.service$/.test(place.unit) ? place.unit : ""
        };
        order.push(key);
    }
    return order.map(function (k) {
        return found[k];
    }).sort(function (a, b) {
        return a.port - b.port || (a.protocol < b.protocol ? -1 : a.protocol > b.protocol ? 1 : 0);
    });
}

function ownerName(listener) {
    if (listener.owners.length)
        return listener.owners[0].name;
    if (listener.unit)
        return listener.unit.replace(/\.(?:service|scope)$/, "");
    return "";
}

function matching(listeners, asked, place) {
    var out = [];
    for (var i = 0; i < listeners.length; i++) {
        var l = listeners[i];
        if (l.protocol === "udp" && !asked.udp || l.protocol === "tcp" && !asked.tcp)
            continue;
        var portText = String(l.port);
        var rank = 1;
        if (asked.port) {
            if (portText === asked.port)
                rank = 3;
            else if (!asked.exact && portText.indexOf(asked.port) === 0)
                rank = 2;
            else
                continue;
        }
        if (asked.words) {
            var names = l.owners.map(function (o) {
                return o.name;
            }).concat([l.unit]);
            var best = -1;
            for (var j = 0; j < names.length; j++)
                best = Math.max(best, place(names[j], asked.words));
            if (best <= 0)
                continue;
            rank += best;
        }
        out.push({
            listener: l,
            rank: rank,
            at: i
        });
    }
    out.sort(function (a, b) {
        return b.rank - a.rank || a.at - b.at;
    });
    return out.map(function (o) {
        return o.listener;
    });
}

function addressText(addresses) {
    return addresses.join(", ");
}

var NOT_WEB = [21, 22, 23, 25, 53, 110, 111, 139, 143, 389, 445, 465, 514, 587, 636, 853, 993, 995, 1433, 1521, 2049, 3306, 3389, 5353, 5355, 5432, 5672, 6379, 9092, 11211, 27017];

function readUsers(text) {
    var out = {};
    var all = String(text || "").split("\n");
    for (var i = 0; i < all.length; i++) {
        var fields = all[i].split(":");
        var uid = parseInt(fields[2], 10);
        if (fields[0] && !isNaN(uid) && out[uid] === undefined)
            out[uid] = fields[0];
    }
    return out;
}

function userText(uid, mine, users) {
    if (uid === mine)
        return "";
    if (users && users[uid])
        return users[uid];
    return uid === 0 ? "root" : "uid " + uid;
}

function detailOf(listener, mine, users) {
    var pids = listener.owners.map(function (o) {
        return o.pid;
    });
    return [addressText(listener.addresses), listener.protocol.toUpperCase(), pids.length ? (pids.length > 1 ? "PIDs " : "PID ") + pids.join(", ") : userText(listener.uid, mine, users), pids.length && listener.systemUnit ? listener.systemUnit : ""].filter(Boolean).join(" · ");
}

function labelOf(listener) {
    var name = ownerName(listener);
    return "Port " + listener.port + (name ? " · " + name : "");
}

function browsable(listener) {
    if (listener.protocol !== "tcp" || NOT_WEB.indexOf(listener.port) >= 0)
        return "";
    var local = listener.addresses.some(function (a) {
        return a === "0.0.0.0" || a === "*" || a === "[::]" || a === "127.0.0.1" || a === "[::1]" || a.indexOf("127.") === 0;
    });
    return local ? "http://localhost:" + listener.port : "http://" + listener.addresses[0] + ":" + listener.port;
}

function validPort(port) {
    var n = parseInt(port, 10);
    return String(n) === String(port) && n > 0 && n < 65536;
}
