.pragma library

function inset(small, hair) {
    return small + hair * 2;
}

function fit(width, digit, font, mark, small, gap, least, stacked) {
    const dateWidth = stacked ? digit * 13 : font * 7;
    const sizeWidth = font * 5;
    const spare = width - (mark + small + digit * least);
    const showsDate = spare >= (stacked ? Math.max(dateWidth, sizeWidth) + gap : dateWidth + sizeWidth + gap * 2);
    return {
        dateWidth: dateWidth,
        sizeWidth: sizeWidth,
        showsDate: showsDate,
        showsSize: stacked ? showsDate : spare >= sizeWidth + gap
    };
}
