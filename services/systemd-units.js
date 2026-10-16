.pragma library

var LIST = /^(?:(user|system)\s+)?services?(?:\s+(.*))?$/i;
var FAILED = /^failed\s+services?$/i;
var CONTROL = /^systemctl(?:\s+(--user|--system))?(?:\s+(start|stop|restart|status))?(?:\s+(.*))?$/i;
var VERB = /^(start|stop|restart)\s+(?:the\s+)?(?:(user|system)\s+)?(?:service\s+)?([A-Za-z0-9@_.:\\-]+?)(?:\.service)?(?:\s+service)?$/i;
var UNIT = /^[A-Za-z0-9:_.\\@-]+\.service$/;
var TEMPLATE = /@\.service$/;

var READ = 'command -v systemctl >/dev/null 2>&1 || exit 3\n' + 'for scope in system user; do\n' + '    if [ "$scope" = user ]; then set -- --user; else set --; fi\n' + '    printf "\\036%s units\\n" "$scope"\n' + '    systemctl "$@" list-units --type=service --all --output=json --no-pager 2>/dev/null\n' + '    printf "\\n\\036%s files\\n" "$scope"\n' + '    systemctl "$@" list-unit-files --type=service --output=json --no-pager 2>/dev/null\n' + '    printf "\\n"\n' + 'done\n';

function scopeOf(word) {
    var w = String(word || "").toLowerCase().replace(/^--/, "");
    return w === "user" || w === "system" ? w : "";
}

function ask(text) {
    var t = String(text || "").trim();
    var m = VERB.exec(t);
    if (m)
        return {
            verb: m[1].toLowerCase(),
            scope: scopeOf(m[2]),
            words: m[3],
            failed: false
        };
    if (FAILED.test(t))
        return {
            verb: "",
            scope: "",
            words: "",
            failed: true
        };
    m = CONTROL.exec(t);
    if (m) {
        var verb = String(m[2] || "").toLowerCase();
        return {
            verb: verb === "status" ? "" : verb,
            scope: scopeOf(m[1]),
            words: String(m[3] || "").trim().replace(/\.service$/, ""),
            failed: false
        };
    }
    m = LIST.exec(t);
    if (m) {
        var words = String(m[2] || "").trim();
        var failed = /^failed$/i.test(words);
        return {
            verb: "",
            scope: scopeOf(m[1]),
            words: failed ? "" : words.replace(/\.service$/, ""),
            failed: failed
        };
    }
    return null;
}

function readCommand() {
    return ["sh", "-c", READ];
}

function parseJson(text) {
    var t = String(text || "").trim();
    if (!t)
        return [];
    try {
        var got = JSON.parse(t);
        return Array.isArray(got) ? got : [];
    } catch (e) {
        return [];
    }
}

function sections(text) {
    var out = {};
    var parts = String(text || "").split("\u001e");
    for (var i = 0; i < parts.length; i++) {
        var cut = parts[i].indexOf("\n");
        if (cut < 0)
            continue;
        out[parts[i].slice(0, cut).trim()] = parts[i].slice(cut + 1);
    }
    return out;
}

function unitsOf(listed, files, scope) {
    var out = [];
    var seen = {};
    var enabled = {};
    for (var i = 0; i < files.length; i++) {
        var f = files[i] || {};
        if (f.unit_file)
            enabled[f.unit_file] = f.state || "";
    }
    for (var j = 0; j < listed.length; j++) {
        var u = listed[j] || {};
        var name = String(u.unit || "");
        if (!UNIT.test(name) || seen[name] || u.load === "not-found" && u.active !== "active")
            continue;
        seen[name] = true;
        out.push({
            name: name,
            base: name.replace(/\.service$/, ""),
            scope: scope,
            load: u.load || "",
            active: u.active || "",
            sub: u.sub || "",
            description: u.description || "",
            enabled: enabled[name] || (u.load === "masked" ? "masked" : "")
        });
    }
    for (var k = 0; k < files.length; k++) {
        var file = files[k] || {};
        var unit = String(file.unit_file || "");
        if (!UNIT.test(unit) || TEMPLATE.test(unit) || seen[unit])
            continue;
        seen[unit] = true;
        out.push({
            name: unit,
            base: unit.replace(/\.service$/, ""),
            scope: scope,
            load: file.state === "masked" ? "masked" : "",
            active: "inactive",
            sub: "dead",
            description: "",
            enabled: file.state || ""
        });
    }
    return out;
}

