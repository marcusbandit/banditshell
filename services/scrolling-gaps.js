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

function check(state) {
    const version = state?.version;
    const inner = state?.gapsIn;
    const outer = state?.gapsOut;
    if (!version || !atLeast(version, FIRST_UNEVEN) || state.layout !== "scrolling" || !inner || !outer)
        return null;
    const even = outer.top === outer.right && outer.right === outer.bottom && outer.bottom === outer.left;
    if (!even)
        return null;
    const vertical = state.direction === "up" || state.direction === "down";
    const ends = vertical ? ["top", "bottom"] : ["left", "right"];
    if (ends.every(side => inner[side] <= 0) || ends.some(side => inner[side] > outer[side]))
        return null;
    const want = Object.assign({}, outer);
    for (const side of ends)
        want[side] = outer[side] - inner[side];
    return {
        axis: vertical ? "vertical" : "horizontal",
        edge: outer.top,
        extra: Math.max(...ends.map(side => inner[side])),
        want
    };
}

function describe(found) {
    if (!found)
        return "";
    const ends = found.axis === "vertical" ? ["top and bottom", "sides"] : ["sides", "top and bottom"];
    return `Windows sit ${found.edge + found.extra}px from the frame at the ${ends[0]} and ${found.edge}px at the ${ends[1]}, because Hyprland's scrolling layout adds gaps_in there.`;
}
