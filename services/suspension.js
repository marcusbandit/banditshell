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

function logindCommand(verb) {
    return ["sh", "-c", 'if [ -d /run/systemd/system ]; then exec systemctl "$1"; fi; exec loginctl "$1"', "sh", verb];
}

function logoutCommand(seats) {
    return ["sh", "-c", 'if [ -d "$1" ]; then session="${XDG_SESSION_ID:-$(loginctl show-user "$(id -u)" -p Display --value)}"; [ -n "$session" ] || exit 1; exec loginctl terminate-session "$session"; fi; [ "$(hyprctl dispatch "hl.dsp.exit()")" = ok ] || exec hyprctl dispatch exit', "sh", seats ?? "/run/systemd/seats"];
}

function commandFor(action) {
    if (action === "suspend" || action === "hibernate")
        return logindCommand(action);
    return [];
}