function readUnits(text) {
    var parts = sections(text);
    return unitsOf(parseJson(parts["system units"]), parseJson(parts["system files"]), "system").concat(unitsOf(parseJson(parts["user units"]), parseJson(parts["user files"]), "user"));
}

function stateOf(unit) {
    if (unit.load === "masked" || unit.enabled === "masked")
        return "masked";
    return unit.active === "active" ? unit.sub || "active" : unit.active || "inactive";
}

function running(unit) {
    return unit.active === "active" || unit.active === "activating" || unit.active === "reloading";
}

function startable(unit) {
    return !running(unit) && stateOf(unit) !== "masked";
}

function standing(unit) {
    var state = stateOf(unit);
    return state === "failed" ? 0 : unit.sub === "running" ? 1 : running(unit) ? 2 : 3;
}

function detailOf(unit) {
    var enabled = unit.enabled === "enabled" || unit.enabled === "disabled" ? unit.enabled : "";
    return [unit.scope === "user" ? "user" : "", stateOf(unit), enabled, unit.description].filter(Boolean).join(" · ");
}

function matching(units, asked, place, limit) {
    var out = [];
    var want = String(asked.words || "");
    for (var i = 0; i < units.length; i++) {
        var u = units[i];
        if (asked.scope && u.scope !== asked.scope)
            continue;
        if (asked.failed && stateOf(u) !== "failed")
            continue;
        var rank = 0;
        if (want) {
            var onName = place(u.base, want);
            var onWords = asked.verb ? -1 : place(u.description, want) - 1.5;
            rank = Math.max(onName, onWords);
            if (rank <= 0 || asked.verb && onName < 3)
                continue;
        }
        out.push({
            unit: u,
            rank: rank,
            exact: !!want && u.base.toLowerCase() === want.toLowerCase(),
            at: i
        });
    }
    out.sort(function (a, b) {
        var left = a.unit.base.toLowerCase();
        var right = b.unit.base.toLowerCase();
        return b.rank - a.rank || standing(a.unit) - standing(b.unit) || (left < right ? -1 : left > right ? 1 : a.unit.scope < b.unit.scope ? -1 : 1);
    });
    return out.slice(0, limit);
}

function validUnit(name) {
    return UNIT.test(String(name || "")) && String(name).charAt(0) !== "-" && !TEMPLATE.test(name);
}

function controlCommand(unit, verb) {
    if (!validUnit(unit.name) || ["start", "stop", "restart"].indexOf(verb) < 0)
        return null;
    return unit.scope === "user" ? ["systemctl", "--user", verb, "--", unit.name] : ["pkexec", "systemctl", verb, "--", unit.name];
}

function quote(text) {
    return "'" + String(text).replace(/'/g, "'\\''") + "'";
}

function logsLine(unit) {
    if (!validUnit(unit.name))
        return "";
    return (unit.scope === "user" ? "journalctl --user -u " : "journalctl -u ") + quote(unit.name) + ' -n 200 -f; status=$?; if [ "$status" -ne 0 ] && [ "$status" -ne 130 ]; then echo; echo "journalctl stopped with status $status. Press Enter to close."; read -r _; fi';
}

function verbLabel(verb) {
    return verb === "start" ? "Start" : verb === "stop" ? "Stop" : verb === "restart" ? "Restart" : "";
}

function progressWord(verb) {
    return verb === "start" ? "starting" : verb === "stop" ? "stopping" : verb === "restart" ? "restarting" : "";
}
