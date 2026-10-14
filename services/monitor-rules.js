const MODE_PATTERN = /^(\d+)x(\d+)@([\d.]+)(?:Hz)?$/;
const POSITION_PATTERN = /^-?\d+x-?\d+$/;

function mirrorSource(reported, all) {
    const raw = reported?.mirrorOf;
    if (raw === undefined || raw === null || raw === "" || raw === "none")
        return "";
    const outputs = all ?? [];
    const byId = outputs.find(o => o.id !== undefined && String(o.id) === String(raw));
    if (byId)
        return byId.name;
    return outputs.some(o => o.name === raw) ? String(raw) : "";
}

function restingFields(reported, entry) {
    const known = reported.width > 0 && reported.height > 0;
    const firstAvailable = (reported.availableModes ?? []).map(s => MODE_PATTERN.exec(s)).find(Boolean);
    const entryMode = typeof entry?.mode === "string" ? entry.mode : "";
    return {
        mode: entryMode || (known ? `${reported.width}x${reported.height}@${Math.round(reported.refreshRate)}` : firstAvailable ? `${firstAvailable[1]}x${firstAvailable[2]}@${Math.round(+firstAvailable[3])}` : "preferred"),
        position: POSITION_PATTERN.test(entry?.position) ? entry.position : `${reported.x ?? 0}x${reported.y ?? 0}`,
        scale: entry?.scale > 0 ? entry.scale : reported.scale > 0 ? reported.scale : 1,
        transform: typeof entry?.transform === "number" ? entry.transform : reported.transform ?? 0,
        vrr: entry?.vrr !== undefined ? +entry.vrr : reported.vrr ? 1 : 0
    };
}

function entryFields(spec) {
    return {
        mode: spec.mode,
        position: spec.position,
        scale: spec.scale,
        transform: spec.transform,
        vrr: spec.vrr,
        disabled: spec.disabled ? true : null,
        mirror: spec.disabled || !spec.mirror ? null : spec.mirror
    };
}

function violation(specs) {
    const names = Object.keys(specs);
    if (names.length && names.every(n => specs[n].disabled))
        return "the last screen stays on";
    for (const name of names) {
        const target = specs[name].mirror;
        if (!target || specs[name].disabled)
            continue;
        if (target === name)
            return `${name} cannot mirror itself`;
        if (!specs[target])
            return `${name} cannot mirror ${target}, it is not connected`;
        if (specs[target].disabled)
            return `${name} cannot mirror ${target}, it is off`;
        if (specs[target].mirror)
            return `${name} cannot follow ${target}, it mirrors ${specs[target].mirror}`;
    }
    return "";
}

function mirroring(specs, source) {
    return Object.keys(specs).filter(n => !specs[n].disabled && specs[n].mirror === source);
}

function plan(specs, name, change) {
    const fields = {};
    if (change.disabled === true) {
        fields[name] = { disabled: true, mirror: "" };
        for (const follower of mirroring(specs, name))
            fields[follower] = { mirror: "" };
    } else if (change.disabled === false) {
        fields[name] = { disabled: false };
    } else {
        fields[name] = { mirror: change.mirror ?? "" };
    }
    const after = {};
    for (const n of Object.keys(specs))
        after[n] = Object.assign({}, specs[n], fields[n] ?? {});
    const why = violation(after);
    return { why, fields: why ? {} : fields };
}

function mirrorChoices(specs, name) {
    if (mirroring(specs, name).length)
        return [];
    return Object.keys(specs).filter(n => n !== name && !specs[n].disabled && !specs[n].mirror);
}

function findOutput(outputs, name) {
    return (outputs ?? []).find(o => o.name === name) ?? null;
}

function turnsOn(spec, outputs) {
    const live = findOutput(outputs, spec?.output);
    return !!live && !!live.disabled && !spec.disabled;
}

function turnsOff(spec, outputs) {
    const live = findOutput(outputs, spec?.output);
    return !!live && !live.disabled && !!spec.disabled;
}

function writeOrder(list, outputs) {
    const rank = spec => turnsOn(spec, outputs) ? 0 : turnsOff(spec, outputs) ? 2 : 1;
    return list.map((spec, index) => ({ spec, index, rank: rank(spec) })).sort((a, b) => a.rank - b.rank || a.index - b.index).map(e => e.spec);
}

function dropTurnOffs(queued) {
    const kept = {};
    for (const name of Object.keys(queued ?? {}))
        if (!queued[name].disabled)
            kept[name] = queued[name];
    return kept;
}

function guardSpecs(outputs, intents, list) {
    const specs = {};
    for (const live of outputs ?? []) {
        const intent = intents?.[live.name] ?? {};
        specs[live.name] = Object.assign({}, intent, { disabled: !!live.disabled || !!intent.disabled });
    }
    for (const spec of list ?? [])
        if (spec?.output && specs[spec.output])
            specs[spec.output] = spec;
    return specs;
}
