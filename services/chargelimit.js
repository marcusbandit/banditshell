function parseProbe(text) {
    const body = String(text ?? "");
    const threshold = /^threshold (\d*)$/m.exec(body);
    const current = threshold && threshold[1] !== "" ? Number(threshold[1]) : -1;
    return {
        supported: !!threshold,
        current,
        helper: /^helper$/m.test(body)
    };
}

function wanted(holdCharge, holdAt) {
    return holdCharge ? Math.max(50, Math.min(100, Math.round(holdAt))) : 100;
}

function shouldWrite(state) {
    if (!state.supported || !state.helper || state.writing || state.current < 0)
        return false;
    if (state.current === state.wanted)
        return false;
    return !(state.refused && state.refused.wanted === state.wanted && state.refused.got === state.current);
}

function trouble(state, installCommand) {
    if (!state.probed)
        return "";
    if (!state.supported)
        return "this battery has no charge limit in its firmware";
    if (!state.helper)
        return `needs the helper · run ${installCommand}`;
    const stuck = state.refused && state.refused.wanted === state.wanted && state.refused.got === state.current;
    if (stuck && state.refused.failed)
        return "the helper was refused · check polkit is running";
    if (stuck)
        return `the firmware kept it at ${state.current}%`;
    return "";
}
