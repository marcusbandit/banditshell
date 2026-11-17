.pragma library

function between(height, span, top, bottom) {
    var centred = (span - height) / 2;
    return {
        y: Math.round(Math.max(top, Math.min(centred, bottom - height))),
        fits: bottom - top >= height
    };
}

function rail(height, span, top, foot, reserve, gap) {
    var y = between(height, span, top, foot - reserve - gap).y;
    return {
        y: y,
        room: foot - y - height - gap
    };
}
