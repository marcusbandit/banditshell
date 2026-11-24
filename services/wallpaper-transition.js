.pragma library

function readPick(text, asked) {
    const bits = String(text).trim().split("\t");
    if (bits.length < 6 || bits[0] !== asked)
        return null;
    if (bits[1] !== "contagion" && bits[1] !== "outline")
        return { failed: true };
    return {
        kind: bits[1],
        field: bits[2],
        line: bits[3],
        ember: bits[4] === "-" ? "" : bits[4],
        ink: bits[5] === "-" ? "" : bits[5]
    };
}
