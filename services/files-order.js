.pragma library

const SORTS = ["name", "size", "mtime", "kind"];

function ordered(entries, key) {
    return entries.slice().sort((a, b) => {
        if ((a.kind === "dir") !== (b.kind === "dir"))
            return a.kind === "dir" ? -1 : 1;
        if (key === "size" && a.size !== b.size)
            return b.size - a.size;
        if (key === "mtime" && a.mtime !== b.mtime)
            return b.mtime - a.mtime;
        if (key === "kind" && a.class !== b.class)
            return a.class < b.class ? -1 : 1;
        return a.name.localeCompare(b.name, undefined, {numeric: true, sensitivity: "base"});
    });
}
