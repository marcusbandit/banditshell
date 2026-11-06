const CATEGORY_PREFIX = "x-banditshell.";

function categoryFor(kind) {
    return `${CATEGORY_PREFIX}${kind}`;
}

function kindOf(category) {
    const text = category ?? "";
    return text.startsWith(CATEGORY_PREFIX) ? text.slice(CATEGORY_PREFIX.length) : "";
}

function commandFor(spec) {
    const category = spec.kind ? ["-c", categoryFor(spec.kind)] : [];
    return ["notify-send", "-a", "banditshell", "-u", spec.urgency ?? "normal", ...category, "--", String(spec.summary ?? ""), String(spec.body ?? "")];
}
