const BASE = ["systemd-run", "--user", "--scope", "--quiet", "--collect"];
const PROBE = "systemd-run --user --scope --quiet --collect --expand-environment=no -- true >/dev/null 2>&1 && echo literal && exit 0; systemd-run --user --scope --quiet --collect -- true >/dev/null 2>&1 && echo expanding; exit 0";
const KEPT = /[A-Za-z0-9:_.]/;
const LONGEST_ID = 180;

function prefixFor(answer) {
    const word = String(answer ?? "").trim();
    if (word === "literal")
        return BASE.concat(["--expand-environment=no"]);
    if (word === "expanding")
        return BASE.slice();
    return [];
}

function escapeId(id) {
    const text = String(id ?? "").replace(/\.desktop$/, "");
    let out = "";
    for (const c of text) {
        if (KEPT.test(c) && !(out === "" && c === "."))
            out += c;
        else if (c.charCodeAt(0) < 128)
            out += "\\x" + c.charCodeAt(0).toString(16).padStart(2, "0");
        else
            out += encodeURIComponent(c).replace(/%([0-9A-F]{2})/g, (_, hex) => "\\x" + hex.toLowerCase());
    }
    return (out || "app").slice(0, LONGEST_ID).replace(/\\x?[0-9a-f]?$/, "");
}

function unitName(id, stamp) {
    return `app-banditshell-${escapeId(id)}-${stamp}.scope`;
}

function command(prefix, id, stamp, argv) {
    if (!prefix || prefix.length === 0 || !argv || argv.length === 0)
        return argv;
    return prefix.concat([`--unit=${unitName(id, stamp)}`, "--"], argv);
}
