.pragma library

function parseEvent(line) {
    let event = null;
    try {
        event = JSON.parse(line);
    } catch (e) {
        return null;
    }
    return event && typeof event === "object" && typeof event.event === "string" ? event : null;
}

function who(ask) {
    return ask.name || ask.address || "the device";
}

function describe(ask) {
    if (!ask)
        return null;
    const name = who(ask);
    switch (ask.kind) {
    case "confirm":
        return { title: `Pair with ${name}?`, detail: "Check that the same code shows on it", code: ask.code, field: "", yes: "Pair", no: "Cancel" };
    case "authorize":
        return { title: `${name} wants to pair`, detail: "", code: "", field: "", yes: "Allow", no: "Refuse" };
    case "passkey":
        return { title: `Enter the code shown on ${name}`, detail: "", code: "", field: "code", yes: "Pair", no: "Cancel" };
    case "pin":
        return { title: `Enter the PIN for ${name}`, detail: "Try 0000 if it has none", code: "", field: "PIN", yes: "Pair", no: "Cancel" };
    }
    return null;
}

function describeShown(shown) {
    if (!shown)
        return null;
    const name = who(shown);
    const left = Math.max(0, (shown.code || "").length - (shown.entered || 0));
    return { title: `Type this on ${name}`, detail: left > 0 ? "then press Enter" : "now press Enter", code: shown.code || "" };
}

function answerFor(ask, accept, text) {
    if (!ask)
        return null;
    const code = String(text || "").trim();
    if (accept && ask.kind === "passkey" && !/^[0-9]{1,6}$/.test(code))
        return null;
    if (accept && ask.kind === "pin" && !code)
        return null;
    const typed = ask.kind === "passkey" || ask.kind === "pin";
    return { id: ask.id, accept: !!accept, code: accept && typed ? code : "" };
}

function failureLabel(kind) {
    return kind === "pair" ? "pairing failed" : "could not connect";
}

function stateLabel(device, failure) {
    if (!device)
        return "";
    if (device.blocked)
        return "blocked";
    if (device.pairing)
        return "pairing";
    if (device.connecting)
        return "connecting";
    if (device.disconnecting)
        return "disconnecting";
    if (device.connected)
        return device.battery >= 0 ? `connected · ${Math.round(device.battery * 100)}%` : "connected";
    if (failure)
        return failure;
    return device.paired ? "not connected" : "not paired";
}
