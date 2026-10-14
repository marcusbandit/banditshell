.pragma library

const sim = { level: 0, phase: "intro", target: 73, charging: true, samples: [], sampleAt: 0 };
const DRAIN = { saver: 1.2, balanced: 2.4, fast: 4.5 };
const CHARGE = 7;

function step(dt, o) {
    const b = sim;
    const cap = o.limit ? o.max : 100;
    const home = o.home;
    if (!o.present) {
        b.charging = false;
        b.target = 0;
        b.phase = "dead";
    } else if (b.phase === "dead") {
        b.phase = "charge";
        b.target = cap;
        b.charging = true;
    }
    const rate = b.phase === "intro" ? 40 : b.charging ? CHARGE : (DRAIN[o.profile] || 2.4);
    const dir = Math.sign(b.target - b.level);
    b.level = dir > 0 ? Math.min(b.target, b.level + rate * dt) : Math.max(b.target, b.level - rate * dt);
    if (b.level === b.target && b.phase !== "dead") {
        const rnd = (lo, hi) => Math.round(lo + Math.random() * (hi - lo));
        if (b.phase === "intro") {
            b.phase = "charge";
            b.charging = true;
            b.target = cap;
        } else if (b.phase === "charge") {
            b.phase = "settle";
            b.charging = false;
            b.target = Math.min(home, cap);
        } else if (b.charging) {
            b.charging = false;
            b.target = rnd(Math.max(o.warn - 5, 8), Math.max(o.warn + 10, Math.min(cap - 15, 55)));
            b.phase = "cycle";
        } else {
            b.charging = true;
            b.target = rnd(Math.min(cap, 60), cap);
            b.phase = "cycle";
        }
    }
    b.sampleAt += dt;
    if (b.sampleAt > 0.25 || !b.samples.length) {
        b.sampleAt = 0;
        b.samples.push(b.level);
        if (b.samples.length > 60)
            b.samples.shift();
    }
    return { level: b.level, charging: b.charging, target: b.target, samples: b.samples.slice() };
}

function still(o) {
    if (sim.phase === "intro") {
        sim.level = o.present ? o.home : 0;
        sim.phase = "settle";
    }
    if (!sim.samples.length)
        sim.samples.push(sim.level);
    return { level: sim.level, charging: sim.charging, target: sim.target, samples: sim.samples.slice() };
}
