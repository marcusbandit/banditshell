.pragma library

function recordText(session, told) {
    return JSON.stringify({ session: session, told: told }) + "\n";
}

function readRecord(text, session) {
    try {
        const data = JSON.parse(text);
        if (session && data?.session === session && typeof data.told === "boolean")
            return data.told;
    } catch (e) {
    }
    return null;
}

function onStart(hint, told, lockUp) {
    if (hint !== true || lockUp)
        return "leave";
    return told === false ? "clear" : "relock";
}
