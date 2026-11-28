const SECTIONS = [
    { key: "messages", title: "Messages" },
    { key: "apps", title: "Apps" },
    { key: "silent", title: "Silent" }
];

const LOW = 0;

const CHATS = /^(discord|vesktop|webcord|legcord|armcord|signal|telegram|whatsapp|zapzap|slack|element|fractal|nheko|teams|messenger|caprine|beeper|ferdium|session|wire|threema|dino|gajim|kdeconnect|chatterino)\b/i;

function sectionOf(entry) {
    if (!entry)
        return "apps";
    if (entry.urgency === LOW)
        return "silent";
    if (/^im(\.|$)/.test(String(entry.category || "")))
        return "messages";
    if (entry.canReply)
        return "messages";
    const names = [entry.appName, entry.desktopEntry, entry.appId].map(n => String(n || "").split(".").pop());
    return names.some(n => CHATS.test(n)) ? "messages" : "apps";
}

function split(groups, extraSilent) {
    const filled = { messages: [], apps: [], silent: [] };
    for (const group of groups || []) {
        const head = (group.entries || []).find(e => !e.leaving) || group.entries[0];
        filled[sectionOf(head)].push(group);
    }
    return SECTIONS.filter(s => filled[s.key].length > 0 || (s.key === "silent" && extraSilent > 0)).map(s => ({ key: s.key, title: s.title, groups: filled[s.key] }));
}

function newest(groups) {
    let best = null;
    for (const group of groups || [])
        for (const entry of group.entries || [])
            if (!entry.leaving && (!best || (entry.time || 0) > (best.time || 0)))
                best = entry;
    return best;
}

function seen(top, height, viewTop, viewBottom) {
    if (height <= 0)
        return 1;
    return Math.max(0, Math.min(1, (viewBottom - top) / height));
}
