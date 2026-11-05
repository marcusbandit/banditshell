.pragma library

var FORMATS = {
    still: ["png", "jpg", "jpeg", "webp", "bmp", "avif", "svg"],
    motion: ["gif", "apng"],
    video: ["mp4", "webm", "mkv", "mov", "m4v"],
    audio: ["mp3", "flac", "ogg", "opus", "wav", "m4a"]
};

function expand(path, home, shipped) {
    if (!path)
        return "";
    if (path.startsWith("shipped:"))
        return shipped + path.slice("shipped:".length);
    return path.replace(/^(~|\$HOME)(?=\/|$)/, () => home);
}

function kindOf(path, formats) {
    const dot = path.lastIndexOf(".");
    if (dot < 0)
        return "";
    const ext = path.slice(dot + 1).toLowerCase();
    for (const kind in formats)
        if (formats[kind].indexOf(ext) >= 0)
            return kind;
    return "";
}

function fits(aspect, screenAspect, fit) {
    if (!aspect || !screenAspect)
        return true;
    return Math.abs(Math.log(aspect / screenAspect)) <= Math.log(fit);
}

function within(path, folder) {
    if (!folder)
        return false;
    return path.startsWith(folder.replace(/\/*$/, "/"));
}

function reread(state, folder, listed) {
    const missing = state.missing && listed.indexOf(state.missing) >= 0 ? "" : state.missing;
    const want = state.want;
    const shown = !!want && want !== missing && (want === state.verified || state.available.indexOf(want) >= 0);
    const gone = shown && within(want, folder) && listed.indexOf(want) < 0;
    return {
        missing,
        verified: gone ? want : state.verified,
        recheck: gone ? want : ""
    };
}

function strangeOf(wanted, available, aliases, asked) {
    const strange = [];
    for (const path of wanted)
        if (path && available.indexOf(path) < 0 && !aliases[path] && !asked[path] && strange.indexOf(path) < 0)
            strange.push(path);
    return strange;
}

function resolved(strange, listed, text) {
    const lines = String(text ?? "").trim().split("\n");
    if (lines.length !== strange.length + listed.length)
        return null;
    const home = {};
    for (let i = 0; i < listed.length; i++)
        home[lines[strange.length + i]] = listed[i];
    const found = {};
    for (let i = 0; i < strange.length; i++)
        if (home[lines[i]])
            found[strange[i]] = home[lines[i]];
    return found;
}

function repairs(batch, aliases, current, perScreen, home, shipped) {
    const pairs = [];
    const now = expand(current, home, shipped);
    if (batch.indexOf(now) >= 0 && aliases[now])
        pairs.push(["wallpaper.current", aliases[now]]);
    const next = Object.assign({}, perScreen);
    let moved = false;
    for (const screen in perScreen) {
        const path = expand(perScreen[screen], home, shipped);
        if (batch.indexOf(path) >= 0 && aliases[path]) {
            next[screen] = aliases[path];
            moved = true;
        }
    }
    if (moved)
        pairs.push(["wallpaper.perScreen", next]);
    return pairs;
}
