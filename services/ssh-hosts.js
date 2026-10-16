.pragma library

var ASK = /^ssh(?:\s+(.*))?$/i;
var KEYWORD = /^\s*([A-Za-z]+)\s*(?:=\s*|\s+)(.*?)\s*$/;
var COMMENT = /(?:^|\s)#.*$/;
var ARGUMENT = /"([^"]*)"|(\S+)/g;
var WILD = /[*?!]/;
var ADDRESS = /^(?:\d{1,3}(?:\.\d{1,3}){3}|[0-9A-Fa-f]*:[0-9A-Fa-f:.%]*)$/;
var BRACKETED = /^\[([^\]]+)\]:(\d{1,5})$/;
var TARGET = /^(?:[A-Za-z0-9_][A-Za-z0-9._+-]*@)?(?:[A-Za-z0-9_][A-Za-z0-9._-]*|[0-9A-Fa-f]*:[0-9A-Fa-f:.]+(?:%[A-Za-z0-9_.-]+)?)$/;
var GLOB_SPECIAL = /[.+^${}()|[\]\\]/g;

var READ = 'cd "$HOME/.ssh" 2>/dev/null || exit 0\n' + 'IFS=\n' + 'for pattern in "$@"; do\n' + '    printf "\\035%s\\n" "$pattern"\n' + '    case $pattern in "~/"*) pattern="$HOME/${pattern#??}" ;; esac\n' + '    for file in $pattern; do\n' + '        [ -f "$file" ] && [ -r "$file" ] || continue\n' + '        case ${file##*/} in id_* | *.pub | *.key | *.pem) continue ;; esac\n' + '        printf "\\036%s\\n" "$file"\n' + '        cat -- "$file"\n' + '        printf "\\n"\n' + '    done\n' + 'done\n';

var KNOWN = 'command -v ssh >/dev/null 2>&1 || exit 3\n' + 'for file in "$HOME/.ssh/known_hosts" "$HOME/.ssh/known_hosts2"; do\n' + '    [ -r "$file" ] && awk \'{ if (substr($1, 1, 1) == "@") print $1, $2, $3; else print $1, $2 }\' "$file"\n' + 'done\n' + 'true\n';

function ask(text) {
    var m = ASK.exec(String(text || "").trim());
    return m ? {
        words: (m[1] || "").trim()
    } : null;
}

function readCommand(patterns) {
    return ["sh", "-c", READ, "sh"].concat(patterns);
}

function knownCommand() {
    return ["sh", "-c", KNOWN];
}

function argumentsOf(rest) {
    var out = [];
    ARGUMENT.lastIndex = 0;
    var m;
    while ((m = ARGUMENT.exec(rest)) !== null)
        out.push(m[1] !== undefined ? m[1] : m[2]);
    return out;
}

function lines(text) {
    var out = [];
    var all = String(text || "").split("\n");
    for (var i = 0; i < all.length; i++) {
        var line = all[i].replace(COMMENT, "");
        var m = KEYWORD.exec(line);
        if (m)
            out.push({
                key: m[1].toLowerCase(),
                values: argumentsOf(m[2])
            });
    }
    return out;
}

function nextMark(text, from) {
    for (var i = from; i < text.length; i++) {
        var code = text.charCodeAt(i);
        if (code === 29 || code === 30)
            return i;
    }
    return text.length;
}

function readFiles(text) {
    var out = {};
    var pattern = null;
    var all = String(text || "");
    var at = nextMark(all, 0);
    while (at < all.length) {
        var mark = all.charCodeAt(at);
        var next = nextMark(all, at + 1);
        var part = all.slice(at + 1, next);
        var cut = part.indexOf("\n");
        var head = cut < 0 ? part : part.slice(0, cut);
        var body = cut < 0 ? "" : part.slice(cut + 1);
        if (mark === 29) {
            pattern = head;
            if (!out[pattern])
                out[pattern] = [];
        } else if (pattern !== null) {
            out[pattern].push({
                path: head,
                text: body
            });
        }
        at = next;
    }
    return out;
}

