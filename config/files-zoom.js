.pragma library

const SMALLEST = 0.7;
const LARGEST = 2.5;

function clamp(zoom) {
    const n = Number(zoom);
    if (!Number.isFinite(n) || n <= 0)
        return 1;
    return Math.max(SMALLEST, Math.min(LARGEST, n));
}
