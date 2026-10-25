const ACTIVE_MAX = 12;
const LINGER_MS = 2500;
const SPAN_MAX_MS = 7 * 24 * 60 * 60 * 1000;
const TEXT_MAX = 120;
const DETAIL_MAX = 200;
const ENDING_MS = 10000;
const LEVEL_MS = 1000;
const OUTCOMES = ["done", "failed", "cancelled"];
const KINDS = ["external", "privacy"];
const STYLES = ["", "screenshot", "copied", "bluetooth", "wifi", "privacy"];
const ACTIONS_MAX = 4;
const ACTION_LABEL_MAX = 12;
const LEVEL_KINDS = ["volume", "brightness", "mic"];
const ID_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._:-]{0,63}$/;
const SPAN_PIECE = /(\d+(?:\.\d+)?)(ms|h|m|s)/g;
const SPAN_UNITS = { ms: 1, s: 1000, m: 60000, h: 3600000 };

function parseSpan(text) {
    if (typeof text === "number")
        return isFinite(text) && text >= 0 && text <= SPAN_MAX_MS ? Math.round(text) : -1;
    const raw = String(text === undefined || text === null ? "" : text).trim().toLowerCase();
    if (raw === "")
        return 0;
    if (/^\d+(\.\d+)?$/.test(raw))
        return parseSpan(Number(raw) * 1000);
    SPAN_PIECE.lastIndex = 0;
    let total = 0;
    let covered = 0;
    let piece = SPAN_PIECE.exec(raw);
    while (piece) {
        total += Number(piece[1]) * SPAN_UNITS[piece[2]];
        covered += piece[0].length;
        piece = SPAN_PIECE.exec(raw);
    }
    return covered === raw.length ? parseSpan(total) : -1;
}

function readProgress(value) {
    if (value === undefined || value === null || value === "")
        return { unset: true };
    if (String(value).trim().toLowerCase() === "unknown")
        return { value: -1 };
    const number = typeof value === "number" ? value : Number(String(value).trim());
    if (!isFinite(number))
        return { error: `progress is a number from 0 to 1, or -1 when unknown: ${value}` };
    return { value: number < 0 ? -1 : Math.min(1, number) };
}

function readText(value, max, name) {
    const text = String(value === undefined || value === null ? "" : value).replace(/\s+/g, " ").trim();
    if (text.length > max)
        return { error: `${name} is longer than ${max} characters` };
    return { value: text };
}

function readPriority(value) {
    if (value === undefined || value === null || value === "")
        return { unset: true };
    const number = Number(value);
    if (!isFinite(number))
        return { error: `priority is a whole number: ${value}` };
    return { value: Math.max(-100, Math.min(100, Math.round(number))) };
}

function readActions(value) {
    if (value === undefined || value === null)
        return { value: [] };
    if (!Array.isArray(value) || value.length > ACTIONS_MAX)
        return { error: `actions are a list of at most ${ACTIONS_MAX}` };
    const out = [];
    for (const a of value) {
        const name = String(a && a.name !== undefined ? a.name : "");
        const label = String(a && a.label !== undefined ? a.label : "");
        if (name === "" || label === "" || label.length > ACTION_LABEL_MAX)
            return { error: `an action is a name and a label of up to ${ACTION_LABEL_MAX} characters` };
        out.push({ name: name, label: label });
    }
    return { value: out };
}

function made(spec, now) {
    const source = spec || {};
    const id = String(source.id === undefined || source.id === null ? "" : source.id);
    if (!ID_PATTERN.test(id))
        return { error: "id is 1 to 64 letters, digits, dot, dash, colon or underscore" };
    const kind = source.kind === undefined || source.kind === "" ? "external" : source.kind;
    if (!KINDS.includes(kind))
        return { error: `kind is one of ${KINDS.join(", ")}` };
    const text = readText(source.text, TEXT_MAX, "text");
    if (text.error)
        return text;
    if (text.value === "")
        return { error: "text is needed" };
    const detail = readText(source.detail, DETAIL_MAX, "detail");
    if (detail.error)
        return detail;
    const progress = readProgress(source.progress);
    if (progress.error)
        return progress;
    const priority = readPriority(source.priority);
    if (priority.error)
        return priority;
    const span = parseSpan(source.until);
    if (span < 0)
        return { error: `until is a span like 30s, 2m or 1h30m, up to 7 days: ${source.until}` };
    const style = source.style === undefined || source.style === null ? "" : source.style;
    if (!STYLES.includes(style))
        return { error: `style is one of ${STYLES.filter(s => s !== "").join(", ")}` };
    const actions = readActions(source.actions);
    if (actions.error)
        return actions;
    return {
        entry: {
            id: id,
            kind: kind,
            text: text.value,
            detail: detail.value,
            progress: progress.unset ? -1 : progress.value,
            icon: String(source.icon || ""),
            mark: String(source.mark || ""),
            priority: priority.unset ? 0 : priority.value,
            until: span,
            deadline: span > 0 ? now + span : 0,
            act: source.act || null,
            style: style,
            data: source.data || null,
            actions: actions.value,
            pressable: !!source.pressable,
            source: String(source.source || ""),
            state: "running",
            outcome: "",
            outcomeUntil: 0,
            born: now,
            touched: now
        }
    };
}

