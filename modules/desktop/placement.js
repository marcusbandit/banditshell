.pragma library

const SIZES = ["small", "medium", "large"];

const COLUMNS = {
    left: ["system", "limits"],
    right: ["clock", "weather", "media"]
};

function clamp(value, low, high) {
    return Math.max(low, Math.min(high, value));
}

function isPlace(place) {
    return !!place && (place.side === "left" || place.side === "right") && (place.edge === "top" || place.edge === "bottom") && typeof place.x === "number" && isFinite(place.x) && typeof place.y === "number" && isFinite(place.y);
}

function topLeft(place, width, height, area) {
    const x = place.side === "right" ? area.x + area.width - place.x - width : area.x + place.x;
    const y = place.edge === "bottom" ? area.y + area.height - place.y - height : area.y + place.y;
    return {
        x: clamp(x, area.x, Math.max(area.x, area.x + area.width - width)),
        y: clamp(y, area.y, Math.max(area.y, area.y + area.height - height))
    };
}

function placeAt(x, y, width, height, area) {
    const left = clamp(x, area.x, Math.max(area.x, area.x + area.width - width));
    const top = clamp(y, area.y, Math.max(area.y, area.y + area.height - height));
    const side = left + width / 2 > area.x + area.width / 2 ? "right" : "left";
    const edge = top + height / 2 > area.y + area.height / 2 ? "bottom" : "top";
    return {
        side,
        edge,
        x: Math.round(side === "right" ? area.x + area.width - left - width : left - area.x),
        y: Math.round(edge === "bottom" ? area.y + area.height - top - height : top - area.y)
    };
}

function columnOf(key) {
    return COLUMNS.left.includes(key) ? "left" : "right";
}

function stacked(key, heights, gap) {
    const side = columnOf(key);
    let y = 0;
    for (const other of COLUMNS[side]) {
        if (other === key)
            break;
        if (heights[other] > 0)
            y += heights[other] + gap;
    }
    return { side, edge: "top", x: 0, y };
}

function validSize(size, fallback) {
    return SIZES.includes(size) ? size : fallback;
}

function badgeSide(place) {
    return place && place.side === "right" ? "left" : "right";
}

function grid(area, pitch, gap) {
    const cols = Math.max(1, Math.round((area.width + gap) / pitch));
    const rows = Math.max(1, Math.round((area.height + gap) / pitch));
    return {
        x: area.x,
        y: area.y,
        width: area.width,
        height: area.height,
        gap,
        px: (area.width + gap) / cols,
        py: (area.height + gap) / rows
    };
}

function span(length, pitch, gap) {
    if (!(length > 0) || !(pitch > 0))
        return 0;
    return Math.max(1, Math.ceil((length + gap) / pitch - 1e-6)) * pitch - gap;
}

function boxOf(width, height, g) {
    return { width: span(width, g.px, g.gap), height: span(height, g.py, g.gap) };
}

function snapPlace(place, g) {
    return {
        side: place.side,
        edge: place.edge,
        x: Math.max(0, Math.round(place.x / g.px) * g.px),
        y: Math.max(0, Math.round(place.y / g.py) * g.py)
    };
}

function crowds(a, b, gap) {
    const slack = gap - 0.5;
    return a.x < b.x + b.width + slack && b.x < a.x + a.width + slack && a.y < b.y + b.height + slack && b.y < a.y + a.height + slack;
}

function freeSpot(x, y, width, height, others, g) {
    const lastCol = Math.max(0, Math.floor((g.width - width) / g.px + 1e-6));
    const lastRow = Math.max(0, Math.floor((g.height - height) / g.py + 1e-6));
    const wantCol = clamp(Math.round((x - g.x) / g.px), 0, lastCol);
    const wantRow = clamp(Math.round((y - g.y) / g.py), 0, lastRow);
    let best = null;
    let bestDistance = Infinity;
    for (let col = 0; col <= lastCol; col++) {
        const dx = (col - wantCol) * g.px;
        if (dx * dx >= bestDistance)
            continue;
        for (let row = 0; row <= lastRow; row++) {
            const dy = (row - wantRow) * g.py;
            const distance = dx * dx + dy * dy;
            if (distance >= bestDistance)
                continue;
            const spot = { x: g.x + col * g.px, y: g.y + row * g.py, width, height };
            if (others.some(o => crowds(spot, o, g.gap)))
                continue;
            best = spot;
            bestDistance = distance;
        }
    }
    const fallback = { x: g.x + wantCol * g.px, y: g.y + wantRow * g.py };
    return best ? { x: best.x, y: best.y } : fallback;
}
