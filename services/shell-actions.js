.pragma library

var ASK = /^actions?(?:\s+(.*))?$/i;
var SILENT_TAIL = /\.(?:status|list|get|probe|palette|log|find|show|answer)$/;
var NEVER = /^(?:launcher|shell)\./;
var DESTRUCTIVE_TAIL = /\.(?:clear|remove|cancel)$/;
var ARGUMENTS = /\s*\((optional )?(arguments?):\s*([^)]*)\)\s*$/;
var AMBIENT_SCALE = 0.1;

function ask(text) {
    var m = ASK.exec(String(text || "").trim());
    return m ? { words: String(m[1] || "").trim().toLowerCase() } : null;
}

function panelNames(commandsText) {
    var lines = String(commandsText || "").split("\n");
    for (var i = 0; i < lines.length; i++) {
        var f = lines[i].split("\t");
        if (f[0] === "values" && f[1] === "panel")
            return String(f[2] || "").split(/\s+/).filter(function (n) {
                return n.length > 0 && n !== "launcher";
            });
    }
    return [];
}

function argumentsOf(about) {
    var m = ARGUMENTS.exec(String(about || ""));
    if (!m)
        return null;
    var plural = m[2] === "arguments";
    var first = m[3].split(",")[0].trim();
    return { required: !m[1], plural: plural, prompt: (plural ? "Arguments: " : "Argument: ") + first };
}

function labelOf(about) {
    var text = String(about || "").replace(ARGUMENTS, "");
    return text.charAt(0).toUpperCase() + text.slice(1);
}

function rowFor(id, about) {
    return {
        id: id,
        label: labelOf(about),
        words: id.replace(/[._]/g, " "),
        args: argumentsOf(about),
        destructive: DESTRUCTIVE_TAIL.test(id)
    };
}

function parseTable(text, panels) {
    var out = [];
    var lines = String(text || "").split("\n");
    for (var i = 0; i < lines.length; i++) {
        if (!lines[i] || lines[i].charAt(0) === "#")
            continue;
        var f = lines[i].split("\t");
        if (f.length < 5 || f[1] !== "stable")
            continue;
        var id = f[0];
        if (NEVER.test(id) || SILENT_TAIL.test(id))
            continue;
        if (id.indexOf("*") < 0) {
            out.push(rowFor(id, f[4]));
            continue;
        }
        for (var p = 0; p < (panels || []).length; p++)
            out.push(rowFor(id.replace("*", panels[p]), f[4].replace(/\ba panel or menu\b/, "the " + panels[p])));
    }
    return out;
}

function tokens(words) {
    return String(words || "").toLowerCase().split(/\s+/).filter(function (t) {
        return t.length > 0;
    });
}

function relevance(row, want, phrase, place) {
    var label = row.label.toLowerCase();
    for (var i = 0; i < want.length; i++)
        if (label.indexOf(want[i]) < 0 && row.words.indexOf(want[i]) < 0)
            return -1;
    return Math.max(place(row.label, phrase), place(row.words, phrase) - 0.5, 0.5);
}

function matching(rows, words, place, limit) {
    var want = tokens(words);
    var phrase = want.join(" ");
    var scored = [];
    for (var i = 0; i < rows.length; i++) {
        var s = want.length ? relevance(rows[i], want, phrase, place) : 1;
        if (s > 0)
            scored.push({ row: rows[i], score: s, at: i });
    }
    scored.sort(function (a, b) {
        return b.score - a.score || a.at - b.at;
    });
    return scored.slice(0, limit).map(function (s) {
        return s.row;
    });
}

function ambient(rows, text, place, limit) {
    var want = String(text || "").trim().toLowerCase();
    if (want.length < 3)
        return [];
    var scored = [];
    for (var i = 0; i < rows.length; i++) {
        var s = Math.max(place(rows[i].label, want), place(rows[i].words, want) - 0.5);
        if (s >= 2)
            scored.push({ row: rows[i], score: s * AMBIENT_SCALE, at: i });
    }
    scored.sort(function (a, b) {
        return b.score - a.score || a.at - b.at;
    });
    return scored.slice(0, limit);
}

function argv(row, typed) {
    var out = ["action", row.id];
    var text = String(typed || "").trim();
    if (row.args && text)
        return out.concat(row.args.plural ? text.split(/\s+/) : [text]);
    return out;
}
