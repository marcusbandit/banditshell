.pragma library

const OPTIONS = [
    { name: "decoration:rounding", key: "rounding" },
    { name: "decoration:rounding_power", key: "roundingPower" },
    { name: "general:gaps_out", key: "gapsOut" },
    { name: "general:gaps_in", key: "gapsIn" },
    { name: "general:border_size", key: "borderSize" },
    { name: "input:natural_scroll", key: "naturalScrollMouse", flag: true },
    { name: "input:touchpad:natural_scroll", key: "naturalScrollTouchpad", flag: true }
];

function batch() {
    return OPTIONS.map(option => `getoption ${option.name}`).join(" ; ");
}

function answerValue(answer, flag) {
    if (flag)
        return typeof answer.bool === "boolean" ? answer.bool : typeof answer.int === "number" ? answer.int !== 0 : null;
    const many = answer.custom ?? answer.css;
    const value = many !== undefined ? parseFloat(String(many).trim().split(/\s+/)[0]) : answer.float ?? answer.int;
    return typeof value === "number" && isFinite(value) ? value : null;
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
    for (const option of OPTIONS)
        out[option.key] = answers[option.name] ? answerValue(answers[option.name], option.flag) : null;
    return out;
}
