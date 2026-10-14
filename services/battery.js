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
        if (stage === "counting" || stage === "acted")
            next.stage = "warned";
        return next;
    }

    if (stage === "acted")
        return next;

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
    const verb = action === "hibernate" ? "Hibernating" : "Suspending";
    return `${verb} in ${seconds} seconds unless you plug in.`;
}

function afterResume(stage) {
    return stage === "acted" ? "warned" : stage;
}
