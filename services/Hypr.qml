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

    // HOW MANY SLOTS THE COLUMN DRAWS: the persistent set, always, even when
    // every one of them is empty. A FIXED SET OF PLACES rather than a list of
    // whatever the compositor happens to be holding.
    //
    // It used to grow to cover the focused workspace and the highest live one
    // as well, which sounds accommodating and is exactly how a session comes up
    // with an eleven-slot column: Hyprland numbers workspaces from wherever the
    // last session left off, so ONE window sitting on workspace 11 stretches
    // the column past any length a person chose, and the six empty slots in the
    // middle are places nothing will ever be. A column whose height is decided
    // by the desktop's history is a different shape every boot, and the sidebar
    // is centred on it, so everything else moves too.
    //
    // Derived, not enumerated: the number is `sidebar.workspaces.persistent`
    // and every slot is built from it, so setting it to nine gives nine (see
    // ~/.claude/rules/math-over-hardcoding.md).
    //
    // WHAT THIS GIVES UP is a plate for a workspace off the end of the set. A
    // window opened on workspace 9 by a bind of your own is still there and
    // still switched to; the column just does not draw it, the same way it
    // draws no numbered plate for a special. The one case where that mattered
    // and could be answered rather than accepted is the boot, below.
    readonly property int count: Appearance.sizes.wsPersistent

    // HOME AT BOOT, and only when the shell would otherwise come up looking at
    // a workspace it has nowhere to draw. Where you are is the compositor's
    // business every other minute of the day; a session that starts on
    // workspace 11 with a five-slot column is the one moment it is the shell's,
    // because the accent then sits on no plate at all and the sidebar is
    // quietly wrong about where you are before you have touched it.
    //
    // ONCE, and conditionally. A reload is a fresh `Component.onCompleted` as
    // far as this file is concerned, and being yanked back to workspace one
    // every time a QML file is saved would be unusable; anywhere inside the
    // column, which is nearly always, this does nothing whatsoever.
    //
    // WAITED FOR, TWICE, rather than read at startup, because two separate
    // answers have to be in before the question means anything.
    //
    // The first is Hyprland's own. Quickshell talks to it over a socket, so
    // `activeId` is its own fallback of 1 until the first reply lands, and
    // asking before then finds the shell already home and arms nothing.
    // `known` going non-zero IS that reply: the earliest instant the question
    // can be asked truthfully.
    //
    // The second is `parserKnown`, for the reason written over it. `switchTo`
    // goes out through `send`, which picks its dialect from a probe that is a
    // whole process round-trip away, and `lua` reads false while it is in
    // flight. This is the exact caller that comment warns about: it fires once,
    // at startup, in the one moment nobody is watching the log, and a switch
    // spelled in the wrong dialect is refused as a syntax error rather than
    // failing loudly. So it waits, and both handlers below call in because
    // either answer can be the one that arrives last.
    readonly property int known: Hyprland.workspaces.values.length
    property bool homed: false

    onKnownChanged: root.home()
    onParserKnownChanged: root.home()
    Component.onCompleted: root.home()

    function home(): void {
        if (root.homed || root.known === 0 || !root.parserKnown)
            return;
        root.homed = true;
        if (root.activeId > root.count)
            root.switchTo(1);
    }

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
    //
    // AND THE ADDRESS IS CHECKED BEFORE IT IS SPOKEN, which is the whole of what
    // was missing. Every caller of this is a panel handing back an address it
    // snapshotted when it OPENED, and a window is free to die while a panel is
    // up: close the last window on a workspace with the settings sheet over it
    // and the address the sheet is holding names nothing by the time it is
    // used. Dispatched anyway, Hyprland answers "hl.focus: window not found",
    // the shell writes a warning nobody can act on, and the keyboard is handed
    // nowhere at all, silently, on every dismissal from then on.
    //
    // THE CHECK IS "CAN YOU SEE IT", NOT "DOES IT EXIST", and the difference is
    // a whole workspace. `focusedAddress` is only ever written by a focus event
    // and Hyprland sends none when you arrive on an EMPTY workspace (the empty
    // payload it does send is ignored two hundred lines down, for a reason that
    // still stands), so standing on a bare workspace the remembered address is
    // the window you were using before you left, alive and well and somewhere
    // else entirely. Focusing it is not a focus at all: Hyprland goes to where
    // that window is, which means Escape on an empty workspace threw the whole
    // screen back to the workspace you had just come from. A panel closing is
    // never a request to travel, so a remembered window that is not on screen
    // right now is treated exactly like one that has died, and the keyboard is
    // left wherever the compositor puts it. On an empty workspace that is
    // nowhere, which is the correct answer and the one that was asked for.
    //
    // ON SCREEN ANYWHERE, not on the workspace this panel happens to be drawn
    // over. With two monitors the window you were last in can be sitting in
    // plain sight on the other one, and handing the keyboard back to a window
    // you are looking at is the good half of this behaviour rather than the bad
    // half: nothing moves, nothing switches, the focus goes where it was.
    //
    // NOT PUSHED INTO `focusAddress` ABOVE, which is the obvious place to put
    // one check for both and is wrong for that one. Its second caller is the
    // claim on a window that has just MAPPED (see claimNextWindow), and at that
    // moment the address is younger than the model: the check would refuse the
    // one dispatch that has to happen and the launcher would stop focusing what
    // it launched. Its first is the sidebar being CLICKED, which is a request to
    // travel and must still cross workspaces. The calls differ in exactly this,
    // so the guard belongs to the one that is meant to change nothing.
    //
    // SAYING NOTHING when the window is gone is deliberately the whole of the
    // recovery. The alternative considered was falling back to the front-most
    // window of the workspace, and it was rejected as an opinion this function
    // has no right to: the compositor has already chosen who gets the keyboard
    // when a window dies, and a panel closing is not a request to overrule it.
    function restoreFocus(addr: string): void {
        if (addr && root.onScreen(addr))
            root.send(`(function() local p = hl.get_cursor_pos() hl.dispatch(hl.dsp.focus({ window = "address:${addr}" })) return hl.dsp.cursor.move({ x = p.x, y = p.y }) end)()`, `focuswindow address:${addr}`);
    }

    // IS THERE A WINDOW AT THIS ADDRESS AND IS IT IN FRONT OF YOU, asked of the
    // model rather than of the compositor.
    //
    // `Hyprland.toplevels` is kept in step with the same event stream this file
    // reads, so the answer is already in the process and costs a walk of a list
    // that is never longer than the windows on the machine. `hyprctl clients`
    // would be the authority, and it was rejected for being an ASYNCHRONOUS
    // one: the caller above has to decide whether to dispatch in the turn it is
    // asked, and an answer that lands two frames later is no use to it.
    //
    // The two spellings are both here to be reconciled. Quickshell's model
    // writes an address bare and Hyprland's event stream writes it with its
    // `0x`, so both ends are stripped before they are compared; neither format
    // is this shell's to change, and comparing them as they come would answer
    // "no window" for every window there is.
    //
    // VISIBLE means the window's workspace is the one a monitor is showing, or
    // is a special pulled over one, which is the same pair `occupancy` below
    // counts and for the same reason: a scratchpad hidden again is off screen,
    // and a window on it is as unreachable as one two workspaces away. Asked of
    // every monitor rather than of the focused one, per the paragraph above.
    //
    // Workspace id zero is a window the model has not placed yet, and an unplaced
    // window is not one anybody is looking at.
    function onScreen(addr: string): bool {
        const bare = (addr.startsWith("0x") ? addr.slice(2) : addr).toLowerCase();
        const client = Hyprland.toplevels.values.find(t => (t.address ?? "").toLowerCase() === bare);
        const id = client?.workspace?.id ?? 0;
        if (id === 0)
            return false;
        return Hyprland.monitors.values.some(mon => {
            const special = mon.lastIpcObject?.specialWorkspace;
            return mon.activeWorkspace?.id === id || (!!special?.name && special.id === id);
        });
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

    // HOW MANY WINDOWS EACH MONITOR IS SHOWING, by monitor name.
    //
    // { "DP-1": 0, "eDP-1": 3 }, and the zero is the interesting one: a monitor
    // whose count is zero is one where the desktop itself is what you are
    // looking at. The wallpaper reads this to decide whether an animation is
    // worth running (modules/WallpaperWindow.qml), which is a question that can
    // only be asked per monitor, because a window opened on the left screen has
    // no opinion about the picture on the right one.
    //
    // A PROPERTY rather than a function, unlike clientsOn below, and the
    // difference is that this one is READ BY A BINDING that has to re-run every
    // time a window opens anywhere. A binding does track properties read
    // through a function call, but only the ones it happens to reach on the
    // path it took, so a function that returns early leaves the caller
    // subscribed to less than it asked about. Computing every monitor at once
    // touches everything every time and cannot go stale.
    //
    // A special workspace pulled over a monitor COUNTS, and counts instead of
    // rather than as well as the workspace underneath: it is drawn on top, so
    // what is on it is what is in front of the wallpaper. An empty special is
    // not a state Hyprland keeps for long, which is the one case this reads
    // optimistically.
    readonly property var occupancy: {
        const out = {};
        for (const mon of Hyprland.monitors.values) {
            const special = mon.lastIpcObject?.specialWorkspace;
            const id = special?.name ? special.id : mon.activeWorkspace?.id;
            out[mon.name] = id === undefined ? 0 : Hyprland.toplevels.values.filter(c => c.workspace?.id === id).length;
        }
        return out;
    }

    // Nothing known about a screen is the same as nothing on it: a monitor the
    // compositor has not told us about yet is one the shell cannot say is busy.
    function windowsOn(screen: string): int {
        return root.occupancy[screen] ?? 0;
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
                if (raw) {
                    const gone = raw.startsWith("0x") ? raw : `0x${raw}`;

                    // AND THE REMEMBERED ADDRESS IS FORGOTTEN WITH IT, before
                    // anybody is told, so a listener that reads `focusedAddress`
                    // out of `windowClosed` reads the truth rather than the
                    // window it was just told had gone.
                    //
                    // This is the other half of `onScreen`'s job and not a
                    // duplicate of it. That guard saves the panel already up,
                    // holding a snapshot nothing can reach; this one stops the
                    // dead address being handed to the NEXT panel, and the one
                    // after that, because `focusedAddress` is what every panel
                    // snapshots on the way in.
                    //
                    // It is needed precisely because of the rule three
                    // paragraphs down: an empty activewindowv2 is ignored, so
                    // that focus moving to a layer surface does not erase the
                    // window a panel has to remember across. Closing the LAST
                    // window on a workspace sends exactly that empty payload,
                    // and with nothing else to correct it the address of a dead
                    // window stayed here for the rest of the session. It also
                    // stopped `isFocused` matching anything at all, so the
                    // sidebar quietly showed no window as focused until the next
                    // focus change: the same staleness, spending itself
                    // somewhere nobody would have thought to look.
                    if (root.focusedAddress === gone)
                        root.focusedAddress = "";

                    root.windowClosed(gone);
                }
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
