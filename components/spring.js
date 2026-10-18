.pragma library

function step(x, v, stiffness, damping, mass, t) {
    const m = Math.max(0.0001, mass);
    const k = Math.max(0.0001, stiffness);
    const w = Math.sqrt(k / m);
    const z = Math.max(0, damping) / (2 * Math.sqrt(k * m));
    if (z < 0.9999) {
        const a = z * w;
        const wd = w * Math.sqrt(1 - z * z);
        const fall = Math.exp(-a * t);
        const cos = Math.cos(wd * t);
        const sin = Math.sin(wd * t);
        return {
            x: fall * (x * cos + (v + a * x) / wd * sin),
            v: fall * (v * cos - (a * v + w * w * x) / wd * sin)
        };
    }
    if (z <= 1.0001) {
        const fall = Math.exp(-w * t);
        const lean = v + w * x;
        return {
            x: (x + lean * t) * fall,
            v: (v - w * lean * t) * fall
        };
    }
    const spread = Math.sqrt(z * z - 1);
    const r1 = -w * (z - spread);
    const r2 = -w * (z + spread);
    const c2 = (v - r1 * x) / (r2 - r1);
    const c1 = x - c2;
    return {
        x: c1 * Math.exp(r1 * t) + c2 * Math.exp(r2 * t),
        v: r1 * c1 * Math.exp(r1 * t) + r2 * c2 * Math.exp(r2 * t)
    };
}

function rest(x, v, stiffness, mass, epsilon) {
    const w = Math.sqrt(Math.max(0.0001, stiffness) / Math.max(0.0001, mass));
    return Math.abs(x) < epsilon && Math.abs(v) < epsilon * w;
}

function heldSpeed(speed, moved, dt) {
    const weight = 1 - Math.exp(-dt / 0.04);
    return speed + (moved / dt - speed) * weight;
}
