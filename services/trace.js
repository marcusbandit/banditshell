.pragma library

function heartbeatStall(gap, interval, sinceFirstFrame) {
    if (sinceFirstFrame < 0)
        return 0;
    return Math.max(0, Math.min(gap, sinceFirstFrame) - interval);
}
