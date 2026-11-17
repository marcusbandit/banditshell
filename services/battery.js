const nearlyEmptyFraction = 0.05;
const rearmMargin = 0.05;
const graceSeconds = 30;

function actionable(action) {
    return action === "suspend" || action === "hibernate";
}

function lowStep(stage, input) {
    const next = { stage, say: "" };
    if (!input.reading)
        return next;

    if (input.percentage > input.warnAt + rearmMargin) {
        next.stage = "ok";
        return next;
    }

    if (!input.onBattery) {
        if (stage === "counting" || stage === "acted" || stage === "resumed")
            next.stage = "warned";
        return next;
    }

    if (stage === "acted")
        return next;

    if (stage === "resumed") {
        next.stage = "warned";
        if (input.percentage <= input.warnAt)
            next.say = "warn";
        return next;
    }

    if (actionable(input.action) && input.percentage <= nearlyEmptyFraction) {
        if (stage === "ok" || stage === "warned") {
            next.stage = "counting";
            next.say = "countdown";
        }
        return next;
    }

    if (stage === "counting") {
        next.stage = "warned";
        return next;
    }

    if (input.percentage <= input.warnAt && stage === "ok") {
        next.stage = "warned";
        next.say = "warn";
    }
    return next;
}

function countdownMessage(action, seconds) {
    const verb = action === "hibernate" ? "Hibernating" : "Sleeping";
    return `${verb} in ${seconds} seconds unless you plug in.`;
}

function nearlyEmptyChoice(action) {
    return action === "suspend" ? "sleep" : action;
}

function nearlyEmptyAction(choice) {
    const word = String(choice).split(" ")[0];
    return word === "sleep" ? "suspend" : word;
}

function afterResume(stage) {
    return stage === "acted" ? "resumed" : stage;
}

function phaseOf(state, onBattery) {
    if (state === "charging" || state === "full")
        return state;
    if (onBattery || state === "discharging")
        return "battery";
    return state === "pendingCharge" ? "held" : "plugged";
}

function stateText(phase, heldAt) {
    switch (phase) {
    case "charging":
        return "charging";
    case "full":
        return "full";
    case "battery":
        return "on battery";
    case "held":
        return heldAt > 0 ? `plugged in, held at ${heldAt}%` : "not charging";
    default:
        return "plugged in";
    }
}

function noteText(phase, heldAt) {
    switch (phase) {
    case "full":
        return "fully charged";
    case "held":
        return heldAt > 0 ? "not charging" : "plugged in";
    case "plugged":
        return "not charging";
    default:
        return "";
    }
}

function timeText(phase, seconds) {
    if (phase !== "charging" && phase !== "battery")
        return "";
    if (!(seconds > 0))
        return "estimating";
    const mins = Math.round(seconds / 60);
    const h = Math.floor(mins / 60);
    const m = mins % 60;
    const left = h > 0 ? `${h}h ${m}m` : `${m}m`;
    return phase === "charging" ? `${left} to full` : `${left} left`;
}

function flow(rate, phase) {
    const r = Number(rate);
    if (!(Math.abs(r) >= 0.05))
        return "idle";
    if (phase === "charging")
        return "in";
    if (phase === "battery")
        return "out";
    return r > 0 ? "in" : "out";
}

function percentOf(fraction) {
    const f = Number(fraction);
    return Math.round((isFinite(f) ? Math.max(0, Math.min(1, f)) : 0) * 100);
}
