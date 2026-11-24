.pragma library

function cpuTimes(stat) {
    const line = String(stat || "").split("\n").find(l => l.startsWith("cpu "));
    if (!line)
        return null;
    const parts = line.trim().split(/\s+/).slice(1).map(Number);
    if (parts.length < 4 || parts.some(n => isNaN(n)))
        return null;
    const idle = parts[3] + (parts[4] || 0);
    const total = parts.slice(0, 8).reduce((a, b) => a + b, 0);
    return { idle, total };
}

function cpuShare(before, after) {
    if (!before || !after)
        return 0;
    const total = after.total - before.total;
    const idle = after.idle - before.idle;
    if (total <= 0)
        return 0;
    return Math.max(0, Math.min(1, 1 - idle / total));
}

function coreTimes(stat) {
    const cores = [];
    for (const line of String(stat || "").split("\n")) {
        const m = line.match(/^cpu(\d+)\s+(.+)$/);
        if (!m)
            continue;
        const parts = m[2].trim().split(/\s+/).map(Number);
        if (parts.length < 4 || parts.some(n => isNaN(n)))
            continue;
        cores.push({
            id: Number(m[1]),
            idle: parts[3] + (parts[4] || 0),
            total: parts.slice(0, 8).reduce((a, b) => a + b, 0)
        });
    }
    cores.sort((a, b) => a.id - b.id);
    return cores.length ? cores : null;
}

function coreShares(before, after) {
    if (!Array.isArray(before) || !Array.isArray(after) || !after.length)
        return [];
    const prevById = {};
    for (let i = 0; i < before.length; i++)
        prevById[before[i].id] = before[i];
    return after.map(c => ({
        id: c.id,
        share: cpuShare(prevById[c.id], c)
    }));
}

function memoryShare(meminfo) {
    const kb = {};
    for (const line of String(meminfo || "").split("\n")) {
        const m = line.match(/^(\w+):\s+(\d+)/);
        if (m)
            kb[m[1]] = Number(m[2]);
    }
    if (!kb.MemTotal || kb.MemAvailable === undefined)
        return { share: 0, usedGb: 0, totalGb: 0 };
    return {
        share: Math.max(0, Math.min(1, 1 - kb.MemAvailable / kb.MemTotal)),
        usedGb: (kb.MemTotal - kb.MemAvailable) / 1048576,
        totalGb: kb.MemTotal / 1048576
    };
}

function memoryDetail(meminfo) {
    const kb = {};
    for (const line of String(meminfo || "").split("\n")) {
        const m = line.match(/^(\w+):\s+(\d+)/);
        if (m)
            kb[m[1]] = Number(m[2]);
    }
    if (!kb.MemTotal || kb.MemAvailable === undefined)
        return { share: 0, usedGb: 0, totalGb: 0, availableGb: 0, cachedGb: 0, swapUsedGb: 0, swapTotalGb: 0, swapShare: 0 };
    const swapTotal = kb.SwapTotal || 0;
    const swapFree = kb.SwapFree || 0;
    const swapUsed = Math.max(0, swapTotal - swapFree);
    return {
        share: Math.max(0, Math.min(1, 1 - kb.MemAvailable / kb.MemTotal)),
        usedGb: (kb.MemTotal - kb.MemAvailable) / 1048576,
        totalGb: kb.MemTotal / 1048576,
        availableGb: kb.MemAvailable / 1048576,
        cachedGb: ((kb.Cached || 0) + (kb.Buffers || 0)) / 1048576,
        swapUsedGb: swapUsed / 1048576,
        swapTotalGb: swapTotal / 1048576,
        swapShare: swapTotal > 0 ? Math.max(0, Math.min(1, swapUsed / swapTotal)) : 0
    };
}

function gpuShare(output) {
    const values = String(output || "").trim().split(/\s+/).map(Number).filter(n => isFinite(n));
    if (!values.length)
        return null;
    const peak = Math.max.apply(null, values);
    return Math.max(0, Math.min(1, peak / 100));
}

function gpuStats(output) {
    const lines = String(output || "").trim().split("\n").map(l => l.trim()).filter(Boolean);
    let best = null;
    for (let i = 0; i < lines.length; i++) {
        const cols = lines[i].split(",").map(s => s.trim());
        const util = Number(cols[0]);
        if (!isFinite(util))
            continue;
        const share = Math.max(0, Math.min(1, util / 100));
        const usedMb = cols.length > 1 ? Number(cols[1]) : NaN;
        const totalMb = cols.length > 2 ? Number(cols[2]) : NaN;
        const temp = cols.length > 3 ? Number(cols[3]) : NaN;
        const name = cols.length > 4 ? cols.slice(4).join(", ") : "";
        const entry = {
            share: share,
            vramUsedGb: isFinite(usedMb) ? usedMb / 1024 : 0,
            vramTotalGb: isFinite(totalMb) && totalMb > 0 ? totalMb / 1024 : 0,
            vramShare: isFinite(usedMb) && isFinite(totalMb) && totalMb > 0 ? Math.max(0, Math.min(1, usedMb / totalMb)) : 0,
            tempC: isFinite(temp) ? Math.round(temp) : 0,
            name: name
        };
        if (!best || entry.share > best.share)
            best = entry;
    }
    return best;
}

