.pragma library

const ENOUGH = 3;
const BUSY = 0.12;

function placement(aspect, width, height) {
    if (!(aspect > 0) || width <= 0 || height <= 0)
        return null;
    const wide = aspect > width / height;
    const w = wide ? height * aspect : width;
    const h = wide ? height : width / aspect;
    return { x: (width - w) / 2, y: (height - h) / 2, width: w, height: h };
}

function shrunk(rect, factor, width, height) {
    const x = Math.max(0, Math.floor(rect.x * factor));
    const y = Math.max(0, Math.floor(rect.y * factor));
    const w = Math.min(width - x, Math.ceil(rect.width * factor));
    const h = Math.min(height - y, Math.ceil(rect.height * factor));
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
