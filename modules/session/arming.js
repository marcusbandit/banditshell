.pragma library

function press(entry, arming, armedAt, now, doubleClick) {
    if (entry.safe)
        return "run";
    if (arming !== entry.key)
        return "arm";
    return now - armedAt < doubleClick ? "wait" : "run";
}
