function parseHibernate(text) {
    const parts = String(text ?? "").split("---\n");
    const states = (parts[0] ?? "").trim().split(/\s+/);
    if (!states.includes("disk"))
        return false;

    const swaps = (parts[1] ?? "").split("\n").slice(1).filter(line => line.trim() !== "" && !line.includes("/zram"));
    const answer = answerOf(parts[2] ?? "");
    if (answer !== "")
        return answer === "yes" || answer === "challenge";
    return swaps.length > 0;
}

function answerOf(text) {
    try {
        const data = JSON.parse(text)?.data;
        return typeof data?.[0] === "string" ? data[0] : "";
    } catch (e) {
        return "";
    }
}

function resolve(action, hibernatePossible) {
    if (action === "hibernate" && !hibernatePossible)
        return "suspend";
    return action;
}

function commandFor(action) {
    if (action === "suspend" || action === "hibernate")
        return ["sh", "-c", 'if command -v systemctl >/dev/null 2>&1; then exec systemctl "$1"; fi; exec loginctl "$1"', "sh", action];
    return [];
}
