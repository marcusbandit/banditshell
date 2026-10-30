.pragma library

var BUNDLES = /\.(p12|pfx)$/i;
var KEYS = /\.key$/i;
var MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
var SHARED = ["ac", "co", "com", "edu", "gov", "net", "org"];

function holdsKey(path, lines) {
    return BUNDLES.test(path) || lines.some(function (line) {
        return line.trim() === "private key";
    });
}

function kindOf(path, lines) {
    var key = false;
    var subject = null;
    var issuer = null;
    var authority = markedOf(lines);
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (line === "private key")
            key = true;
        else if (line.indexOf("subject=") === 0)
            subject = line.slice(8).trim();
        else if (line.indexOf("issuer=") === 0)
            issuer = line.slice(7).trim();
    }
    if (BUNDLES.test(path))
        return "client";
    if (subject === null)
        return key || KEYS.test(path) ? "key" : "";
    if (key)
        return "client";
    if (authority === null)
        authority = subject === issuer;
    return authority ? "authority" : "client";
}

function field(lines, name) {
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (line.indexOf(name + "=") === 0)
            return line.slice(name.length + 1).trim();
    }
    return "";
}

function endOf(text) {
    var m = /^([A-Z][a-z]{2})\s+(\d{1,2})\s+(\d{2}):(\d{2}):(\d{2})\s+(\d{4})\s+GMT$/.exec(String(text || "").trim());
    if (!m || MONTHS.indexOf(m[1]) < 0)
        return 0;
    return Date.UTC(Number(m[6]), MONTHS.indexOf(m[1]), Number(m[2]), Number(m[3]), Number(m[4]), Number(m[5]));
}

function partsOf(dn) {
    var text = String(dn || "");
    var keys = [];
    var key = /(?:^|,\s*)([A-Za-z][A-Za-z0-9.]*)\s*=\s*/g;
    var m;
    while ((m = key.exec(text)) !== null)
        keys.push({ name: m[1], at: m.index, from: m.index + m[0].length });
    var found = {};
    for (var i = 0; i < keys.length; i++) {
        var value = text.slice(keys[i].from, i + 1 < keys.length ? keys[i + 1].at : text.length).trim();
        found[keys[i].name] = value.replace(/^"(.*)"$/, "$1");
    }
    return found;
}

function nameOf(dn) {
    var found = partsOf(dn);
    return found.O || found.CN || "";
}

function holderOf(dn) {
    var found = partsOf(dn);
    return found.CN || found.O || "";
}

function after(lines, lead) {
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (line.slice(0, lead.length).toLowerCase() === lead.toLowerCase())
            return line.slice(lead.length).trim();
    }
    return "";
}

function markedOf(lines) {
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (/^CA:TRUE\b/.test(line))
            return true;
        if (/^CA:FALSE\b/.test(line))
            return false;
    }
    return null;
}

function read(text) {
    var out = [];
    var seen = {};
    var records = String(text || "").split("\x1e");
    for (var i = 0; i < records.length; i++) {
        var lines = records[i].split("\n");
        var path = lines[0];
        if (path.charAt(0) !== "/" || seen[path])
            continue;
        seen[path] = true;
        var rest = lines.slice(1);
        var kind = kindOf(path, rest);
        if (kind)
            out.push({
                path: path,
                kind: kind,
                key: holdsKey(path, lines),
                locked: rest.some(function (line) {
                    return line.trim() === "locked";
                }),
                subject: field(rest, "subject"),
                issuer: field(rest, "issuer"),
                until: endOf(field(rest, "notAfter")),
                marked: markedOf(rest),
                fingerprint: after(rest, "sha256 Fingerprint="),
                ownKey: after(rest, "key "),
                publicKey: after(rest, "public ")
            });
    }
    return out;
}

function schoolLabel(server) {
    var parts = String(server || "").trim().toLowerCase().split(".").filter(function (p) {
        return p;
    });
    if (parts.length < 2)
        return "";
    var label = parts[parts.length - 2];
    if (SHARED.indexOf(label) >= 0 && parts.length >= 3)
        label = parts[parts.length - 3];
    return label.length >= 3 ? label : "";
}

