const TOLERANCE = 0.125;

function near(a, b) {
    return Math.abs(a - b) < TOLERANCE;
}

function key(id, cap, syms, extra) {
    return Object.assign({ id, cap, syms }, extra ?? {});
}

function functionKeys(first, last) {
    const out = [];
    for (let n = first; n <= last; n++)
        out.push(key(`F${n}`, `F${n}`, [`F${n}`]));
    return out;
}

function letters(row, word) {
    const out = [];
    for (let n = 0; n < word.length; n++)
        out.push(key(`${row}${String(n + 1).padStart(2, "0")}`, word[n], [word[n].toLowerCase()]));
    return out;
}

const FUNCTION_ROWS = [
    [key("ESC", "Esc", ["Escape"]), { gap: 1 }]
        .concat(functionKeys(1, 4), [{ gap: 0.5 }], functionKeys(5, 8), [{ gap: 0.5 }], functionKeys(9, 12))
];

const NUMBER_ROW = [key("TLDE", "`", ["grave"])]
    .concat(letters("AE", "1234567890").map(k => Object.assign(k, { syms: [k.cap] })), [
        key("AE11", "-", ["minus"]),
        key("AE12", "=", ["equal"]),
        key("BKSP", "Back", ["BackSpace"], { units: 2 })
    ]);

const UPPER_LETTERS = [key("TAB", "Tab", ["Tab"], { units: 1.5 })]
    .concat(letters("AD", "QWERTYUIOP"), [
        key("AD11", "[", ["bracketleft"]),
        key("AD12", "]", ["bracketright"])
    ]);

const HOME_LETTERS = [key("CAPS", "Caps", ["Caps_Lock"], { units: 1.75 })]
    .concat(letters("AC", "ASDFGHJKL"), [
        key("AC10", ";", ["semicolon"]),
        key("AC11", "'", ["apostrophe"])
    ]);

const LOWER_LETTERS = letters("AB", "ZXCVBNM").concat([
    key("AB08", ",", ["comma"]),
    key("AB09", ".", ["period"]),
    key("AB10", "/", ["slash"])
]);

const ARROW_UP = [{ gap: 1.25 }, key("UP", "↑", ["Up"])];

const BOTTOM_ROW = [
    key("LCTL", "Ctrl", [], { mod: 4, units: 1.25 }),
    key("LWIN", "", [], { mod: 64, units: 1.25 }),
    key("LALT", "Alt", [], { mod: 8, units: 1.25 }),
    key("SPCE", "", ["space"], { units: 6.25 }),
    key("RALT", "Alt", [], { mod: 8, units: 1.25 }),
    key("RWIN", "", [], { mod: 64, units: 1.25 }),
    key("MENU", "Menu", ["Menu"], { units: 1.25 }),
    key("RCTL", "Ctrl", [], { mod: 4, units: 1.25 }),
    { gap: 0.25 },
    key("LEFT", "←", ["Left"]),
    key("DOWN", "↓", ["Down"]),
    key("RGHT", "→", ["Right"])
];

const RIGHT_SHIFT = key("RTSH", "Shift", [], { mod: 1, units: 2.75 });

const SPLIT_GAP = 1;

const SPLIT_BOTTOM_ROW = [
    key("LCTL", "Ctrl", [], { mod: 4, units: 1.25 }),
    key("LWIN", "", [], { mod: 64, units: 1.25 }),
    key("LALT", "Alt", [], { mod: 8, units: 1.25 }),
    key("SPCE", "", ["space"], { units: 3.25 }),
    { gap: SPLIT_GAP },
    key("SPCR", "", ["space"], { units: 2.75 }),
    key("RALT", "Alt", [], { mod: 8, units: 1.25 }),
    key("RWIN", "", [], { mod: 64, units: 1.25 }),
    key("MENU", "Menu", ["Menu"], { units: 1.25 }),
    key("RCTL", "Ctrl", [], { mod: 4, units: 1.25 }),
    { gap: 0.5 },
    key("LEFT", "←", ["Left"]),
    key("DOWN", "↓", ["Down"]),
    key("RGHT", "→", ["Right"])
];

