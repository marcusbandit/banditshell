.pragma library

const BOARDS = {
    ansi: [
        ["`", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=", { w: 2 }, "Backspace"],
        [{ w: 1.5 }, "Tab", "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "[", "]", { w: 1.5 }, "\\"],
        [{ w: 1.75 }, "Caps", "A", "S", "D", "F", "G", "H", "J", "K", "L", ";", "'", { w: 2.25 }, "Enter"],
        [{ w: 2.25 }, "Shift", "Z", "X", "C", "V", "B", "N", "M", ",", ".", "/", { w: 2.75 }, "Shift"],
        [{ w: 1.25 }, "Ctrl", { w: 1.25 }, "Super", { w: 1.25 }, "Alt", { w: 6.25 }, "Space", { w: 1.25 }, "Alt", { w: 1.25 }, "Super", { w: 1.25 }, "Menu", { w: 1.25 }, "Ctrl"]
    ],
    iso: [
        ["`", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=", { w: 2 }, "Backspace"],
        [{ w: 1.5 }, "Tab", "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "[", "]", { x: 0.25, w: 1.25, h: 2, w2: 1.5, h2: 1, x2: -0.25 }, "Enter"],
        [{ w: 1.75 }, "Caps", "A", "S", "D", "F", "G", "H", "J", "K", "L", ";", "'", "#"],
        [{ w: 1.25 }, "Shift", "<", "Z", "X", "C", "V", "B", "N", "M", ",", ".", "/", { w: 2.75 }, "Shift"],
        [{ w: 1.25 }, "Ctrl", { w: 1.25 }, "Super", { w: 1.25 }, "Alt", { w: 6.25 }, "Space", { w: 1.25 }, "Alt", { w: 1.25 }, "Super", { w: 1.25 }, "Menu", { w: 1.25 }, "Ctrl"]
    ],
    split: [
        ["`", "1", "2", "3", "4", "5", "6", { x: 1 }, "7", "8", "9", "0", "-", "=", { w: 2 }, "Backspace"],
        [{ w: 1.5 }, "Tab", "Q", "W", "E", "R", "T", { x: 1 }, "Y", "U", "I", "O", "P", "[", "]", { w: 1.5 }, "\\"],
        [{ w: 1.75 }, "Caps", "A", "S", "D", "F", "G", { x: 1 }, "H", "J", "K", "L", ";", "'", { w: 2.25 }, "Enter"],
        [{ w: 2.25 }, "Shift", "Z", "X", "C", "V", "B", { x: 1 }, "N", "M", ",", ".", "/", { w: 2.75 }, "Shift"],
        [{ w: 1.25 }, "Ctrl", { w: 1.25 }, "Super", { w: 1.25 }, "Alt", { w: 3.25 }, "Space", { x: 1, w: 2.75 }, "Space", { w: 1.25 }, "Alt", { w: 1.25 }, "Super", { w: 1.25 }, "Menu", { w: 1.25 }, "Ctrl"]
    ]
};

const SAMPLE_VIA = {
    name: "sample 65%",
    layouts: { keymap: [
        ["0,0", "0,1", "0,2", "0,3", "0,4", "0,5", "0,6", "0,7", "0,8", "0,9", "0,10", "0,11", "0,12", { w: 2 }, "0,13", "0,14"],
        [{ w: 1.5 }, "1,0", "1,1", "1,2", "1,3", "1,4", "1,5", "1,6", "1,7", "1,8", "1,9", "1,10", "1,11", "1,12", { w: 1.5 }, "1,13", "1,14"],
        [{ w: 1.75 }, "2,0", "2,1", "2,2", "2,3", "2,4", "2,5", "2,6", "2,7", "2,8", "2,9", "2,10", "2,11", { w: 2.25 }, "2,13", "2,14"],
        [{ w: 2.25 }, "3,0", "3,2", "3,3", "3,4", "3,5", "3,6", "3,7", "3,8", "3,9", "3,10", "3,11", { w: 1.75 }, "3,12", "3,13", "3,14"],
        [{ w: 1.25 }, "4,0", { w: 1.25 }, "4,1", { w: 1.25 }, "4,2", { w: 6.25 }, "4,6", "4,9", "4,10", "4,11", "4,12", "4,13", "4,14"]
    ] }
};

function kle(rows) {
    const keys = [];
    let y = 0;
    for (const row of rows) {
        if (!Array.isArray(row))
            continue;
        let x = 0;
        let p = {};
        for (const item of row) {
            if (item && typeof item === "object") {
                if (item.x)
                    x += item.x;
                if (item.y)
                    y += item.y;
                p = Object.assign({}, p, item);
                continue;
            }
            const lines = String(item).split("\n");
            const label = lines.filter(Boolean).pop() || "";
            keys.push({
                matrix: /^\d+,\d+$/.test(lines[0].trim()) ? lines[0].trim() : "",
                x: x,
                y: y,
                w: p.w || 1,
                h: p.h || 1,
                x2: p.x2 || 0,
                y2: p.y2 || 0,
                w2: p.w2 || 0,
                h2: p.h2 || 0,
                label: /^\d+,\d+$/.test(label) ? "" : label
            });
            x += p.w || 1;
            p = {};
        }
        y += 1;
    }
    return keys;
}

function readVia(text) {
    let data;
    try {
        data = JSON.parse(text);
    } catch (e) {
        throw new Error("that file isn’t JSON");
    }
    const map = data && data.layouts ? data.layouts.keymap : null;
    if (!Array.isArray(map))
        throw new Error("no layouts.keymap in it, so it isn’t a VIA definition");
    const keys = kle(map);
    if (!keys.length)
        throw new Error("the keymap has no keys");
    return { name: data.name || "imported board", keys: keys };
}

function extent(keys) {
    let cols = 0;
    let rows = 0;
    for (const k of keys) {
        cols = Math.max(cols, k.x + k.w, k.x + k.x2 + (k.w2 || 0));
        rows = Math.max(rows, k.y + k.h);
    }
    return { cols: cols, rows: rows };
}

function rects(keys) {
    const out = [];
    for (const k of keys) {
        if (k.w2)
            out.push({ x: k.x + k.x2, y: k.y + k.y2, w: k.w2, h: k.h2 || 1, label: k.label, syms: k.syms || [], second: true });
        out.push({ x: k.x, y: k.y, w: k.w, h: k.h, label: k.label, syms: k.syms || [], second: false });
    }
    return out;
}

function board(shape) {
    return kle(BOARDS[shape] || BOARDS.ansi);
}

const KEY_NAMES = {
    mod: "super", super: "super", super_l: "super", meta: "super", win: "super",
    ctrl: "ctrl", control: "ctrl", alt: "alt", shift: "shift", space: "space", return: "enter", enter: "enter",
    escape: "esc", tab: "tab", backspace: "backspace", grave: "`", slash: "/", comma: ",", period: ".", minus: "-", equal: "=",
    bracketleft: "[", bracketright: "]", semicolon: ";", apostrophe: "'", backslash: "\\"
};

function keyName(raw) {
    const k = String(raw || "").toLowerCase();
    return KEY_NAMES[k] || k;
}

function withLegends(keys, legends) {
    return keys.map(k => legends[k.matrix] ? Object.assign({}, k, { label: legends[k.matrix].label, syms: legends[k.matrix].syms }) : k);
}

function struck(key, hot) {
    if (key.label && hot[key.label.toLowerCase()])
        return true;
    return (key.syms || []).some(s => !!hot[s.toLowerCase()]);
}

function lit(keys, combos) {
    const hot = {};
    for (const combo of combos)
        for (const part of String(combo).split(" "))
            if (part)
                hot[part.toLowerCase()] = true;
    return keys.map(k => struck(k, hot));
}
