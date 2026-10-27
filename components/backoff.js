.pragma library

function grow(step, base, cap) {
    if (!(step >= base))
        return base;
    return Math.min(cap, step * 2);
}
