.pragma library

function completes(progress, velocity, commit, reversal, flick) {
    var carried = progress >= commit && velocity > -reversal;
    if (flick > 0)
        return velocity >= flick || carried;
    return velocity >= 0 || carried;
}