function evict(list) {
    if (list.length <= ACTIVE_MAX)
        return list;
    const ended = list.filter(e => e.state === "ended").sort((a, b) => a.touched - b.touched);
    if (ended.length > 0)
        return evict(list.filter(e => e !== ended[0]));
    const weakest = list.slice().sort((a, b) => a.priority - b.priority || a.touched - b.touched)[0];
    return evict(list.filter(e => e !== weakest));
}

function push(list, spec, now) {
    const result = made(spec, now);
    if (result.error)
        return { list: list, error: result.error };
    const before = list.find(e => e.id === result.entry.id);
    const entry = before ? Object.assign(result.entry, { born: before.born }) : result.entry;
    return { list: evict(list.filter(e => e.id !== entry.id).concat([entry])), entry: entry };
}

function update(list, id, patch, now) {
    const before = list.find(e => e.id === id);
    if (!before)
        return { list: list, error: `no activity ${id}` };
    if (before.state === "ended")
        return { list: list, error: `${id} has already ended` };
    const given = patch || {};
    const next = Object.assign({}, before, { touched: now });
    if (given.text !== undefined && given.text !== "") {
        const text = readText(given.text, TEXT_MAX, "text");
        if (text.error)
            return { list: list, error: text.error };
        if (text.value !== "")
            next.text = text.value;
    }
    if (given.detail !== undefined && given.detail !== null) {
        const detail = readText(given.detail, DETAIL_MAX, "detail");
        if (detail.error)
            return { list: list, error: detail.error };
        next.detail = detail.value;
    }
    const progress = readProgress(given.progress);
    if (progress.error)
        return { list: list, error: progress.error };
    if (!progress.unset)
        next.progress = progress.value;
    const priority = readPriority(given.priority);
    if (priority.error)
        return { list: list, error: priority.error };
    if (!priority.unset)
        next.priority = priority.value;
    if (given.icon !== undefined && given.icon !== "")
        next.icon = String(given.icon);
    if (given.mark !== undefined && given.mark !== "")
        next.mark = String(given.mark);
    if (given.act)
        next.act = given.act;
    if (given.data)
        next.data = given.data;
    if (given.until !== undefined && given.until !== "") {
        const span = parseSpan(given.until);
        if (span < 0)
            return { list: list, error: `until is a span like 30s, 2m or 1h30m, up to 7 days: ${given.until}` };
        next.until = span;
        next.deadline = span > 0 ? now + span : 0;
    }
    return { list: list.map(e => e === before ? next : e), entry: next };
}

function end(list, id, outcome, now, lingerMs) {
    const before = list.find(e => e.id === id);
    if (!before)
        return { list: list, error: `no activity ${id}` };
    const named = outcome === undefined || outcome === null || outcome === "" ? "done" : String(outcome);
    if (!OUTCOMES.includes(named))
        return { list: list, error: `outcome is one of ${OUTCOMES.join(", ")}: ${outcome}` };
    const stay = lingerMs === undefined ? LINGER_MS : lingerMs;
    const next = Object.assign({}, before, {
        state: "ended",
        outcome: named,
        progress: named === "done" ? 1 : before.progress,
        outcomeUntil: now + stay,
        deadline: 0,
        touched: now
    });
    return { list: list.map(e => e === before ? next : e), entry: next };
}

function remove(list, id) {
    return list.filter(e => e.id !== id);
}

function sweep(list, now) {
    const kept = list.filter(e => e.state === "ended" ? e.outcomeUntil > now : e.deadline === 0 || e.deadline > now);
    return kept.length === list.length ? list : kept;
}

function nextWake(list, now) {
    let soonest = -1;
    for (const e of list) {
        const due = e.state === "ended" ? e.outcomeUntil : e.deadline;
        if (due > 0 && (soonest < 0 || due < soonest))
            soonest = due;
    }
    return soonest < 0 ? -1 : Math.max(0, soonest - now);
}

function ordered(list) {
    return list.slice().sort((a, b) => b.priority - a.priority || b.born - a.born || (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));
}

