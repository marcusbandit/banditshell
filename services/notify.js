const CATEGORY_PREFIX = "x-banditshell.";

function categoryFor(kind) {
    return `${CATEGORY_PREFIX}${kind}`;
}

function kindOf(category) {
    const text = category ?? "";
    return text.startsWith(CATEGORY_PREFIX) ? text.slice(CATEGORY_PREFIX.length) : "";
}

function commandFor(spec) {
    return ["notify-send", "-a", "banditshell", "-u", spec.urgency ?? "normal", "-c", categoryFor(spec.kind), spec.summary, spec.body ?? ""];
}
