.pragma library

function chordParts(chord) {
    return String(chord || "").split("+").map(p => p.trim()).filter(Boolean);
}

function sameChord(a, b) {
    const norm = c => chordParts(c).map(p => p.toUpperCase()).sort().join("+");
    return !!norm(a) && norm(a) === norm(b);
}

function legacyChord(chord) {
    const parts = chordParts(chord);
    const key = parts.pop() || "";
    return `${parts.join(" ")}, ${key}`;
}

function chordText(chord) {
    return chordParts(chord).map(p => p.length <= 1 ? p : p.charAt(0) + p.slice(1).toLowerCase()).join(" ");
}

function hotkeyCommand(id) {
    return `banditshell action launcher.run '${String(id).replace(/'/g, "'\\''")}'`;
}