function includesIn(text) {
    var out = [];
    var all = lines(text);
    for (var i = 0; i < all.length; i++)
        if (all[i].key === "include")
            for (var j = 0; j < all[i].values.length; j++)
                if (out.indexOf(all[i].values[j]) < 0)
                    out.push(all[i].values[j]);
    return out;
}

function missingIncludes(files) {
    var out = [];
    for (var pattern in files)
        for (var i = 0; i < files[pattern].length; i++) {
            var wanted = includesIn(files[pattern][i].text);
            for (var j = 0; j < wanted.length; j++)
                if (files[wanted[j]] === undefined && out.indexOf(wanted[j]) < 0)
                    out.push(wanted[j]);
        }
    return out;
}

function assemble(files, pattern, depth) {
    if ((depth || 0) > 8)
        return [];
    var out = [];
    var found = files[pattern] || [];
    for (var i = 0; i < found.length; i++) {
        var all = lines(found[i].text);
        for (var j = 0; j < all.length; j++) {
            if (all[j].key !== "include") {
                out.push(all[j]);
                continue;
            }
            for (var k = 0; k < all[j].values.length; k++)
                out = out.concat(assemble(files, all[j].values[k], (depth || 0) + 1));
        }
    }
    return out;
}

function globPattern(pattern) {
    return new RegExp("^" + pattern.replace(GLOB_SPECIAL, "\\$&").replace(/\*/g, ".*").replace(/\?/g, ".") + "$", "i");
}

function blocksOf(entries) {
    var out = [];
    var current = {
        patterns: [{
                test: globPattern("*"),
                negated: false
            }],
        names: [],
        all: true,
        options: {}
    };
    out.push(current);
    for (var i = 0; i < entries.length; i++) {
        var entry = entries[i];
        if (entry.key === "host" || entry.key === "match") {
            var patterns = [];
            var names = [];
            if (entry.key === "host")
                for (var j = 0; j < entry.values.length; j++) {
                    var value = entry.values[j];
                    var negated = value.charAt(0) === "!";
                    var bare = negated ? value.slice(1) : value;
                    patterns.push({
                        test: globPattern(bare),
                        negated: negated
                    });
                    if (!WILD.test(value) && names.indexOf(value) < 0)
                        names.push(value);
                }
            else if (entry.values.length === 1 && entry.values[0].toLowerCase() === "all")
                patterns.push({
                    test: globPattern("*"),
                    negated: false
                });
            current = {
                patterns: patterns,
                names: names,
                options: {}
            };
            out.push(current);
            continue;
        }
        if (current.options[entry.key] === undefined && entry.values.length)
            current.options[entry.key] = entry.values.join(" ");
    }
    return out;
}

function blockMatches(block, name) {
    var hit = false;
    for (var i = 0; i < block.patterns.length; i++) {
        var p = block.patterns[i];
        if (!p.test.test(name))
            continue;
        if (p.negated)
            return false;
        hit = true;
    }
    return hit;
}

function optionsFor(blocks, name) {
    var out = {};
    for (var i = 0; i < blocks.length; i++) {
        if (!blockMatches(blocks[i], name))
            continue;
        for (var key in blocks[i].options)
            if (out[key] === undefined)
                out[key] = blocks[i].options[key];
    }
    return out;
}

function isAddress(name) {
    return ADDRESS.test(name);
}

function configHosts(entries) {
    var blocks = blocksOf(entries);
    var out = [];
    var seen = {};
    for (var i = 0; i < blocks.length; i++)
        for (var j = 0; j < blocks[i].names.length; j++) {
            var name = blocks[i].names[j];
            if (seen[name.toLowerCase()])
                continue;
            seen[name.toLowerCase()] = true;
            var options = optionsFor(blocks, name);
            out.push({
                name: name,
                address: String(options.hostname || "").replace(/%h/g, name),
                user: options.user || "",
                port: options.port || "",
                jump: options.proxyjump && options.proxyjump !== "none" ? options.proxyjump : "",
                known: false
            });
        }
    return out;
}

