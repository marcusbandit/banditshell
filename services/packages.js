.pragma library

var ASK = /^(?:install|pkg|package|packages)\s+(\S.*)$/i;
var SECTION = /^@@ (\S+)\s*$/;
var PACMAN_LINE = /^([^\s\/]+)\/(\S+) (\S+)(?: \(([^)]*)\))?(?: \[installed(?:: ([^\]]+))?\])?/;
var APT_LINE = /^(\S+) - (.*)$/;
var POLICY_NAME = /^(\S+):$/;
var POLICY_FIELD = /^\s+(Installed|Candidate): (.*)$/;
var DNF_LINE = /^\s*([^\s:]+)\.(x86_64|noarch|i686|aarch64|armv7hl|ppc64le|s390x|src)\s*(?::|\t)\s*(.*)$/;
var XBPS_LINE = /^\[(.)\]\s+(\S+)-([^-\s]+_\d+)\s+(.*)$/;
var APK_LINE = /^(\S+?)-(\d[^-\s]*-r\d+)(?:\s+-\s+(.*))?$/;
var MOST = 600;
var WORDY = /[a-z0-9]/;

var SOURCES = {
    pacman: "pacman",
    apt: "apt",
    dnf: "dnf",
    zypper: "zypper",
    xbps: "xbps",
    apk: "apk",
    aur: "AUR",
    flatpak: "Flatpak"
};

function ask(input) {
    var hit = ASK.exec(String(input || "").trim());
    return hit ? hit[1].trim() : "";
}

function sections(raw) {
    var out = {};
    var at = "";
    String(raw || "").split("\n").forEach(function (line) {
        var head = SECTION.exec(line);
        if (head) {
            at = head[1];
            out[at] = out[at] || [];
            return;
        }
        if (at)
            out[at].push(line);
    });
    return out;
}

function record(fields) {
    return {
        source: fields.source,
        name: fields.name,
        title: fields.title || fields.name,
        version: fields.version || "",
        description: fields.description || "",
        installed: !!fields.installed,
        installedVersion: fields.installedVersion || "",
        repo: fields.repo || "",
        popularity: fields.popularity || 0,
        installation: fields.installation || "",
        icon: fields.icon || ""
    };
}

function readPacman(lines) {
    var out = [];
    for (var i = 0; i < lines.length && out.length < MOST; i++) {
        var hit = PACMAN_LINE.exec(lines[i]);
        if (!hit)
            continue;
        var next = lines[i + 1] || "";
        var described = /^\s/.test(next);
        out.push(record({
            source: "pacman",
            repo: hit[1],
            name: hit[2],
            version: hit[3],
            installed: lines[i].indexOf(" [installed") >= 0,
            installedVersion: hit[5] || (lines[i].indexOf(" [installed") >= 0 ? hit[3] : ""),
            description: described ? next.trim() : ""
        }));
        if (described)
            i++;
    }
    return out;
}

function readApt(lines, policyLines) {
    var policy = {};
    var at = "";
    (policyLines || []).forEach(function (line) {
        var name = POLICY_NAME.exec(line);
        if (name) {
            at = name[1];
            policy[at] = {};
            return;
        }
        var field = POLICY_FIELD.exec(line);
        if (field && at)
            policy[at][field[1]] = field[2].trim();
    });
    var out = [];
    lines.forEach(function (line) {
        var hit = APT_LINE.exec(line);
        if (!hit || out.length >= MOST)
            return;
        var known = policy[hit[1]] || {};
        var have = known.Installed && known.Installed !== "(none)" ? known.Installed : "";
        out.push(record({
            source: "apt",
            name: hit[1],
            version: known.Candidate && known.Candidate !== "(none)" ? known.Candidate : have,
            installed: !!have,
            installedVersion: have,
            description: hit[2]
        }));
    });
    return out;
}

function installedTable(lines) {
    var have = {};
    (lines || []).forEach(function (line) {
        var parts = line.trim().split(/\s+/);
        if (parts[0])
            have[parts[0]] = parts[1] || "";
    });
    return have;
}