function splitAfter(row, leftCount) {
    const out = [];
    let seen = 0;
    for (const cell of row) {
        out.push(cell);
        if (cell.gap === undefined && ++seen === leftCount)
            out.push({ gap: SPLIT_GAP });
    }
    return out;
}

function mainRows(variant) {
    if (variant === "ansi" || variant === "split") {
        const rows = [
            NUMBER_ROW,
            UPPER_LETTERS.concat([key("BKSL", "\\", ["backslash"], { units: 1.5 })]),
            HOME_LETTERS.concat([key("RTRN", "Enter", ["Return"], { units: 2.25 })]),
            [key("LFSH", "", [], { mod: 1, units: 2.25 })].concat(LOWER_LETTERS, [RIGHT_SHIFT])
        ];
        if (variant === "ansi")
            return rows.slice(0, 3).concat([rows[3].concat(ARROW_UP), BOTTOM_ROW]);
        return [
            splitAfter(rows[0], 7),
            splitAfter(rows[1], 6),
            splitAfter(rows[2], 6),
            splitAfter(rows[3], 6).concat(ARROW_UP),
            SPLIT_BOTTOM_ROW
        ];
    }
    return [
        NUMBER_ROW,
        UPPER_LETTERS.concat([key("RTRN", "Enter", ["Return"], { units: 1.5, span: 2, foot: 1.25 })]),
        HOME_LETTERS.concat([key("BKSL", "\\", ["backslash"])]),
        [key("LFSH", "", [], { mod: 1, units: 1.25 }), key("LSGT", "<", ["less"])].concat(LOWER_LETTERS, [RIGHT_SHIFT], ARROW_UP),
        BOTTOM_ROW
    ];
}

const NUMPAD_ROWS = [
    [
        key("NMLK", "Num", ["Num_Lock"]),
        key("KPDV", "/", ["KP_Divide"]),
        key("KPMU", "*", ["KP_Multiply"]),
        key("KPSU", "-", ["KP_Subtract"])
    ],
    [
        key("KP7", "7", ["KP_7", "KP_Home"]),
        key("KP8", "8", ["KP_8", "KP_Up"]),
        key("KP9", "9", ["KP_9", "KP_Page_Up"]),
        key("KPAD", "+", ["KP_Add"], { span: 2 })
    ],
    [
        key("KP4", "4", ["KP_4", "KP_Left"]),
        key("KP5", "5", ["KP_5", "KP_Begin"]),
        key("KP6", "6", ["KP_6", "KP_Right"])
    ],
    [
        key("KP1", "1", ["KP_1", "KP_End"]),
        key("KP2", "2", ["KP_2", "KP_Down"]),
        key("KP3", "3", ["KP_3", "KP_Page_Down"]),
        key("KPEN", "Enter", ["KP_Enter"], { span: 2 })
    ],
    [
        key("KP0", "0", ["KP_0", "KP_Insert"], { units: 2 }),
        key("KPDL", ".", ["KP_Decimal", "KP_Delete"])
    ]
];

function place(rows) {
    const keys = [];
    let width = 0;
    let height = 0;
    for (let y = 0; y < rows.length; y++) {
        let x = 0;
        for (const cell of rows[y]) {
            if (cell.gap !== undefined) {
                x += cell.gap;
                continue;
            }
            const w = cell.units ?? 1;
            const h = cell.span ?? 1;
            keys.push({
                id: cell.id,
                role: cell.id,
                cap: cell.cap,
                syms: cell.syms ?? [],
                mod: cell.mod ?? 0,
                matrix: "",
                encoder: false,
                x,
                y,
                w,
                h,
                foot: cell.foot ?? 0
            });
            x += w;
            width = Math.max(width, x);
            height = Math.max(height, y + h);
        }
    }
    return { keys, width, height };
}