function swapDevices(swapsText) {
    const lines = String(swapsText || "").trim().split("\n").slice(1);
    const out = [];
    for (let i = 0; i < lines.length; i++) {
        const parts = lines[i].trim().split(/\s+/);
        if (parts.length < 5)
            continue;
        const path = parts[0];
        const sizeKb = Number(parts[2]);
        const usedKb = Number(parts[3]);
        const priority = Number(parts[4]);
        if (!isFinite(sizeKb) || sizeKb <= 0 || !isFinite(usedKb))
            continue;
        const name = path.startsWith("/dev/") ? path.slice(5) : path;
        out.push({
            name: name,
            path: path,
            type: parts[1],
            usedGb: usedKb / 1048576,
            totalGb: sizeKb / 1048576,
            share: Math.max(0, Math.min(1, usedKb / sizeKb)),
            priority: isFinite(priority) ? priority : 0
        });
    }
    out.sort((a, b) => b.priority - a.priority);
    return out;
}

function pushCoreHistories(histories, cores, limit) {
    if (!Array.isArray(cores) || !cores.length)
        return [];
    const prev = Array.isArray(histories) ? histories : [];
    return cores.map((c, i) => pushHistory(prev[i], c.share, limit));
}

function tempShare(celsius) {
    return clamp01((Number(celsius) || 0) / 100);
}

function pushHistory(samples, value, limit) {
    const max = Math.max(2, Number(limit) || 24);
    const clamped = Math.max(0, Math.min(1, isFinite(value) ? value : 0));
    const next = Array.isArray(samples) ? samples.slice(-(max - 1)) : [];
    next.push(clamped);
    return next;
}

function clamp01(value) {
    return Math.max(0, Math.min(1, isFinite(value) ? value : 0));
}

function smooth(t) {
    const u = clamp01(t);
    return 0.5 - 0.5 * Math.cos(Math.PI * u);
}

function tipValue(samples, phase) {
    if (!Array.isArray(samples) || samples.length === 0)
        return 0;
    if (samples.length === 1)
        return clamp01(samples[0]);
    const p = phase === undefined ? 1 : smooth(phase);
    const prev = clamp01(samples[samples.length - 2]);
    const curr = clamp01(samples[samples.length - 1]);
    return prev + (curr - prev) * p;
}

function plotPoints(samples, width, height, limit, phase) {
    if (!Array.isArray(samples) || samples.length < 2 || !(width > 0) || !(height > 0))
        return [];
    const p = phase === undefined ? 1 : clamp01(phase);
    const slots = Math.max(2, Number(limit) || samples.length);
    const step = width / (slots - 1);
    const n = samples.length;
    const raw = [];
    for (let i = 0; i < n - 1; i++) {
        raw.push({
            x: width - (n - 2 - i + p) * step,
            v: clamp01(samples[i])
        });
    }
    const pts = [];
    let start = 0;
    while (start < raw.length && raw[start].x <= 0)
        start += 1;
    if (start > 0) {
        const left = raw[start - 1];
        const right = start < raw.length ? raw[start] : { x: width, v: tipValue(samples, p) };
        const span = right.x - left.x;
        const t = span > 0 ? smooth((0 - left.x) / span) : 0;
        const lv = left.v + (right.v - left.v) * t;
        pts.push({ x: 0, y: (1 - lv) * height });
    }
    for (let i = start; i < raw.length; i++) {
        if (raw[i].x < width - 0.01)
            pts.push({ x: raw[i].x, y: (1 - raw[i].v) * height });
    }
    const tv = tipValue(samples, p);
    pts.push({ x: width, y: (1 - tv) * height });
    return pts;
}

function buildLine(pts) {
    const m = pts.length;
    if (m < 2)
        return "";
    const f = n => n.toFixed(1);
    if (m === 2)
        return `M${f(pts[0].x)} ${f(pts[0].y)} L${f(pts[1].x)} ${f(pts[1].y)}`;
    const d = [];
    for (let i = 0; i < m - 1; i++) {
        const dx = pts[i + 1].x - pts[i].x;
        d.push(dx > 0 ? (pts[i + 1].y - pts[i].y) / dx : 0);
    }
    const t = [d[0]];
    for (let i = 1; i < m - 1; i++) {
        if (d[i - 1] * d[i] <= 0) {
            t.push(0);
        } else {
            const avg = (d[i - 1] + d[i]) / 2;
            const bound = 3 * Math.min(Math.abs(d[i - 1]), Math.abs(d[i]));
            t.push(Math.max(-bound, Math.min(bound, avg)));
        }
    }
    t.push(d[m - 2]);
    const parts = [`M${f(pts[0].x)} ${f(pts[0].y)}`];
    for (let i = 0; i < m - 1; i++) {
        const dx = pts[i + 1].x - pts[i].x;
        const c1x = pts[i].x + dx / 3;
        const c1y = pts[i].y + t[i] * dx / 3;
        const c2x = pts[i + 1].x - dx / 3;
        const c2y = pts[i + 1].y - t[i + 1] * dx / 3;
        parts.push(`C${f(c1x)} ${f(c1y)} ${f(c2x)} ${f(c2y)} ${f(pts[i + 1].x)} ${f(pts[i + 1].y)}`);
    }
    return parts.join(" ");
}

function linePath(samples, width, height, limit, phase) {
    return buildLine(plotPoints(samples, width, height, limit, phase));
}

function areaPath(samples, width, height, limit, phase) {
    const pts = plotPoints(samples, width, height, limit, phase);
    const line = buildLine(pts);
    if (!line)
        return "";
    const firstX = pts[0].x.toFixed(1);
    const lastX = pts[pts.length - 1].x.toFixed(1);
    const bottom = height.toFixed(1);
    return `${line} L${lastX} ${bottom} L${firstX} ${bottom} Z`;
}

function tipPoint(samples, width, height, limit, phase) {
    if (!Array.isArray(samples) || samples.length === 0 || !(width > 0) || !(height > 0))
        return null;
    const v = tipValue(samples, phase);
    return {
        x: width,
        y: (1 - v) * height
    };
}
