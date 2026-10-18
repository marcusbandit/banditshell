const SIZE_CAP = 262144;
const TEXT_MAX = 200;

const OPEN_PARTS = {
    launcher: "launcher",
    session: "session",
    clipboard: "clipboard",
    media: "media",
    calculator: "calculator",
    keyboard: "keyboard",
    settings: "settings",
    hotkeys: "hotkeys",
    wallpapers: "wallpaper"
};

const PINNED_PARTS = {
    quickControls: "quickcontrols",
    notifications: "notifications",
    island: "island"
};

const WRITER_SCRIPT = 'umask 077; dir=${XDG_RUNTIME_DIR:-/tmp}/banditshell; mkdir -p "$dir" || exit 1; file=$dir/events.jsonl; cap=${1:-' + SIZE_CAP + '}; size=0; [ ! -f "$file" ] || size=$(wc -c <"$file"); if [ "$size" -gt "$cap" ]; then mv -f "$file" "$file.1"; size=0; fi; while IFS= read -r line; do printf \'%s\\n\' "$line" >>"$file"; size=$((size + ${#line} + 1)); if [ "$size" -gt "$cap" ]; then mv -f "$file" "$file.1"; size=0; fi; done';

function clip(value) {
    const text = String(value === undefined || value === null ? "" : value).replace(/\s+/g, " ").trim();
    return text.length > TEXT_MAX ? text.slice(0, TEXT_MAX) : text;
}

function panelKey(panel, screen) {
    return `${panel}@${screen}`;
}

function panelsOf(windows, extras) {
    const out = {};
    const add = (panel, screen) => {
        out[panelKey(panel, screen)] = { panel: panel, screen: screen };
    };
    for (const win of windows ?? []) {
        const screen = win?.screen?.name ?? "";
        for (const part of Object.keys(OPEN_PARTS))
            if (win?.[part]?.open)
                add(OPEN_PARTS[part], screen);
        for (const part of Object.keys(PINNED_PARTS))
            if (win?.[part]?.pinned)
                add(PINNED_PARTS[part], screen);
        const menu = win?.menus?.currentKey;
        if (menu)
            add(menu, screen);
    }
    for (const name of extras ?? [])
        add(name, "");
    return out;
}

function activitiesOf(entries) {
    const out = {};
    for (const e of entries ?? []) {
        if (!e || !e.id)
            continue;
        out[e.id] = {
            text: clip(e.text),
            state: e.state === "ended" ? "ended" : "running",
            outcome: String(e.outcome ?? ""),
            progress: typeof e.progress === "number" ? e.progress : -1,
            touched: e.touched ?? 0
        };
    }
    return out;
}

function notificationsOf(history) {
    const out = {};
    for (const e of history ?? []) {
        if (!e || !e.id || (e.leaving && e.forget))
            continue;
        out[e.id] = { app: clip(e.appName), summary: clip(e.summary) };
    }
    return out;
}

function snapshotOf(input) {
    const media = input.media ?? {};
    const update = input.update ?? {};
    return {
        workspace: input.workspace ?? 0,
        panels: panelsOf(input.windows, input.extraPanels),
        mode: String(input.mode ?? "none"),
        quiet: !!input.quiet,
        media: {
            title: clip(media.title),
            artist: clip(media.artist),
            app: clip(media.app),
            playing: !!media.playing
        },
        activities: activitiesOf(input.activities),
        notifications: notificationsOf(input.notifications),
        update: { state: String(update.state ?? ""), behind: update.behind ?? 0 }
    };
}

function keysOf(map) {
    return Object.keys(map ?? {}).sort();
}

function diff(before, after, options) {
    if (!before || !after)
        return [];
    const withText = !!options?.notificationText;
    const out = [];
    if (before.workspace !== after.workspace)
        out.push({ event: "workspace.changed", workspace: after.workspace, previous: before.workspace });
    for (const key of keysOf(after.panels))
        if (!before.panels[key])
            out.push({ event: "panel.opened", panel: after.panels[key].panel, screen: after.panels[key].screen });
    for (const key of keysOf(before.panels))
        if (!after.panels[key])
            out.push({ event: "panel.closed", panel: before.panels[key].panel, screen: before.panels[key].screen });
    if (before.mode !== after.mode)
        out.push({ event: "mode.changed", mode: after.mode, previous: before.mode });
    if (before.quiet !== after.quiet)
        out.push({ event: "quiet.changed", quiet: after.quiet });
    const a = before.media;
    const b = after.media;
    if (b.title && (a.title !== b.title || a.artist !== b.artist || a.app !== b.app))
        out.push({ event: "media.track", title: b.title, artist: b.artist, app: b.app, playing: b.playing });
    if (a.playing !== b.playing)
        out.push({ event: "media.state", playing: b.playing, app: b.app });
    for (const id of keysOf(after.activities)) {
        const now = after.activities[id];
        const was = before.activities[id];
        if (!was)
            out.push({ event: "activity.pushed", id: id, text: now.text });
        else if (now.state === "ended" && was.state !== "ended")
            out.push({ event: "activity.ended", id: id, text: now.text, outcome: now.outcome });
        else if (now.state !== "ended" && (was.touched !== now.touched || was.state === "ended"))
            out.push({ event: "activity.updated", id: id, text: now.text, progress: now.progress });
    }
    for (const id of keysOf(before.activities))
        if (!after.activities[id] && before.activities[id].state !== "ended")
            out.push({ event: "activity.ended", id: id, text: before.activities[id].text, outcome: "removed" });
    for (const id of keysOf(after.notifications))
        if (!before.notifications[id]) {
            const item = { event: "notification.arrived", id: id, app: after.notifications[id].app };
            if (withText)
                item.summary = after.notifications[id].summary;
            out.push(item);
        }
    for (const id of keysOf(before.notifications))
        if (!after.notifications[id])
            out.push({ event: "notification.dismissed", id: id, app: before.notifications[id].app });
    if (before.update.state !== after.update.state || before.update.behind !== after.update.behind)
        out.push({ event: "update.changed", state: after.update.state, behind: after.update.behind });
    return out;
}

function line(event, now) {
    const shaped = { event: event.event, time: now };
    for (const key of Object.keys(event))
        if (key !== "event")
            shaped[key] = event[key];
    return JSON.stringify(shaped) + "\n";
}

function wanted(filter, name) {
    const items = String(filter ?? "").split(",").map(s => s.trim()).filter(s => s);
    if (items.length === 0)
        return true;
    return items.some(item => name === item || name.startsWith(item + "."));
}
