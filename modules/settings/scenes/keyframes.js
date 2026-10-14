.pragma library

function bezier(x1, y1, x2, y2) {
    const cx = 3 * x1;
    const bx = 3 * (x2 - x1) - cx;
    const ax = 1 - cx - bx;
    const cy = 3 * y1;
    const by = 3 * (y2 - y1) - cy;
    const ay = 1 - cy - by;
    const sx = t => ((ax * t + bx) * t + cx) * t;
    const sy = t => ((ay * t + by) * t + cy) * t;
    const dx = t => (3 * ax * t + 2 * bx) * t + cx;
    return x => {
        if (x <= 0)
            return 0;
        if (x >= 1)
            return 1;
        let t = x;
        for (let i = 0; i < 8; i++) {
            const e = sx(t) - x;
            const d = dx(t);
            if (Math.abs(e) < 1e-5 || Math.abs(d) < 1e-6)
                break;
            t -= e / d;
        }
        if (t < 0 || t > 1) {
            let lo = 0;
            let hi = 1;
            t = x;
            for (let i = 0; i < 20; i++) {
                if (sx(t) < x)
                    lo = t;
                else
                    hi = t;
                t = (lo + hi) / 2;
            }
        }
        return sy(t);
    };
}

const STANDARD = bezier(0.4, 0, 0.2, 1);
const ARRIVE = bezier(0.22, 0.9, 0.3, 1);
const BACK = bezier(0.34, 1.56, 0.64, 1);
const EASE = bezier(0.25, 0.1, 0.25, 1);
const EASE_OUT = bezier(0, 0, 0.58, 1);
const EASE_IN_OUT = bezier(0.42, 0, 0.58, 1);
const LINEAR = x => x;

function steps(x) {
    return x < 1 ? 0 : 1;
}

function expand(frames) {
    const out = [];
    for (const f of frames) {
        const at = [].concat(f[0]);
        for (const p of at)
            out.push([p, f[1]]);
    }
    out.sort((a, b) => a[0] - b[0]);
    const filled = [];
    let last = {};
    for (const f of out) {
        last = Object.assign({}, last, f[1]);
        filled.push([f[0], last]);
    }
    return filled;
}

function at(frames, t, ease) {
    const list = frames.expanded || (frames.expanded = expand(frames));
    const p = t * 100;
    const curve = ease || STANDARD;
    if (p <= list[0][0])
        return list[0][1];
    for (let i = 1; i < list.length; i++) {
        const a = list[i - 1];
        const b = list[i];
        if (p <= b[0]) {
            const span = b[0] - a[0];
            const k = span <= 0 ? 1 : curve((p - a[0]) / span);
            const out = {};
            for (const key in b[1]) {
                const va = a[1][key];
                const vb = b[1][key];
                out[key] = typeof vb === "number" && typeof va === "number" ? va + (vb - va) * k : (k < 1 ? va : vb);
            }
            return out;
        }
    }
    return list[list.length - 1][1];
}

function pulse(t, delay, period) {
    const local = ((t - delay) % period + period) % period;
    return local / period;
}
