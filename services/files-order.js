.pragma library

const SORTS = ["name", "size", "mtime", "kind"];

const SORT_WORDS = { name: "name", mtime: "date", size: "size", kind: "type" };

const ORDER_WORDS = {
    name: ["a to z", "z to a"],
    mtime: ["newest", "oldest"],
    size: ["biggest", "smallest"],
    kind: ["a to z", "z to a"]
};

function orderWords(key) {
    return ORDER_WORDS[key] ?? ORDER_WORDS.name;
}

function ordered(entries, key, reversed) {
    const sign = reversed ? -1 : 1;
    const byName = (a, b) => a.name.localeCompare(b.name, undefined, {numeric: true, sensitivity: "base"});
    const primary = {
        size: (a, b) => b.size - a.size,
        mtime: (a, b) => b.mtime - a.mtime,
        kind: (a, b) => a.class < b.class ? -1 : a.class > b.class ? 1 : 0
    }[key] ?? byName;
    return entries.slice().sort((a, b) => {
        if ((a.kind === "dir") !== (b.kind === "dir"))
            return a.kind === "dir" ? -1 : 1;
        return sign * primary(a, b) || byName(a, b);
    });
}
