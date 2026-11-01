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