function section(id, align, rows) {
    return Object.assign({ id, align }, place(rows));
}

function templateSections(variant) {
    return [
        section("function", "left", FUNCTION_ROWS),
        section("main", "left", mainRows(variant)),
        section("numpad", "right", NUMPAD_ROWS)
    ];
}

const SHAPES = ["ansi", "iso", "split"];
const TEMPLATE_VARIANT = "iso";

function shapeNamed(value) {
    return SHAPES.indexOf(value) >= 0 ? value : TEMPLATE_VARIANT;
}

const TEMPLATE = templateSections(TEMPLATE_VARIANT);
const MAIN_WIDTH = place([NUMBER_ROW]).width;

function freshSize() {
    return { w: 1, h: 1, x2: 0, y2: 0, w2: 0, h2: 0 };
}

function shapeOf(lines, x, y, size) {
    const out = {
        matrix: String(lines[0] ?? "").trim(),
        encoder: /^e\d+$/.test(String(lines[9] ?? "").trim()),
        x,
        y,
        w: size.w,
        h: size.h,
        foot: 0
    };
    const ell = size.w2 > 0 && size.h2 > 0 && size.h > size.h2 && size.y2 === 0 && size.x2 < 0 && near(size.x2 + size.w2, size.w);
    if (ell) {
        out.x = x + size.x2;
        out.w = size.w2;
        out.foot = size.w;
    }
    return out;
}

function parseVia(text) {
    let data;
    try {
        data = JSON.parse(String(text ?? ""));
    } catch (e) {
        return { error: "the file is not JSON" };
    }

    const keymap = data?.layouts?.keymap;
    if (!Array.isArray(keymap) || keymap.length === 0)
        return { error: Array.isArray(data?.layers) ? "the file is a saved keymap, not a definition · import it under VIA keymap" : "the file has no layouts.keymap, so it is not a VIA keyboard definition" };

    const rows = [];
    let y = 0;
    for (const raw of keymap) {
        if (!Array.isArray(raw))
            continue;
        const cells = [];
        let x = 0;
        let size = freshSize();
        for (const item of raw) {
            if (item && typeof item === "object") {
                if (typeof item.x === "number")
                    x += item.x;
                if (typeof item.y === "number")
                    y += item.y;
                for (const k of ["w", "h", "x2", "y2", "w2", "h2"])
                    if (typeof item[k] === "number")
                        size[k] = item[k];
                continue;
            }
            const lines = String(item).split("\n");
            const option = /^\s*(\d+)\s*,\s*(\d+)\s*$/.exec(lines[3] ?? "");
            if (!option || option[2] === "0")
                cells.push(shapeOf(lines, x, y, size));
            x += size.w;
            size = freshSize();
        }
        if (cells.length)
            rows.push(cells);
        y += 1;
    }

    if (!rows.length)
        return { error: "the layout lists no keys" };

    let left = Infinity;
    let top = Infinity;
    for (const row of rows)
        for (const cell of row) {
            left = Math.min(left, cell.x);
            top = Math.min(top, cell.y);
        }
    for (const row of rows) {
        for (const cell of row) {
            cell.x -= left;
            cell.y -= top;
        }
        row.sort((a, b) => a.x - b.x);
    }

    return {
        name: String(data.name ?? ""),
        vendorProductId: definitionId(data),
        matrix: { rows: Number(data.matrix?.rows) || 0, cols: Number(data.matrix?.cols) || 0 },
        rows
    };
}

function definitionId(data) {
    if (typeof data.vendorProductId === "number")
        return data.vendorProductId;
    const vendor = parseInt(String(data.vendorId ?? ""), 16);
    const product = parseInt(String(data.productId ?? ""), 16);
    return isNaN(vendor) || isNaN(product) ? null : vendor * 65536 + product;
}

