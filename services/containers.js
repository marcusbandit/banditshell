.pragma library

var LIST = /^(?:(podman|docker)\s+)?containers?(?:\s+(.*))?$/i;
var ENGINE = /^(podman|docker)(?:\s+(?:ps|container\s+ls)(?:\s+-a)?(?=\s|$))?(?:\s+(.*))?$/i;
var ID = /^[0-9a-f]{12,64}$/;
var SOCKET = /unix:\/\/(\S+?)(?=[:\s"]|$)/;

var READ = 'run() { if command -v timeout >/dev/null 2>&1; then timeout 10 "$@"; else "$@"; fi; }\n' + 'for engine in podman docker; do\n' + '    if ! command -v "$engine" >/dev/null 2>&1; then printf "\\036%s 127\\n" "$engine"; continue; fi\n' + '    if [ "$engine" = podman ]; then out=$(run podman ps -a --format json 2>&1); else out=$(run docker ps -a --format "{{json .}}" 2>&1); fi\n' + '    printf "\\036%s %s\\n%s\\n" "$engine" "$?" "$out"\n' + 'done\n';

function ask(text) {
    var t = String(text || "").trim();
    var m = LIST.exec(t);
    if (m)
        return {
            engine: String(m[1] || "").toLowerCase(),
            words: String(m[2] || "").trim()
        };
    m = ENGINE.exec(t);
    if (m)
        return {
            engine: m[1].toLowerCase(),
            words: String(m[2] || "").trim()
        };
    return null;
}

function readCommand() {
    return ["sh", "-c", READ];
}

function portsOfPodman(ports) {
    return (ports || []).map(function (p) {
        var range = p.range > 1 ? "-" + (p.host_port + p.range - 1) : "";
        return (p.host_ip && p.host_ip !== "0.0.0.0" ? p.host_ip + ":" : "") + p.host_port + range + "→" + p.container_port + (p.protocol && p.protocol !== "tcp" ? "/" + p.protocol : "");
    });
}

function portsOfDocker(text) {
    var seen = [];
    String(text || "").split(/,\s*/).forEach(function (part) {
        var m = /^(?:(.*):)?(\d+(?:-\d+)?)->(\d+(?:-\d+)?)\/(\w+)$/.exec(part.trim());
        if (!m)
            return;
        var host = m[1] && m[1] !== "0.0.0.0" && m[1] !== "::" && m[1] !== "[::]" ? m[1] + ":" : "";
        var shown = host + m[2] + "→" + m[3] + (m[4] !== "tcp" ? "/" + m[4] : "");
        if (seen.indexOf(shown) < 0)
            seen.push(shown);
    });
    return seen;
}

function stateWord(state) {
    var s = String(state || "").toLowerCase();
    return s === "up" ? "running" : s;
}

function readPodman(text) {
    var got;
    try {
        got = JSON.parse(String(text || "").trim() || "[]");
    } catch (e) {
        return null;
    }
    if (!Array.isArray(got))
        return null;
    return got.filter(function (c) {
        return c && !c.IsInfra && ID.test(String(c.Id || ""));
    }).map(function (c) {
        return {
            engine: "podman",
            id: String(c.Id),
            name: (c.Names || [])[0] || String(c.Id).slice(0, 12),
            image: String(c.Image || ""),
            state: stateWord(c.State),
            status: String(c.Status || ""),
            ports: portsOfPodman(c.Ports),
            pod: String(c.PodName || "")
        };
    });
}

function readDocker(text) {
    var out = [];
    var all = String(text || "").split("\n");
    for (var i = 0; i < all.length; i++) {
        var line = all[i].trim();
        if (!line)
            continue;
        var c;
        try {
            c = JSON.parse(line);
        } catch (e) {
            return null;
        }
        var id = String(c.ID || "");
        if (!/^[0-9a-f]{12,64}$/.test(id))
            continue;
        out.push({
            engine: "docker",
            id: id,
            name: String(c.Names || "").split(",")[0] || id.slice(0, 12),
            image: String(c.Image || ""),
            state: stateWord(c.State || (/^up\b/i.test(c.Status || "") ? "running" : "exited")),
            status: String(c.Status || ""),
            ports: portsOfDocker(c.Ports),
            pod: ""
        });
    }
    return out;
}

function problemOf(engine, code, text) {
    if (code === 127)
        return {
            kind: "missing"
        };
    var said = String(text || "");
    if (/permission denied/i.test(said)) {
        var socket = SOCKET.exec(said);
        return {
            kind: "denied",
            socket: socket ? socket[1] : ""
        };
    }
    if (/cannot connect to the docker daemon|is the docker daemon running|connection refused|no such file or directory/i.test(said))
        return {
            kind: "stopped"
        };
    if (code === 124)
        return {
            kind: "slow"
        };
    var first = said.split("\n").filter(Boolean)[0] || "";
    return {
        kind: "failed",
        said: first.length > 120 ? first.slice(0, 119) + "…" : first
    };
}

function readAll(text) {
    var out = {
        containers: [],
        problems: {}
    };
    var parts = String(text || "").split("\u001e");
    for (var i = 0; i < parts.length; i++) {
        var cut = parts[i].indexOf("\n");
        var head = (cut < 0 ? parts[i] : parts[i].slice(0, cut)).trim().split(" ");
        var body = cut < 0 ? "" : parts[i].slice(cut + 1);
        var engine = head[0];
        if (engine !== "podman" && engine !== "docker")
            continue;
        var code = parseInt(head[1], 10);
        var read = code === 0 ? (engine === "podman" ? readPodman(body) : readDocker(body)) : null;
        if (read === null)
            out.problems[engine] = problemOf(engine, code === 0 ? 1 : code, body);
        else
            out.containers = out.containers.concat(read);
    }
    return out;
}

function running(container) {
    return container.state === "running" || container.state === "restarting";
}

function detailOf(container, both) {
    return [both ? container.engine : "", container.image.replace(/^(?:docker\.io|ghcr\.io|quay\.io)\//, "").replace(/^library\//, ""), container.status, container.ports.join(", "), container.pod ? "pod " + container.pod : ""].filter(Boolean).join(" · ");
}

function matching(containers, asked, place) {
    var want = String(asked.words || "");
    var out = [];
    for (var i = 0; i < containers.length; i++) {
        var c = containers[i];
        if (asked.engine && c.engine !== asked.engine)
            continue;
        var rank = 0;
        if (want) {
            rank = Math.max(place(c.name, want), place(c.image, want) - 1, place(c.pod, want) - 1);
            if (rank <= 0)
                continue;
        }
        out.push({
            container: c,
            rank: rank,
            at: i
        });
    }
    out.sort(function (a, b) {
        return b.rank - a.rank || (running(b.container) ? 1 : 0) - (running(a.container) ? 1 : 0) || a.at - b.at;
    });
    return out.map(function (o) {
        return o.container;
    });
}

function validId(id) {
    return ID.test(String(id || ""));
}

function controlCommand(container, verb) {
    if (!validId(container.id) || ["start", "stop", "restart", "unpause"].indexOf(verb) < 0 || ["podman", "docker"].indexOf(container.engine) < 0)
        return null;
    return [container.engine, verb, container.id];
}

function quote(text) {
    return "'" + String(text).replace(/'/g, "'\\''") + "'";
}

function logsLine(container) {
    if (!validId(container.id))
        return "";
    return [container.engine, "logs", "-f", "--tail", "200", container.id].map(quote).join(" ") + '; status=$?; echo; if [ "$status" -ne 0 ] && [ "$status" -ne 130 ]; then echo "Logs stopped with status $status. Press Enter to close."; else echo "The logs ended. Press Enter to close."; fi; read -r _';
}

function shellLine(container) {
    if (!validId(container.id))
        return "";
    return [container.engine, "exec", "-it", container.id, "sh", "-c", "if command -v bash >/dev/null 2>&1; then exec bash; fi; exec sh"].map(quote).join(" ") + '; status=$?; if [ "$status" -ne 0 ] && [ "$status" -ne 130 ]; then echo; echo "The shell stopped with status $status. Press Enter to close."; read -r _; fi';
}
