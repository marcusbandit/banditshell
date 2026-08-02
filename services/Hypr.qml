pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config

// Adapter over Quickshell's Hyprland IPC.
//
// Widgets read this, never `Hyprland` directly. All the "how do we know" logic
// (which events force a refresh, id arithmetic, what counts as occupied) lives
// here, so the widgets stay purely visual.
Singleton {
    id: root

    // Workspaces always shown, even when empty.
    readonly property int persistentCount: Appearance.sizes.wsPersistent

    // THE NUMBERED WORKSPACE YOU ARE ON, which is not always the focused one:
    // opening a scratchpad focuses IT, and its id is negative. The workspace
    // underneath has not changed and neither has the answer to "where am I", so
    // the monitor's own active workspace is asked instead, and the focused one
    // is only a fallback for the case where there is no monitor to ask.
    readonly property int activeId: {
        const focused = Hyprland.focusedWorkspace?.id ?? 1;
        if (focused > 0)
            return focused;
        return Hyprland.focusedMonitor?.activeWorkspace?.id ?? 1;
    }

    // { id: windowCount } for every workspace Hyprland currently knows about.
    // Special workspaces have negative ids and are left out.
    readonly property var windows: {
        const out = {};
        for (const ws of Hyprland.workspaces.values)
            if (ws.id > 0)
                out[ws.id] = ws.lastIpcObject?.windows ?? 0;
        return out;
    }

    // How many slots to render. Always enough for the persistent set, the
    // focused workspace, and the highest live one. Derived from the data, never
    // a hardcoded list of slots.
    readonly property int count: Math.max(persistentCount, activeId, ...Object.keys(windows).map(Number))

    // { id: [toplevel, ...] } for every workspace that has any. The indicators
    // draw one icon per entry, so this is the difference between knowing a
    // workspace is busy and knowing what is on it.
    //
    // Ordered by WHERE THE WINDOW IS, left to right, not by when it was opened.
    // The layout scrolls sideways, so left-to-right is the order you move
    // through them; a column of icons in creation order would be a different
    // order every time and mean nothing. Ties go to the higher window, for the
    // ones stacked in the same column.
    readonly property var clients: {
        const out = {};
        for (const c of Hyprland.toplevels.values) {
            // Special workspaces have NEGATIVE ids and belong in here too: the
            // only thing zero means is a window with no workspace at all.
            const id = c.workspace?.id ?? 0;
            if (id !== 0) {
                if (!out[id])
                    out[id] = [];
                out[id].push(c);
            }
        }
        for (const id in out)
            out[id].sort((a, b) => {
                const x = a.lastIpcObject?.at ?? [0, 0];
                const y = b.lastIpcObject?.at ?? [0, 0];
                return (x[0] - y[0]) || (x[1] - y[1]);
            });
        return out;
    }

    function clientsIn(id: int): var {
        return root.clients[id] ?? [];
    }

    // SPECIAL WORKSPACES, which are a different kind of thing and not a numbered
    // slot with a minus sign on it. A scratchpad is not somewhere you go and
    // stay, it is something you pull over whatever you are already doing, and it
    // exists only while something is on it.
    //
    // [{ id, name, label, windows }], in the order Hyprland lists them.
    readonly property var specials: {
        const out = [];
        for (const ws of Hyprland.workspaces.values) {
            if (ws.id >= 0)
                continue;
            const name = ws.lastIpcObject?.name ?? "";
            out.push({
                id: ws.id,
                name,
                // `special:magic` is the wire name; `magic` is what you called it.
                label: name.startsWith("special:") ? name.slice(8) : name,
                windows: root.clients[ws.id] ?? []
            });
        }
        return out;
    }

    // The special workspace currently pulled over the screen, by name, or "".
    // Read off the MONITOR rather than off the workspace list, because the
    // question is not which ones exist, it is which one you are looking at.
    readonly property string openSpecial: {
        for (const mon of Hyprland.monitors.values) {
            const name = mon.lastIpcObject?.specialWorkspace?.name ?? "";
            if (name)
                return name;
        }
        return "";
    }

    function toggleSpecial(name: string): void {
        // The dispatcher wants the bare name, not the `special:` prefix it
        // reports back to us.
        Hyprland.dispatch(`togglespecialworkspace ${name.startsWith("special:") ? name.slice(8) : name}`);
    }

    // The focused window itself, not its address: it is the same object the
    // model hands the delegates, so "is this the focused one" is an identity
    // test rather than string bookkeeping that can go stale.
    readonly property var activeClient: Hyprland.activeToplevel

    // Is this the window with the keyboard?
    //
    // Prefers the address off the event stream, which is right the moment the
    // event lands, and falls back to the model's own idea of it for the case
    // that address cannot cover: before the first focus change of the session
    // there has been no event to read.
    function isFocused(client: var): bool {
        const addr = client?.lastIpcObject?.address ?? "";
        if (!addr)
            return false;
        return root.focusedAddress ? root.focusedAddress === addr : root.activeClient === client;
    }

    // What a window IS, for icon lookup. `class` is what Hyprland reports now;
    // `initialClass` is what it started as, and is all there is for a window
    // that has not mapped yet.
    function classOf(client: var): string {
        const o = client?.lastIpcObject;
        return o?.class || o?.initialClass || "";
    }

    function focusClient(client: var): void {
        root.focusAddress(client?.lastIpcObject?.address ?? "");
    }

    function focusAddress(addr: string): void {
        if (addr)
            Hyprland.dispatch(`focuswindow address:${addr}`);
    }

    // Waiting for the window an application is about to open.
    //
    // Hyprland focuses a new window by itself, and that is not the whole job
    // here: with follow_mouse on, the pointer decides who has focus from the
    // next mouse movement onwards, so a window focused while the cursor sits
    // over the one you launched it from loses focus the moment you twitch.
    // Dispatching focus explicitly warps the pointer with it, which makes the
    // keyboard and the mouse agree about what you just asked for.
    property bool claiming: false

    function claimNextWindow(): void {
        root.claiming = true;
        claim.restart();
    }

    // Applications are not quick, and some are very slow. Long enough for a
    // browser to get itself up, short enough that an unrelated window opening
    // later is never mistaken for the one that was asked for.
    Timer {
        id: claim

        interval: Config.values.launcher.claimMs
        onTriggered: root.claiming = false
    }

    // The window that has the keyboard, as an address, straight off the event
    // stream.
    //
    // NOT `activeToplevel`. That is refreshed by an IPC round trip after the
    // event arrives, so anything reading it in the same turn as the event gets
    // the PREVIOUS window: a panel that saved it on the way up restored focus to
    // whatever had it before the one you were actually using. This is set from
    // the event's own payload, so it is right by the time anything can ask.
    //
    // Empty payloads are IGNORED rather than stored. Hyprland reports focus
    // moving to a layer surface as an empty activewindowv2, and that is exactly
    // the transition a panel needs to remember ACROSS.
    property string focusedAddress: ""

    // Windows on the screen's active workspace, front-most first, which is the
    // order a picker has to test them in: the one on top is the one you meant.
    function clientsOn(screen: var): var {
        const mon = Hyprland.monitorFor(screen);
        if (!mon)
            return [];
        const special = mon.lastIpcObject?.specialWorkspace;
        const wsId = special?.name ? special.id : mon.activeWorkspace?.id;
        return Hyprland.toplevels.values.filter(c => c.workspace?.id === wsId).sort((a, b) => {
            const x = a.lastIpcObject;
            const y = b.lastIpcObject;
            return (y.pinned - x.pinned) || ((y.fullscreen !== 0) - (x.fullscreen !== 0)) || (y.floating - x.floating);
        });
    }

    function switchTo(id: int): void {
        Hyprland.dispatch(`workspace ${id}`);
    }

    // Hyprland pushes an event stream over its socket. Quickshell keeps its own
    // model in sync for some of it, but window counts only update when asked.
    Connections {
        target: Hyprland

        function onRawEvent(event): void {
            const n = event.name;

            if (n === "openwindow" && root.claiming) {
                root.claiming = false;
                claim.stop();
                // WINDOWADDRESS,WORKSPACENAME,WINDOWCLASS,WINDOWTITLE, and the
                // address arrives without its 0x.
                const addr = (event.data ?? "").split(",")[0];
                if (addr)
                    root.focusAddress(addr.startsWith("0x") ? addr : `0x${addr}`);
            }

            if (n === "activewindowv2") {
                const addr = (event.data ?? "").trim();
                if (addr && addr !== ",")
                    root.focusedAddress = addr.startsWith("0x") ? addr : `0x${addr}`;
            }

            // `activespecial` is the one that says a scratchpad came or went,
            // and it contains none of the words below: not "workspace", not
            // "window", not "mon". Which is why the shell used to know a special
            // workspace existed and never notice one being pulled open.
            if (n.includes("workspace") || n.includes("window") || n.includes("mon") || n.includes("special")) {
                Hyprland.refreshWorkspaces();
                Hyprland.refreshToplevels();
                // MONITORS TOO: which special is over the screen is a property of
                // the monitor, not of the workspace list, so refreshing the other
                // two leaves that answer exactly as stale as it was.
                Hyprland.refreshMonitors();
            }
        }
    }
}