function itemOf(entry) {
    return {
        key: `${entry.kind}:${entry.id}`,
        id: entry.id,
        kind: entry.kind,
        text: entry.text,
        detail: entry.detail,
        progress: entry.progress,
        icon: entry.icon,
        mark: entry.mark,
        state: entry.state,
        outcome: entry.outcome,
        priority: entry.priority,
        pressable: !!(entry.act || entry.pressable),
        style: entry.style,
        data: entry.data,
        actions: entry.actions,
        source: entry.source
    };
}

function listLine(entry, now) {
    const progress = entry.progress >= 0 ? `${Math.round(entry.progress * 100)}%` : "-";
    const state = entry.state === "ended" ? entry.outcome : "running";
    const left = entry.state !== "ended" && entry.deadline > 0 ? `${Math.ceil((entry.deadline - now) / 1000)}s left` : "";
    return [entry.id, state, progress, entry.text, left].filter(part => part !== "").join("\t");
}

function pad2(n) {
    return n < 10 ? `0${n}` : `${n}`;
}

function clockText(ms) {
    const total = Math.max(0, Math.ceil(ms / 1000));
    const h = Math.floor(total / 3600);
    const m = Math.floor((total % 3600) / 60);
    const s = total % 60;
    return h > 0 ? `${h}:${pad2(m)}:${pad2(s)}` : `${m}:${pad2(s)}`;
}

function clockSample(totalMs) {
    return totalMs >= 3600000 ? "0:00:00" : "00:00";
}

function timerRemaining(timer, now) {
    if (!timer)
        return 0;
    return timer.paused ? timer.left : Math.max(0, timer.deadline - now);
}

function timerItem(timer, now, endingMs) {
    const remaining = timerRemaining(timer, now);
    const near = endingMs === undefined ? ENDING_MS : endingMs;
    return {
        key: `timer:${timer.id}`,
        id: timer.id,
        kind: "timer",
        text: timer.label || "Timer",
        remaining: remaining,
        clock: clockText(remaining),
        sample: clockSample(timer.total),
        progress: timer.total > 0 ? Math.max(0, Math.min(1, remaining / timer.total)) : 0,
        paused: !!timer.paused,
        ending: !timer.paused && remaining <= near
    };
}

function timerItems(timers, now, endingMs) {
    return (timers || []).filter(t => !t.finished && !t.quiet).map(t => timerItem(t, now, endingMs)).sort((a, b) => a.remaining - b.remaining);
}

function alarmItem(id, title, actions) {
    return {
        key: `alarm:${id}`,
        id: id,
        kind: "alarm",
        text: title,
        actions: actions
    };
}

function alarmActions(snoozeable) {
    return snoozeable ? [{ name: "snooze", label: "Snooze" }, { name: "stop", label: "Stop" }] : [{ name: "stop", label: "Stop" }];
}

function levelIcon(kind, value, muted) {
    if (kind === "mic")
        return muted ? "mic_off" : "mic";
    if (kind === "brightness")
        return value < 1 / 3 ? "brightness_low" : value < 2 / 3 ? "brightness_medium" : "brightness_high";
    if (muted || value <= 0)
        return "volume_off";
    return value < 1 / 3 ? "volume_mute" : value < 2 / 3 ? "volume_down" : "volume_up";
}

function levelMoment(kind, value, muted, max) {
    if (!LEVEL_KINDS.includes(kind))
        return null;
    const top = max > 0 ? max : 1;
    const fraction = Math.max(0, Math.min(1, value / top));
    const base = { key: `level:${kind}`, kind: "level", level: kind, muted: !!muted, ms: LEVEL_MS };
    if (kind === "mic")
        return Object.assign(base, { icon: levelIcon(kind, fraction, muted), text: muted ? "Mic muted" : "Mic on", meter: -1, readout: "" });
    const name = kind === "volume" ? "Volume" : "Brightness";
    return Object.assign(base, {
        icon: levelIcon(kind, fraction, muted),
        text: muted ? `${name} muted` : name,
        meter: muted ? 0 : fraction,
        readout: muted ? "" : `${Math.round(value * 100)}%`
    });
}

function levelDiffers(kind, before, after) {
    if (!before || !after)
        return false;
    if (!!before.muted !== !!after.muted)
        return true;
    if (kind === "mic")
        return false;
    return Math.abs(before.value - after.value) >= 0.005;
}

function coveredKinds(covers) {
    const out = [];
    for (const c of covers || [])
        for (const k of c.kinds || [])
            if (!out.includes(k))
                out.push(k);
    return out;
}

function levelWanted(enabled, covers, kind) {
    return !!enabled && !coveredKinds(covers).includes(kind);
}