function fits(file, server) {
    var label = schoolLabel(server);
    if (!label)
        return false;
    var words = (file.subject + " " + file.issuer).toLowerCase().split(/[^a-z0-9]+/);
    return label.split(/[^a-z0-9]+/).every(function (part) {
        return !part || words.indexOf(part) >= 0;
    });
}

function monthOf(ms) {
    var d = new Date(ms);
    return MONTHS[d.getUTCMonth()] + " " + d.getUTCFullYear();
}

function baseName(path) {
    return path.slice(path.lastIndexOf("/") + 1);
}

function untilOf(file, now) {
    if (!(file.until > 0))
        return "";
    return (file.until <= now ? "expired " : "until ") + monthOf(file.until);
}

function joined(parts) {
    return parts.filter(function (p) {
        return p;
    }).join(" · ");
}

function find(files, test) {
    for (var i = 0; i < files.length; i++) {
        if (test(files[i]))
            return files[i];
    }
    return null;
}

function roots(files, server, now, most) {
    var host = String(server || "").trim().toLowerCase();
    var out = [];
    for (var i = 0; i < files.length; i++) {
        var f = files[i];
        if (f.kind !== "authority")
            continue;
        var expired = f.until > 0 && f.until <= now;
        var unmarked = f.marked !== true;
        var match = fits(f, host);
        out.push({
            file: f,
            match: match,
            parts: [nameOf(f.issuer) || nameOf(f.subject), untilOf(f, now), match ? "named like " + host : "", unmarked ? "not marked as a root" : ""],
            warn: expired || unmarked,
            rank: (match ? 0 : 1) + (expired || unmarked ? 2 : 0),
            order: out.length
        });
    }
    out.sort(function (a, b) {
        return a.rank - b.rank || a.order - b.order;
    });
    var shown = out.slice(0, most);
    return shown.map(function (r) {
        var twin = r.file.fingerprint ? find(shown, function (o) {
            return o !== r && o.file.fingerprint === r.file.fingerprint;
        }) : null;
        return { path: r.file.path, detail: joined(r.parts.concat([twin ? "same as " + baseName(twin.file.path) : ""])), warn: r.warn, match: r.match };
    });
}

function unrelated(files, server) {
    var label = schoolLabel(server);
    var listed = files.filter(function (f) {
        return f.kind === "authority";
    });
    return !!label && listed.length > 0 && !listed.some(function (f) {
        return fits(f, String(server || "").trim().toLowerCase());
    });
}

function keyFileOf(files, f) {
    return f.key || !f.publicKey ? null : find(files, function (g) {
        return g.kind === "key" && g.ownKey === f.publicKey;
    });
}

function easeOf(files, f) {
    var keyFile = keyFileOf(files, f);
    if (f.key)
        return f.locked ? 2 : 0;
    return keyFile ? (keyFile.locked ? 2 : 1) : 3;
}

function packaging(files, f) {
    var keyFile = keyFileOf(files, f);
    return joined([f.key ? "holds its key" : keyFile ? "key in " + baseName(keyFile.path) : "needs its key file", f.locked ? "locked with a password" : ""]);
}

function groups(files) {
    var out = [];
    var at = {};
    for (var i = 0; i < files.length; i++) {
        var f = files[i];
        if (f.kind !== "client")
            continue;
        var id = f.fingerprint ? "#" + f.fingerprint.toUpperCase() : "/" + f.path;
        if (!(id in at)) {
            at[id] = out.length;
            out.push([]);
        }
        out[at[id]].push(f);
    }
    return out.map(function (members) {
        var lead = members[0];
        for (var j = 1; j < members.length; j++) {
            if (easeOf(files, members[j]) < easeOf(files, lead))
                lead = members[j];
        }
        return { lead: lead, members: members };
    });
}

