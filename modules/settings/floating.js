.pragma library

function clamp(value, low, high) {
    return high < low ? low : Math.max(low, Math.min(high, value));
}

function place(room, width, height, spot, anchor) {
    const held = anchor ?? height;
    const cx = room.x + room.w / 2 + (spot?.x ?? 0);
    const cy = room.y + room.h / 2 + (spot?.y ?? 0);
    return {
        x: Math.round(clamp(cx - width / 2, room.x, room.x + room.w - width)),
        y: Math.round(clamp(cy - held / 2, room.y, room.y + room.h - height))
    };
}

function spotOf(room, width, height, x, y, anchor) {
    const held = anchor ?? height;
    return {
        x: Math.round(x + width / 2 - room.x - room.w / 2),
        y: Math.round(y + held / 2 - room.y - room.h / 2)
    };
}

function dragged(room, width, height, start, dx, dy, anchor) {
    const at = place(room, width, height, {
        x: (start?.x ?? 0) + dx,
        y: (start?.y ?? 0) + dy
    }, anchor);
    return spotOf(room, width, height, at.x, at.y, anchor);
}

function drawn(room, width, height, spot, anchor) {
    const at = place(room, width, height, spot, anchor);
    return spotOf(room, width, height, at.x, at.y, anchor);
}
