.pragma library

function toggleAction(open, covered, screen, current) {
    const here = !screen || screen === current;
    return open && here && !covered ? "hide" : "show";
}