function readDnf(lines, rpmLines) {
    var have = installedTable(rpmLines);
    var seen = {};
    var out = [];
    lines.forEach(function (line) {
        var hit = DNF_LINE.exec(line);
        if (!hit || seen[hit[1]] || out.length >= MOST)
            return;
        seen[hit[1]] = true;
        out.push(record({
            source: "dnf",
            name: hit[1],
            version: have[hit[1]] || "",
            installed: have[hit[1]] !== undefined,
            installedVersion: have[hit[1]] || "",
            description: hit[3].trim()
        }));
    });
    return out;
}

function readZypper(lines) {
    var columns = null;
    var out = [];
    lines.forEach(function (line) {
        if (line.indexOf("|") < 0 || /^[-+\s]+$/.test(line))
            return;
        var cells = line.split("|").map(function (c) {
            return c.trim();
        });
        if (!columns) {
            columns = {};
            cells.forEach(function (c, i) {
                columns[c.toLowerCase()] = i;
            });
            return;
        }
        var type = columns.type !== undefined ? cells[columns.type] : "package";
        if (type !== "package" || out.length >= MOST)
            return;
        var state = cells[columns.s] || "";
        out.push(record({
            source: "zypper",
            name: cells[columns.name],
            version: columns.version !== undefined ? cells[columns.version] : "",
            installed: state.charAt(0) === "i",
            description: columns.summary !== undefined ? cells[columns.summary] : ""
        }));
    });
    return out;
}

function readXbps(lines) {
    var out = [];
    lines.forEach(function (line) {
        var hit = XBPS_LINE.exec(line);
        if (!hit || out.length >= MOST)
            return;
        out.push(record({
            source: "xbps",
            name: hit[2],
            version: hit[3],
            installed: hit[1] === "*",
            installedVersion: hit[1] === "*" ? hit[3] : "",
            description: hit[4].trim()
        }));
    });
    return out;
}

function readApk(lines, installedLines) {
    var have = {};
    (installedLines || []).forEach(function (line) {
        if (line.trim())
            have[line.trim()] = true;
    });
    var out = [];
    lines.forEach(function (line) {
        var hit = APK_LINE.exec(line.trim());
        if (!hit || out.length >= MOST)
            return;
        out.push(record({
            source: "apk",
            name: hit[1],
            version: hit[2],
            installed: !!have[hit[1]],
            description: (hit[3] || "").trim()
        }));
    });
    return out;
}

function readSystem(raw) {
    var parts = sections(raw);
    if (parts.pacman)
        return readPacman(parts.pacman);
    if (parts.apt)
        return readApt(parts.apt, parts["apt-policy"]);
    if (parts.dnf)
        return readDnf(parts.dnf, parts.rpm);
    if (parts.zypper)
        return readZypper(parts.zypper);
    if (parts.xbps)
        return readXbps(parts.xbps);
    if (parts.apk)
        return readApk(parts.apk, parts["apk-installed"]);
    return null;
}

function readAur(raw) {
    var parts = sections(raw);
    var have = installedTable(parts.foreign);
    var data;
    try {
        data = JSON.parse((parts.aur || []).join("\n"));
    } catch (e) {
        return null;
    }
    if (!data || data.type === "error" || !Array.isArray(data.results))
        return data && data.type === "error" ? [] : null;
    return data.results.map(function (r) {
        return record({
            source: "aur",
            name: r.Name,
            version: r.Version,
            description: r.Description || "",
            installed: have[r.Name] !== undefined,
            installedVersion: have[r.Name] || "",
            popularity: r.Popularity || 0
        });
    });
}

function readFlatpakIndex(raw) {
    var data;
    try {
        data = JSON.parse(String(raw || ""));
    } catch (e) {
        return [];
    }
    return (Array.isArray(data.apps) ? data.apps : []).map(function (a) {
        var entry = record({
            source: "flatpak",
            name: a.id,
            title: a.name || a.id,
            version: a.version || "",
            description: a.summary || "",
            repo: a.remote || "",
            installation: a.installation || "system",
            icon: a.icon || ""
        });
        entry.hay = (entry.title + " " + entry.name).toLowerCase();
        return entry;
    });
}

