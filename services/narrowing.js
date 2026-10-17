.pragma library

function byPath(text) {
    return String(text || "").indexOf("/") >= 0;
}

function narrows(previous, next) {
    const p = String(previous || "");
    const n = String(next || "");
    return !!p && byPath(p) === byPath(n) && n.length >= p.length && n.toLowerCase().indexOf(p.toLowerCase()) >= 0;
}

function grepNarrows(previous, next) {
    const p = String(previous || "");
    const n = String(next || "");
    if (!p || n.length < p.length)
        return false;
    return p !== p.toLowerCase() ? n.indexOf(p) >= 0 : n.toLowerCase().indexOf(p) >= 0;
}

function baseName(path) {
    const s = String(path || "").replace(/\/+$/, "");
    return s.slice(s.lastIndexOf("/") + 1);
}

function keepNamed(lines, text) {
    const t = String(text || "").toLowerCase();
    const whole = byPath(t);
    return (lines || []).filter(line => line && (whole ? line.replace(/\/$/, "") : baseName(line)).toLowerCase().indexOf(t) >= 0);
}

function pathOf(hit) {
    const m = /^(.*?):\d+:/.exec(String(hit || ""));
    return m ? m[1] : "";
}
