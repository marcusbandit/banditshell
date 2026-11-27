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
    return !!place && (place.side === "left" || place.side === "right") && (place.edge === "top" || place.edge === "bottom") && isFinite(place.x) && isFinite(place.y);
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

function sizeUp(size) {
    return size === "small" ? "medium" : size;
}

function validSize(size, fallback) {
    return SIZES.includes(size) ? size : fallback;
}

function badgeSide(place) {
    return place && place.side === "right" ? "left" : "right";
}
