pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
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

    // THE SPECIAL WORKSPACE PULLED OVER THE FOCUSED SCREEN, by wire name
    // ("special:magic"), or "" when none is up. This is the sidebar's "what
    // are you actually looking at": while it is non-empty the numbered
    // workspace is still where you ARE, but not what you SEE, and anything
    // wearing an accent should be reading this before it lights up.
    //
    // Set from the EVENT'S OWN PAYLOAD, not read off the monitors' model as
    // `openSpecial` used to be: that answer is refreshed by an IPC round trip
    // AFTER the event lands, so anything reading it in the same turn as the
    // event got the PREVIOUS screen, and a card animating open was chasing
    // state a frame staler than the gesture that opened it. Same lesson as
    // `focusedAddress` below, learned on the other socket.
    //
    // DERIVED FROM THE MAP BELOW, which is the correction to the paragraph that
    // used to stand here. This was one bare string assigned by the event
    // handler, on the argument that "a special is summoned onto the monitor you
    // are focused on, so the latest event is the focused screen's answer". That
    // argument is only true of events that ORIGINATE on the focused monitor,
    // and the handler accepted every one: it parsed the monitor name out of the
    // payload for the sole purpose of throwing it away. So a bind or a window
    // rule toggling a scratchpad on the OTHER screen wrote its answer into the
    // value every consumer reads as "the special over MY screen", and with the
    // seed below already conceding the point (it believes `m.focused` and
    // nothing else) the field was demonstrably load-bearing on one path and
    // discarded on the other.
    //
    // Keeping the shape of the reading side is deliberate: consumers ask one
    // string and get the focused screen's answer, exactly as before, so nothing
    // downstream changes. The difference is that an event about DP-1 now lands
    // in DP-1's slot instead of in everybody's, and moving the keyboard between
    // monitors re-reads the map rather than waiting for the next toggle to
    // correct a value that was never about this screen.
    readonly property string specialShown: root.specialByMonitor[root.focusedScreen] ?? ""

    // WHICH SPECIAL IS OVER WHICH MONITOR, keyed by the monitor's own name,
    // "" for a monitor whose special has been dismissed.
    //
    // Set from the EVENT'S OWN PAYLOAD, for the reason above, and REASSIGNED
    // rather than mutated in place: a `var` property notifies on the object
    // changing identity, not on a key being written into the one it already
    // holds, and `specialShown` is a binding over it. A special coming or going
    // is an event a user caused, a handful a minute at the very most, so a
    // fresh object per event costs nothing worth counting.
    //
    // A map is also what lets a per-screen consumer eventually ask about ITS
    // screen rather than about the focused one; nothing does yet (see
    // modules/sidebar/WorkspaceModel.qml, which is instantiated per screen and
    // still reads the focused answer), and that is a smaller wrongness than the
    // one this replaces because it at least tracks the screen you are looking
    // at.
    property var specialByMonitor: ({})

    // One monitor's answer, replacing whatever it said before.
    function noteSpecial(monitor: string, name: string): void {
        const next = Object.assign({}, root.specialByMonitor);
        next[monitor] = name;
        root.specialByMonitor = next;
    }

    // SEEDED AT STARTUP, BY ASKING. The event stream begins at zero and says
    // nothing about the past, but the shell can restart while a scratchpad is
    // up, and a shell that comes back believing the screen is bare puts the
    // accent on a plate nobody is looking at until the next toggle corrects
    // it. Which special is over the screen is a property of the MONITOR, so
    // the monitors are asked, once, and every one of them is believed: the
    // scan used to keep only `m.focused`, which was the single-value shape
    // forcing a choice the compositor was answering in full.
    //
    // A MONITOR ALREADY IN THE MAP IS LEFT ALONE, which is the whole of what
    // the old `specialHeard` flag did and it is now asked per monitor rather
    // than globally. A process is slower than a socket, so an event can land
    // first, and a seed overwriting it would replace the newer truth with an
    // older snapshot; a key only ever appears here because an event put it
    // there, so its presence IS "the socket has already spoken for this
    // screen". Globally, the same guard would have thrown away the seed for
    // every other monitor on account of one event.
    Process {
        running: true
        command: ["hyprctl", "-j", "monitors"]

        stdout: StdioCollector {
            onStreamFinished: {
                // hyprctl can come back empty or half-written while the
                // compositor is starting or dying, and a bad seed is not worth
                // an exception: the event stream tells the truth soon enough.
                let mons = [];
                try {
                    mons = JSON.parse(text);
                } catch (e) {}
                const next = Object.assign({}, root.specialByMonitor);
                for (const m of mons)
                    if (m.name && !(m.name in next))
                        next[m.name] = m.specialWorkspace?.name ?? "";
                root.specialByMonitor = next;
            }
        }
    }

    // HOW A DISPATCH IS SPELLED, which stopped being one thing at Hyprland 0.56.
    //
    // Its config parser became Lua and the dispatch socket went with it: a
    // request is no longer a dispatcher's name followed by its arguments, it is
    // a Lua expression. `workspace 3` comes back as
    //
    //   [string "return hl.dispatch(workspace 3)"]:1: ')' expected near '3'
    //
    // which is to say every click in the sidebar was landing, being sent, and
    // being refused as a syntax error. Nothing in the shell was broken and
    // nothing in it worked.
    //
    // BOTH SPELLINGS ARE KEPT, because which one is right is a fact about the
    // Hyprland that happens to be running rather than a decision this shell gets
    // to make.
    function send(lua: string, legacy: string): void {
        Hyprland.dispatch(root.lua ? lua : legacy);
    }

    // WHICH ONE THIS HYPRLAND ANSWERS TO, asked once, by trying it.
    //
    // Not read off Quickshell's `usingLua`: that says whether QUICKSHELL is
    // speaking Lua to the compositor, and it is false on a machine whose
    // compositor accepts nothing else. The only reliable answer is the
    // compositor's, so it is asked with the one dispatcher that exists in both
    // worlds and does nothing in either. `no_op()`, written as a call, is a
    // syntax error to the old parser and "ok" from the new one.
    //
    // A process rather than a dispatch, because a dispatch down the event socket
    // cannot report back, and the whole question is what came back. Once: a
    // compositor does not change parsers while it is running.
    property bool lua: false

    // Whether the question above has been ANSWERED, which is not the same as the
    // answer being false.
    //
    // `lua` starts false and means "the old parser" the moment anything reads
    // it, so a caller that runs before the probe comes back cannot tell "no"
    // from "not asked yet" and will happily speak the wrong dialect once, at
    // startup, which is the one moment nobody is watching the log. Anything that
    // has to be phrased in the compositor's own language waits for this.
    property bool parserKnown: false

    Process {
        running: true
        command: ["hyprctl", "dispatch", "hl.dsp.no_op()"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.lua = text.trim() === "ok";
                root.parserKnown = true;
            }
        }
    }

    function toggleSpecial(name: string): void {
        // The dispatcher wants the bare name, not the `special:` prefix it
        // reports back to us.
        const bare = name.startsWith("special:") ? name.slice(8) : name;
        root.send(`hl.dsp.workspace.toggle_special("${bare}")`, `togglespecialworkspace ${bare}`);
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

    // GO TO a window, pointer and all.
    //
    // Hyprland's focus dispatcher warps the cursor into whatever it focuses, and
    // for this call that is the point: clicking a window in the sidebar, or
    // claiming the one an application has just opened, is a request to BE there,
    // and a pointer left behind hands focus straight back to whatever it is
    // still sitting over the moment you twitch.
    function focusAddress(addr: string): void {
        if (addr)
            root.send(`hl.dsp.focus({ window = "address:${addr}" })`, `focuswindow address:${addr}`);
    }

    // HAND THE KEYBOARD BACK, and do not touch the pointer.
    //
    // Every panel in this shell gives focus back to whatever had it on the way
    // out, and not one of those is a request to go anywhere: you closed a panel,
    // you did not ask to be moved. Warping threw the cursor from the corner you
    // had just clicked to the middle of whatever happened to be underneath,
    // which is most of a screen's travel for a gesture meant to change nothing
    // but what has focus.
    //
    // The position is read and put back INSIDE THE SAME DISPATCH, so there is no
    // frame in between for the pointer to be seen anywhere it was not sent. The
    // shape is odd for a reason: a dispatch runs exactly one dispatcher, so the
    // focusing is done as a side effect and the value handed back is the one
    // that puts the cursor where it already was.
    //
    // The legacy parser cannot do this. `movecursor` needs coordinates and there
    // is no way to read them in the same breath, so an older Hyprland keeps the
    // warp rather than getting a version of this that is a frame late.
    function restoreFocus(addr: string): void {
        if (addr)
            root.send(`(function() local p = hl.get_cursor_pos() hl.dispatch(hl.dsp.focus({ window = "address:${addr}" })) return hl.dsp.cursor.move({ x = p.x, y = p.y }) end)()`, `focuswindow address:${addr}`);
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
        root.send(`hl.dsp.focus({ workspace = ${id} })`, `workspace ${id}`);
    }

    // The monitor the keyboard is on, by name. What "the screen" means to
    // anything summoned by a keybind rather than reached for with the cursor.
    readonly property string focusedScreen: Hyprland.focusedMonitor?.name ?? ""

    // A WINDOW HAS MAPPED, with the address it will answer to.
    //
    // Anything that opens a window and then has something to say about it has to
    // hear about it here: a window has no address until it exists, so there is no
    // earlier moment to hold one. Emitted for every window, not only the claimed
    // one; who cares is the listener's business.
    signal windowOpened(addr: string, title: string)

    // ...and it has gone. The counterpart, for anything holding an address that
    // has stopped meaning anything.
    signal windowClosed(addr: string)

    // Hyprland has re-read its config, which drops every rule set with
    // `hyprctl keyword` along with it. Anything that pushed one has to push it
    // again, and this is the only warning it gets.
    signal configReloaded

    // Hyprland pushes an event stream over its socket. Quickshell keeps its own
    // model in sync for some of it, but window counts only update when asked.
    Connections {
        target: Hyprland

        function onRawEvent(event): void {
            const n = event.name;

            if (n === "openwindow") {
                // WINDOWADDRESS,WORKSPACENAME,WINDOWCLASS,WINDOWTITLE, and the
                // address arrives without its 0x. The title is whatever is left:
                // it can contain commas, and the three fields before it cannot.
                const parts = (event.data ?? "").split(",");
                const raw = parts[0] ?? "";
                const addr = raw && !raw.startsWith("0x") ? `0x${raw}` : raw;

                if (addr)
                    root.windowOpened(addr, parts.slice(3).join(","));

                if (root.claiming) {
                    root.claiming = false;
                    claim.stop();
                    root.focusAddress(addr);
                }
            }

            if (n === "closewindow") {
                const raw = (event.data ?? "").trim();
                if (raw)
                    root.windowClosed(raw.startsWith("0x") ? raw : `0x${raw}`);
            }

            if (n === "configreloaded")
                root.configReloaded();

            if (n === "activewindowv2") {
                const addr = (event.data ?? "").trim();
                if (addr && addr !== ",")
                    root.focusedAddress = addr.startsWith("0x") ? addr : `0x${addr}`;
            }

            // A SCRATCHPAD CAME OVER THE SCREEN, OR LEFT IT. The payload is
            // NAME,MONITOR: "activespecial>>special:probe,eDP-1" opening,
            // "activespecial>>,eDP-1" closing, with the name simply absent
            // (measured, not assumed: those are the literal lines off
            // .socket2.sock). Split at the LAST comma rather than the first,
            // which is openwindow's reasoning read from the other end: a
            // monitor's name cannot contain a comma and a special's name is
            // the user's to invent, so the name is whatever the monitor field
            // leaves behind.
            //
            // AND THE MONITOR IS KEPT, not merely isolated so it can be
            // dropped. It is half of what the event says, and filing the name
            // under it is the whole of why `specialByMonitor` is a map; see
            // that property for what the single value it replaces got wrong.
            //
            // A payload with no comma at all is not a shape this compositor has
            // been seen to send, so it is attributed to the focused screen: the
            // exact assumption the old single value made about EVERY event,
            // which is defensible for the one case where the monitor genuinely
            // was not stated and indefensible for the rest.
            if (n === "activespecial") {
                const data = event.data ?? "";
                const cut = data.lastIndexOf(",");
                const monitor = cut >= 0 ? data.slice(cut + 1) : root.focusedScreen;
                const name = cut >= 0 ? data.slice(0, cut) : data;
                root.noteSpecial(monitor, name);
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