function readKnownHosts(text) {
    var out = [];
    var seen = {};
    var all = String(text || "").split("\n");
    for (var i = 0; i < all.length; i++) {
        var fields = all[i].trim().split(/\s+/);
        if (fields[0] && fields[0].charAt(0) === "@")
            fields = fields.slice(1);
        var first = fields[0] || "";
        if (!first || first.charAt(0) === "#" || first.charAt(0) === "|")
            continue;
        var names = first.split(",");
        for (var j = 0; j < names.length; j++) {
            var raw = names[j];
            if (!raw || WILD.test(raw))
                continue;
            var bracketed = BRACKETED.exec(raw);
            var name = bracketed ? bracketed[1] : raw;
            var port = bracketed && bracketed[2] !== "22" ? bracketed[2] : "";
            var key = (name + ":" + port).toLowerCase();
            if (seen[key])
                continue;
            seen[key] = true;
            out.push({
                name: name,
                address: "",
                user: "",
                port: port,
                jump: "",
                known: true,
                keyType: String(fields[1] || "").replace(/^ssh-/, "").replace(/^ecdsa-sha2-nistp\d+$/, "ecdsa")
            });
        }
    }
    return out;
}

function merged(configured, known) {
    var taken = {};
    for (var i = 0; i < configured.length; i++) {
        taken[configured[i].name.toLowerCase()] = true;
        if (configured[i].address)
            taken[configured[i].address.toLowerCase()] = true;
    }
    var rest = known.filter(function (h) {
        return !taken[h.name.toLowerCase()];
    }).sort(function (a, b) {
        var left = isAddress(a.name) ? 1 : 0;
        var right = isAddress(b.name) ? 1 : 0;
        return left - right || (a.name < b.name ? -1 : a.name > b.name ? 1 : 0);
    });
    return configured.concat(rest);
}

function detailOf(host) {
    if (host.known)
        return [host.port ? "port " + host.port : "", host.keyType || "", "known host"].filter(Boolean).join(" · ");
    var at = host.user ? host.user + "@" + (host.address || host.name) : host.address || "";
    var where = at && host.port && host.port !== "22" ? at + ":" + host.port : at || (host.port && host.port !== "22" ? "port " + host.port : "");
    return [where, host.jump ? "via " + host.jump : ""].filter(Boolean).join(" · ");
}

function matching(hosts, words, place, limit) {
    var want = String(words || "").toLowerCase();
    if (!want)
        return hosts.filter(function (h) {
            return !isAddress(h.name);
        }).slice(0, limit);
    var scored = [];
    for (var i = 0; i < hosts.length; i++) {
        var h = hosts[i];
        var best = Math.max(place(h.name, want), place(h.address, want) - 1, h.user ? place(h.user + "@" + h.name, want) - 1 : -1);
        if (best > 0)
            scored.push({
                host: h,
                score: best + (h.known ? 0 : 0.5),
                at: i
            });
    }
    scored.sort(function (a, b) {
        return b.score - a.score || a.at - b.at;
    });
    return scored.slice(0, limit).map(function (s) {
        return s.host;
    });
}

function ambient(hosts, text) {
    var want = String(text || "").trim().toLowerCase();
    if (want.length < 3 || /\s/.test(want))
        return [];
    return hosts.filter(function (h) {
        if (h.known)
            return false;
        var name = h.name.toLowerCase();
        return name === want || want.length >= 4 && name.indexOf(want) === 0;
    }).slice(0, 2);
}

function validTarget(target) {
    return TARGET.test(String(target || "")) && String(target).length <= 255;
}

function quote(text) {
    return "'" + String(text).replace(/'/g, "'\\''") + "'";
}

function terminalLine(host) {
    var args = host.known && host.port ? ["ssh", "-p", host.port, "--", host.name] : ["ssh", "--", host.name];
    return args.map(quote).join(" ") + '; status=$?; if [ "$status" -eq 255 ]; then echo; echo "ssh stopped with status $status. Press Enter to close."; read -r _; fi';
}

function commandText(host) {
    return host.known && host.port ? "ssh -p " + host.port + " " + host.name : "ssh " + host.name;
}
