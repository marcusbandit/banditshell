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
    return entries.slice().sort((a, b) => {
        if ((a.kind === "dir") !== (b.kind === "dir"))
            return a.kind === "dir" ? -1 : 1;
        if (key === "size" && a.size !== b.size)
            return sign * (b.size - a.size);
        if (key === "mtime" && a.mtime !== b.mtime)
            return sign * (b.mtime - a.mtime);
        if (key === "kind" && a.class !== b.class)
            return sign * (a.class < b.class ? -1 : 1);
        const byName = a.name.localeCompare(b.name, undefined, {numeric: true, sensitivity: "base"});
        return key === "name" ? sign * byName : byName;
    });
}
