function parseProbe(text) {
    const body = String(text ?? "");
    const threshold = /^threshold (\d*)$/m.exec(body);
    const current = threshold && threshold[1] !== "" ? Number(threshold[1]) : -1;
    const helper = /^helper(?: (\S+))?$/m.exec(body);
    return {
        supported: !!threshold,
        current,
        helper: !!helper,
        helperPath: helper && helper[1] ? helper[1] : "",
        nixos: /^nixos$/m.test(body)
    };
}

function wanted(holdCharge, holdAt) {
    return holdCharge ? Math.max(50, Math.min(100, Math.round(holdAt))) : 100;
}

function held(state) {
    return !!state.refused && state.refused.wanted === state.wanted && state.refused.got === state.current;
}

function shouldWrite(state) {
    if (!state.owed || !state.supported || !state.helper || state.writing || state.current < 0)
        return false;
    if (state.current === state.wanted)
        return false;
    return !held(state);
}

function elsewhere(state) {
    return state.hold && state.probed && state.supported && state.helper && !state.owed && !state.writing && state.current >= 0 && state.current !== state.wanted && !held(state);
}

function trouble(state, installCommand) {
    if (!state.probed)
        return "";
    if (!state.supported)
        return "this battery has no charge limit in its firmware";
    if (!state.helper && state.nixos)
        return "needs the helper · import nix/charge-limit.nix in your NixOS config";
    if (!state.helper)
        return `needs the helper · run ${installCommand}`;
    if (held(state) && state.refused.failed)
        return "the helper was refused · check polkit is running";
    if (held(state))
        return `the firmware kept it at ${state.current}%`;
    if (elsewhere(state))
        return `something else set it to ${state.current}%`;
    return "";
}