function variantOf(main) {
    const upper = main[1] ?? [];
    const home = main[2] ?? [];
    const lower = main[3] ?? [];
    if (upper.some(k => k.h >= 2 && k.x < MAIN_WIDTH))
        return "iso";
    const enter = home.find(k => k.w >= 2 && near(k.x + k.w, MAIN_WIDTH));
    const above = upper.find(k => near(k.w, 1.5) && near(k.x + k.w, MAIN_WIDTH));
    if (enter && above)
        return "ansi";
    return lower.length && lower[0].w >= 2 ? "ansi" : "iso";
}

function findNumpad(main) {
    const pad = place(NUMPAD_ROWS).keys;
    let best = null;
    for (const start of main[0] ?? []) {
        if (start.x < MAIN_WIDTH - TOLERANCE)
            continue;
        let score = 0;
        for (const t of pad)
            if ((main[t.y] ?? []).some(p => near(p.x, start.x + t.x)))
                score++;
        if (score * 2 > pad.length && (!best || score > best.score))
            best = { x: start.x, score };
    }
    return best ? best.x : null;
}

function findArrows(main, limit) {
    const bottom = main[4] ?? [];
    const above = main[3] ?? [];
    for (let a = bottom.length - 3; a >= 0; a--) {
        const run = bottom.slice(a, a + 3);
        if (!run.every(k => near(k.w, 1) && near(k.h, 1) && k.x + k.w <= limit + TOLERANCE))
            continue;
        if (!near(run[1].x, run[0].x + 1) || !near(run[2].x, run[1].x + 1))
            continue;
        const up = above.find(k => near(k.w, 1) && near(k.x, run[1].x));
        if (up)
            return { up, left: run[0], down: run[1], right: run[2] };
    }
    return null;
}

function dressed(cell, donor) {
    return {
        id: cell.matrix,
        role: donor ? donor.role : "",
        cap: donor ? donor.cap : cell.encoder ? "Knob" : cell.matrix,
        syms: donor ? donor.syms : [],
        mod: donor ? donor.mod : 0,
        matrix: cell.matrix,
        encoder: cell.encoder,
        x: cell.x,
        y: cell.y,
        w: cell.w,
        h: cell.h,
        foot: cell.foot
    };
}

function alignBoard(parsed) {
    const rows = parsed.rows;
    const mainFrom = Math.max(0, rows.length - 5);
    const main = rows.slice(mainFrom);
    const variant = variantOf(main);

    const template = place(mainRows(variant)).keys;
    const byId = {};
    for (const t of template)
        byId[t.id] = t;
    const functionRow = place(FUNCTION_ROWS).keys;
    const pad = place(NUMPAD_ROWS).keys;

    const padX = findNumpad(main);
    const arrows = findArrows(main, padX === null ? Infinity : padX);
    const donors = new Map();
    if (arrows) {
        donors.set(arrows.up, byId.UP);
        donors.set(arrows.left, byId.LEFT);
        donors.set(arrows.down, byId.DOWN);
        donors.set(arrows.right, byId.RGHT);
    }

    for (let m = 0; m < main.length; m++) {
        const used = new Set();
        for (const cell of main[m]) {
            if (donors.has(cell) || cell.encoder)
                continue;
            const onPad = padX !== null && cell.x >= padX - TOLERANCE;
            const pool = onPad ? pad : template;
            const origin = onPad ? padX : 0;
            const donor = pool.find(t => t.y === m && !used.has(t) && near(origin + t.x, cell.x));
            if (donor) {
                used.add(donor);
                donors.set(cell, donor);
            }
        }
    }

    if (mainFrom > 0) {
        const fkeys = functionRow.slice();
        for (const cell of rows[mainFrom - 1]) {
            if (cell.encoder || !fkeys.length)
                continue;
            if (fkeys[0].id !== "ESC" && !near(cell.w, 1))
                continue;
            donors.set(cell, fkeys.shift());
        }
    }

    const keys = [];
    let width = 0;
    let height = 0;
    for (const row of rows)
        for (const cell of row) {
            keys.push(dressed(cell, donors.get(cell)));
            width = Math.max(width, cell.x + cell.w);
            height = Math.max(height, cell.y + cell.h);
        }

    return {
        name: parsed.name,
        variant,
        sections: [{
                id: "board",
                align: "left",
                keys,
                width,
                height
            }]
    };
}

