.pragma library

const ENOUGH = 3;
const BUSY = 0.12;

function cover(imageW, imageH, screenW, screenH, rect) {
    if (imageW <= 0 || imageH <= 0 || screenW <= 0 || screenH <= 0)
        return null;
    const scale = Math.max(screenW / imageW, screenH / imageH);
    const offsetX = (imageW * scale - screenW) / 2;
    const offsetY = (imageH * scale - screenH) / 2;
    const x = Math.max(0, (rect.x + offsetX) / scale);
    const y = Math.max(0, (rect.y + offsetY) / scale);
    const w = Math.min(imageW - x, rect.width / scale);
    const h = Math.min(imageH - y, rect.height / scale);
    return w > 0 && h > 0 ? { x, y, width: w, height: h } : null;
}

function channel(v) {
    const c = v / 255;
    return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
}

function luminance(r, g, b) {
    return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b);
}

function contrast(a, b) {
    return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05);
}

function judge(data, lightInk, darkInk) {
    let seen = 0;
    let poorOnLight = 0;
    let poorOnDark = 0;
    for (let i = 0; i + 3 < data.length; i += 4) {
        const a = data[i + 3] / 255;
        const l = luminance(data[i] * a, data[i + 1] * a, data[i + 2] * a);
        seen++;
        if (contrast(l, lightInk) < ENOUGH)
            poorOnLight++;
        if (contrast(l, darkInk) < ENOUGH)
            poorOnDark++;
    }
    if (seen === 0)
        return { light: true, busy: false };
    const light = poorOnLight <= poorOnDark;
    return {
        light,
        busy: (light ? poorOnLight : poorOnDark) / seen > BUSY
    };
}
