.pragma library

function read(line) {
    let msg;
    try {
        msg = JSON.parse(line);
    } catch (e) {
        return null;
    }
    if (!msg || typeof msg !== "object" || Array.isArray(msg))
        return null;
    const phase = typeof msg.phase === "string" ? msg.phase : null;
    return {
        phase: phase,
        lang: typeof msg.lang === "string" ? msg.lang : null,
        level: typeof msg.level === "number" ? msg.level : null,
        canCancel: msg.cancel === true,
        cancelled: msg.cancelled === true && phase === "idle"
    };
}