const KEYCODE_ROLES = {
    KC_ESC: "ESC", KC_GRV: "TLDE", KC_MINS: "AE11", KC_EQL: "AE12", KC_BSPC: "BKSP",
    KC_TAB: "TAB", KC_LBRC: "AD11", KC_RBRC: "AD12", KC_BSLS: "BKSL",
    KC_CAPS: "CAPS", KC_SCLN: "AC10", KC_QUOT: "AC11", KC_ENT: "RTRN",
    KC_LSFT: "LFSH", KC_NUBS: "LSGT", KC_COMM: "AB08", KC_DOT: "AB09", KC_SLSH: "AB10", KC_RSFT: "RTSH",
    KC_LCTL: "LCTL", KC_LGUI: "LWIN", KC_LALT: "LALT", KC_SPC: "SPCE",
    KC_RALT: "RALT", KC_RGUI: "RWIN", KC_APP: "MENU", KC_RCTL: "RCTL",
    KC_UP: "UP", KC_LEFT: "LEFT", KC_DOWN: "DOWN", KC_RGHT: "RGHT",
    KC_NUM: "NMLK", KC_PSLS: "KPDV", KC_PAST: "KPMU", KC_PMNS: "KPSU", KC_PPLS: "KPAD", KC_PENT: "KPEN", KC_PDOT: "KPDL",
    KC_P7: "KP7", KC_P8: "KP8", KC_P9: "KP9", KC_P4: "KP4", KC_P5: "KP5", KC_P6: "KP6",
    KC_P1: "KP1", KC_P2: "KP2", KC_P3: "KP3", KC_P0: "KP0"
};

const KEYCODE_EXTRAS = {
    KC_NUHS: ["#", ["numbersign"]],
    KC_DEL: ["Del", ["Delete"]],
    KC_INS: ["Ins", ["Insert"]],
    KC_HOME: ["Home", ["Home"]],
    KC_END: ["End", ["End"]],
    KC_PGUP: ["PgUp", ["Prior", "Page_Up"]],
    KC_PGDN: ["PgDn", ["Next", "Page_Down"]],
    KC_PSCR: ["Print", ["Print"]],
    KC_SCRL: ["ScrLk", ["Scroll_Lock"]],
    KC_PAUS: ["Pause", ["Pause"]],
    KC_MUTE: ["Mute", ["XF86AudioMute"]],
    KC_VOLU: ["Vol+", ["XF86AudioRaiseVolume"]],
    KC_VOLD: ["Vol-", ["XF86AudioLowerVolume"]],
    KC_MPLY: ["Play", ["XF86AudioPlay"]],
    KC_MNXT: ["Next", ["XF86AudioNext"]],
    KC_MPRV: ["Prev", ["XF86AudioPrev"]],
    KC_MSTP: ["Stop", ["XF86AudioStop"]],
    KC_BRIU: ["Bright+", ["XF86MonBrightnessUp"]],
    KC_BRID: ["Bright-", ["XF86MonBrightnessDown"]]
};

function legendFrom(cap, syms, mod, role) {
    return { cap, syms, mod, role };
}

const BLANK_LEGEND = legendFrom("", [], 0, "");

function keycodeLegends() {
    const byId = {};
    for (const section of TEMPLATE)
        for (const k of section.keys)
            byId[k.id] = k;
    const out = {};
    for (const code in KEYCODE_ROLES) {
        const k = byId[KEYCODE_ROLES[code]];
        out[code] = legendFrom(k.cap, k.syms, k.mod, k.id);
    }
    for (const k of TEMPLATE[1].keys)
        if (/^[A-Z0-9]$/.test(k.cap) && /^A[BCDE]\d\d$/.test(k.id))
            out[`KC_${k.cap}`] = legendFrom(k.cap, k.syms, 0, k.id);
    for (let n = 1; n <= 24; n++)
        out[`KC_F${n}`] = legendFrom(`F${n}`, [`F${n}`], 0, byId[`F${n}`] ? `F${n}` : "");
    for (const code in KEYCODE_EXTRAS)
        out[code] = legendFrom(KEYCODE_EXTRAS[code][0], KEYCODE_EXTRAS[code][1], 0, "");
    return out;
}

