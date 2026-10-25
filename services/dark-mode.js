.pragma library

const KNOWN = ["default", "prefer-dark", "prefer-light"];

function parse(text) {
    const m = /'([a-z-]+)'/.exec(String(text));
    return m && KNOWN.includes(m[1]) ? m[1] : "";
}

function lightAfter(previous, scheme) {
    return scheme === "default" || scheme === "prefer-light" ? scheme : previous;
}

function schemeFor(dark, light) {
    return dark ? "prefer-dark" : lightAfter("default", light);
}

function afterWrite(code, wanted, before) {
    return code === 0 ? wanted : before;
}
