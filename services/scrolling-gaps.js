.pragma library

const FIRST_UNEVEN = [0, 57, 0];

const OPTIONS = [
    { name: "general:layout", key: "layout" },
    { name: "scrolling:direction", key: "direction" },
    { name: "general:gaps_in", key: "gapsIn", sides: true },
    { name: "general:gaps_out", key: "gapsOut", sides: true }
];

function batch() {
    return OPTIONS.map(option => `getoption ${option.name}`).join(" ; ");
}

function sides(answer) {
    const raw = answer.css ?? answer.custom ?? answer.int ?? answer.float;
    if (raw === undefined)
        return null;
    const values = String(raw).trim().split(/[\s,]+/).map(Number);
    const four = values.length === 1 ? [values[0], values[0], values[0], values[0]] : values;
    if (four.length !== 4 || !four.every(Number.isFinite))
        return null;
    return { top: four[0], right: four[1], bottom: four[2], left: four[3] };
}

function readOptions(text) {
    const answers = {};
    for (const line of String(text ?? "").split("\n")) {
        if (!line.trim().startsWith("{"))
            continue;
        try {
            const answer = JSON.parse(line);
            answers[answer?.option] = answer;
        } catch (e) {}
    }
    const out = {};
    for (const option of OPTIONS) {
        const answer = answers[option.name];
        out[option.key] = !answer ? null : option.sides ? sides(answer) : typeof answer.str === "string" ? answer.str : null;
    }
    return out;
}

function readVersion(text) {
    let info = null;
    try {
        info = JSON.parse(String(text ?? ""));
    } catch (e) {
        return null;
    }
    const match = /(\d+)\.(\d+)\.(\d+)/.exec(String(info?.version ?? info?.tag ?? ""));
    return match ? [Number(match[1]), Number(match[2]), Number(match[3])] : null;
}

function atLeast(version, floor) {
    for (let i = 0; i < floor.length; i++)
        if (version[i] !== floor[i])
            return version[i] > floor[i];
    return true;
}

const SIDES = ["top", "right", "bottom", "left"];

function even(gaps) {
    return SIDES.every(side => gaps[side] === gaps.top);
}

function same(a, b) {
    return !!a && !!b && SIDES.every(side => a[side] === b[side]);
}

function additions(state) {
    const add = { top: 0, right: 0, bottom: 0, left: 0 };
    if (state.layout !== "scrolling" || !atLeast(state.version, FIRST_UNEVEN))
        return add;
    const vertical = state.direction === "up" || state.direction === "down";
    for (const side of vertical ? ["top", "bottom"] : ["left", "right"])
        add[side] = state.gapsIn[side];
    return add;
}

function check(state) {
    const outer = state?.gapsOut;
    if (!state?.version || !state.gapsIn || !outer)
        return null;
    const ours = same(outer, state.fix) && Number.isFinite(state.fix.even);
    if (!even(outer) && !ours)
        return null;
    const add = additions(state);
    const edges = {};
    for (const side of SIDES)
        edges[side] = outer[side] + add[side];
    if (even(edges))
        return null;
    const intended = ours ? state.fix.even : outer.top;
    const sides = {};
    for (const side of SIDES)
        sides[side] = intended - add[side];
    if (SIDES.some(side => sides[side] < 0))
        return null;
    return {
        edges,
        intended,
        want: SIDES.some(side => add[side] > 0) ? sides : intended
    };
}

function remembered(found) {
    return found && typeof found.want === "object" ? Object.assign({ even: found.intended }, found.want) : {};
}

function describe(found) {
    if (!found)
        return "";
    const e = found.edges;
    if (e.left === e.right && e.top === e.bottom)
        return `Window gaps: ${e.left}px at the sides, ${e.top}px top and bottom`;
    return `Window gaps: ${e.top}px top, ${e.right}px right, ${e.bottom}px bottom, ${e.left}px left`;
}