const KEYCODES = keycodeLegends();

function knownKeycode(text) {
    return Object.prototype.hasOwnProperty.call(KEYCODES, text);
}

function legendOf(code) {
    const text = String(code ?? "").trim();
    if (knownKeycode(text))
        return KEYCODES[text];
    const layer = /^(?:MO|TG|TO|TT|OSL|DF)\(\s*(\d+)\s*\)$/.exec(text);
    if (layer)
        return legendFrom(`Fn${layer[1]}`, [], 0, "");
    const tapped = /^(?:LT\(\s*\d+\s*,|MT\([^,()]+,|[A-Z_]+_T\()\s*(KC_[A-Z0-9_]+)\s*\)$/.exec(text);
    if (tapped && knownKeycode(tapped[1]))
        return KEYCODES[tapped[1]];
    return BLANK_LEGEND;
}

const MOD_LABELS = { 1: "shift", 4: "ctrl", 8: "alt", 64: "super" };

function parseKeymap(text) {
    let data;
    try {
        data = JSON.parse(String(text ?? ""));
    } catch (e) {
        return { error: "the file is not JSON" };
    }

    const layers = data?.layers;
    if (!Array.isArray(layers) || layers.length === 0 || !Array.isArray(layers[0]) || layers[0].length === 0)
        return { error: Array.isArray(data?.layouts?.keymap) ? "the file is a definition, not a keymap · import it under VIA layout" : "the file has no layers, so it is not a VIA keymap" };
    if (typeof data.vendorProductId !== "number")
        return { error: "the file has no vendorProductId, so it is not a VIA keymap" };

    return {
        name: String(data.name ?? ""),
        vendorProductId: data.vendorProductId,
        layer: layers[0].map(code => String(code ?? ""))
    };
}

function keymapLegends(definition, keymap) {
    if (definition.vendorProductId !== null && definition.vendorProductId !== keymap.vendorProductId)
        return { error: `that keymap is for ${keymap.name || "another board"}, not the imported definition` };
    const rows = definition.matrix.rows;
    const cols = definition.matrix.cols;
    if (!cols)
        return { error: "the definition has no matrix size, so the keymap cannot be placed" };
    if (rows && keymap.layer.length !== rows * cols)
        return { error: `the keymap has ${keymap.layer.length} keys, the definition's matrix holds ${rows * cols}` };

    const legends = {};
    for (let n = 0; n < keymap.layer.length; n++) {
        const legend = legendOf(keymap.layer[n]);
        legends[`${Math.floor(n / cols)},${n % cols}`] = Object.assign({ label: legend.mod ? MOD_LABELS[legend.mod] : legend.cap || legend.syms[0] || "" }, legend);
    }
    return { legends };
}

function applyLegends(board, legends) {
    const keys = board.sections[0].keys.map(cell => {
        const legend = cell.encoder ? undefined : legends[cell.matrix];
        return legend ? Object.assign({}, cell, { role: legend.role, cap: legend.cap || (legend.syms.length || legend.mod ? "" : cell.matrix), syms: legend.syms, mod: legend.mod }) : cell;
    });
    return Object.assign({}, board, { sections: [Object.assign({}, board.sections[0], { keys })] });
}

function blockedMap(value) {
    const out = {};
    if (Array.isArray(value)) {
        for (const k of value)
            if (typeof k === "string" && k.trim())
                out[k.trim().toLowerCase()] = "";
    } else if (value && typeof value === "object") {
        for (const k in value)
            if (k.trim())
                out[k.trim().toLowerCase()] = String(value[k] ?? "");
    }
    return out;
}
