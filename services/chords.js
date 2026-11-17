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

function hotkeyCommand(id, toggle) {
    return `banditshell action launcher.run '${String(id).replace(/'/g, "'\\''")}'${toggle ? " toggle" : ""}`;
}

var HIDING_PLACE = "special:hidden";

function toggleStep(windows, focused) {
    if (!windows.length)
        return { step: "launch", addresses: [] };
    if (windows.some(w => w.address === focused))
        return { step: "hide", addresses: windows.map(w => w.address) };
    var hidden = windows.filter(w => w.workspace === HIDING_PLACE);
    if (hidden.length)
        return { step: "bring", addresses: hidden.map(w => w.address) };
    return { step: "focus", addresses: [windows[0].address] };
}
