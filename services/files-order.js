.pragma library

const SORTS = ["name", "size", "mtime", "kind"];
const NATURAL = {numeric: true, sensitivity: "base"};

function merged(list, before) {
    let from = list.slice();
    let to = new Array(from.length);
    for (let width = 1; width < from.length; width *= 2) {
        for (let lo = 0; lo < from.length; lo += 2 * width) {
            const mid = Math.min(lo + width, from.length);
            const hi = Math.min(lo + 2 * width, from.length);
            let i = lo, j = mid, k = lo;
            while (i < mid && j < hi)
                to[k++] = before(from[j], from[i]) < 0 ? from[j++] : from[i++];
            while (i < mid)
                to[k++] = from[i++];
            while (j < hi)
                to[k++] = from[j++];
        }
        [from, to] = [to, from];
    }
    return from;
}

function ordered(entries, key) {
    return merged(entries, (a, b) => {
        if ((a.kind === "dir") !== (b.kind === "dir"))
            return a.kind === "dir" ? -1 : 1;
        if (key === "size" && a.size !== b.size)
            return b.size - a.size;
        if (key === "mtime" && a.mtime !== b.mtime)
            return b.mtime - a.mtime;
        if (key === "kind" && a.class !== b.class)
            return a.class < b.class ? -1 : 1;
        return a.name.localeCompare(b.name, undefined, NATURAL);
    });
}