function clients(files, now, most) {
    return groups(files).slice(0, most).map(function (g) {
        var f = g.lead;
        return {
            path: f.path,
            detail: joined([holderOf(f.subject), untilOf(f, now), packaging(files, f), g.members.length > 1 ? "in " + g.members.length + " files" : ""]),
            warn: f.until > 0 && f.until <= now,
            others: g.members.filter(function (m) {
                return m !== f;
            }).map(function (m) {
                return { path: m.path, detail: packaging(files, m), warn: false };
            })
        };
    });
}

function easiest(files, now) {
    var ready = groups(files).filter(function (g) {
        return easeOf(files, g.lead) <= 1 && !(g.lead.until > 0 && g.lead.until <= now);
    });
    return ready.length === 1 ? ready[0].lead.path : "";
}

function holderAt(files, path) {
    var file = fileAt(files, path);
    return file && file.kind === "client" ? holderOf(file.subject) : "";
}

function fingerprintAt(files, path) {
    var file = fileAt(files, path);
    return file && file.kind === "authority" ? file.fingerprint : "";
}

function printLines(fingerprint) {
    var pairs = String(fingerprint || "").split(":");
    var lines = [];
    for (var i = 0; i < pairs.length; i += 8)
        lines.push(pairs.slice(i, i + 8).join(":"));
    return lines.join("\n");
}

function compare(fingerprint, pasted) {
    var want = String(pasted || "").replace(/sha-?\s*(1|256)|fingerprint/gi, "").replace(/[^0-9a-f]/gi, "").toUpperCase();
    var have = String(fingerprint || "").replace(/[^0-9a-f]/gi, "").toUpperCase();
    if (!want || !have)
        return "";
    if (want === have)
        return "match";
    if (want.length === 40)
        return "sha1";
    if (want.length !== 64)
        return "short";
    return "differs";
}

function keys(files, most) {
    var out = [];
    for (var i = 0; i < files.length && out.length < most; i++) {
        var f = files[i];
        if (f.kind !== "key")
            continue;
        var owner = !f.ownKey ? null : find(files, function (g) {
            return g.kind === "client" && !g.key && g.publicKey === f.ownKey;
        }) || find(files, function (g) {
            return g.kind === "client" && g.publicKey === f.ownKey;
        });
        out.push({
            path: f.path,
            detail: f.locked ? "locked with a password" : owner ? "key for " + baseName(owner.path) : "no certificate here fits it",
            warn: false
        });
    }
    return out;
}

function keyFor(files, path) {
    var cert = fileAt(files, path);
    if (!cert || cert.kind !== "client" || cert.key || !cert.publicKey)
        return "";
    var file = find(files, function (f) {
        return f.kind === "key" && f.ownKey === cert.publicKey;
    });
    return file ? file.path : "";
}

function locked(files, path) {
    var file = fileAt(files, path);
    return !!file && file.locked;
}

function fileAt(files, path) {
    return find(files, function (f) {
        return f.path === path;
    });
}

function carriesKey(files, path) {
    var file = fileAt(files, path);
    return file ? file.key : BUNDLES.test(path);
}

function needsKey(files, path) {
    var file = fileAt(files, path);
    return !!file && file.kind === "client" && !file.key;
}

function shortPath(path, home) {
    var full = String(path || "");
    var base = String(home || "").replace(/\/+$/, "");
    return base && full.indexOf(base + "/") === 0 ? "~" + full.slice(base.length) : full;
}

function fullPath(text, home) {
    var typed = String(text || "").trim();
    var base = String(home || "").replace(/\/+$/, "");
    return base && typed.indexOf("~/") === 0 ? base + typed.slice(1) : typed;
}

function problem(files, path, want, now) {
    var file = fileAt(files, path);
    if (!file)
        return "";
    var name = baseName(path);
    var expired = file.until > 0 && file.until <= now ? name + " expired in " + monthOf(file.until) + "." : "";
    if (want === "authority")
        return file.kind !== "authority" ? name + " is not a root certificate." : expired;
    if (want === "client") {
        if (file.kind === "authority")
            return name + " is a root certificate, not one issued to you.";
        if (file.kind === "key")
            return name + " is a key, not a certificate.";
        return expired;
    }
    if (want === "key")
        return file.kind !== "key" && !file.key ? name + " holds no key." : "";
    return "";
}