function readFlatpakInstalled(raw) {
    var have = {};
    String(raw || "").split("\n").forEach(function (line) {
        var parts = line.split("\t");
        if (parts[0])
            have[(parts[2] || "system") + "/" + parts[0]] = parts[1] || "";
    });
    return have;
}

function placeIn(hay, want) {
    if (!hay || !want)
        return -1;
    if (hay === want)
        return 4;
    var at = hay.indexOf(want);
    if (at === 0)
        return 3;
    while (at > 0) {
        if (!WORDY.test(hay.charAt(at - 1)))
            return 2;
        at = hay.indexOf(want, at + 1);
    }
    return hay.indexOf(want) > 0 ? 1 : -1;
}

function searchFlatpaks(index, term, installed) {
    var want = String(term || "").toLowerCase();
    if (!want)
        return [];
    var have = installed || {};
    var out = [];
    for (var i = 0; i < index.length; i++) {
        var app = index[i];
        if (app.hay.indexOf(want) < 0)
            continue;
        var where = have["system/" + app.name] !== undefined ? "system" : have["user/" + app.name] !== undefined ? "user" : "";
        out.push(Object.assign({}, app, {
            installed: !!where,
            installedVersion: where ? have[where + "/" + app.name] : "",
            installation: where || app.installation
        }));
    }
    return out;
}

var WEIGHT = {
    pacman: 0.3,
    apt: 0.3,
    dnf: 0.3,
    zypper: 0.3,
    xbps: 0.3,
    apk: 0.3,
    flatpak: 0.2,
    aur: 0
};

function scoreOf(entry, want) {
    var named = Math.max(placeIn(entry.name.toLowerCase(), want), placeIn(entry.title.toLowerCase(), want));
    var base = named > 0 ? named : entry.description.toLowerCase().indexOf(want) >= 0 ? 0.5 : 0.25;
    return base + (WEIGHT[entry.source] || 0) + Math.min(0.19, Math.log(1 + (entry.popularity || 0)) / 25);
}

function rank(lists, term) {
    var want = String(term || "").trim().toLowerCase();
    var all = [];
    lists.forEach(function (list) {
        (list || []).forEach(function (entry) {
            all.push(Object.assign({}, entry, {
                rank: scoreOf(entry, want)
            }));
        });
    });
    return all.sort(function (a, b) {
        return b.rank - a.rank || a.name.length - b.name.length || (a.name < b.name ? -1 : 1);
    });
}

function installToken(entry) {
    if (entry.source === "flatpak")
        return "flatpak:" + (entry.installation || "system") + "/" + entry.repo + "/" + entry.name;
    return entry.source + ":" + entry.name;
}

function removalOf(entry) {
    if (entry.source === "flatpak")
        return {
            how: entry.installation === "user" ? "flatpak-user" : "flatpak-system",
            package: entry.name
        };
    return {
        how: entry.source === "aur" ? "pacman" : entry.source,
        package: entry.name
    };
}

function pageUrl(entry) {
    var name = encodeURIComponent(entry.name);
    switch (entry.source) {
    case "pacman":
        return "https://archlinux.org/packages/?name=" + name;
    case "aur":
        return "https://aur.archlinux.org/packages/" + name;
    case "flatpak":
        return entry.repo === "flathub" ? "https://flathub.org/apps/" + name : "";
    }
    return "https://repology.org/project/" + name + "/versions";
}

function sourceName(source) {
    return SOURCES[source] || source;
}

function detailOf(entry) {
    var version = entry.installed && entry.installedVersion && entry.installedVersion !== entry.version ? entry.installedVersion + " to " + entry.version : entry.version;
    var head = [sourceName(entry.source), version].filter(Boolean).join(" ");
    return [head, entry.installed ? "installed" : "", entry.description].filter(Boolean).join(" · ");
}
