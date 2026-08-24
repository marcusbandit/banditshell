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

    // ...AND EVERY MONITOR GETS ITS OWN SET OF THEM, which is what turns the
    // number above from "how many workspaces there are" into "how long one
    // screen's run is".
    //
    // A monitor owns a CONTIGUOUS BAND: the k-th CONNECTED name in
    // `sidebar.workspaces.order` owns [k*count + 1 .. k*count + count], so with
    // a five-slot column the first screen owns 1-5 and the second 6-10. One
    // number, k, is the whole of a monitor's claim, and both ends of the band
    // fall out of it and `count` rather than being written down anywhere (see
    // ~/.claude/rules/math-over-hardcoding.md): lengthen the column and every
    // band lengthens with it, on every screen, with nothing to keep in step.
    //
    // CONTIGUOUS, and not interleaved. Odds on one screen and evens on the
    // other would also partition the numbers, and it would be unusable: the
    // workspace numbers are what you type into a keybind, and a run you can
    // say out loud ("one to five is the laptop") is the only arrangement a hand
    // can learn. It is also the arrangement `rules.conf` is already written in
    // on any machine that has thought about this at all, which is what makes
    // the seed below possible.
    //
    // AN ORDER OF NAMES, never anything the compositor numbers. Hyprland hands
    // out monitor ids in plug order, so pulling one cable renumbers the screens
    // that are left, and a band keyed to an id would change which workspaces a
    // screen draws while you were looking at it. Nor anything spatial: where a
    // monitor sits is something the shell can only guess at from layout
    // coordinates, and guessing would make the answer move when the desk did.
    // A name is the one handle on a screen that holds still.
    readonly property var order: Config.values.sidebar.workspaces.order

    // THE ORDER WITH THE UNPLUGGED SCREENS TAKEN OUT, which is what bands are
    // counted off. A screen that is not here cannot hold a band: alone on the
    // laptop, eDP-1 is first and owns 1-5 however many desk monitors the order
    // still lists ahead of it, and that is the same rule that gives it 11-15
    // when they are all plugged in.
    //
    // `order` itself is untouched, so plugging the desk back in puts every
    // screen back on exactly the workspaces it had.
    readonly property var live: root.order.filter(name => root.outputs.indexOf(name) >= 0)

    // THE FIRST WORKSPACE OF A SCREEN'S RUN, which is the only number a
    // per-screen consumer needs: everything else in its column is this plus an
    // index, and every id it produces is a real workspace, so `switchTo` and
    // `clientsIn` go on meaning exactly what they meant.
    //
    // A NAME `live` HAS NOT HEARD OF GETS THE FIRST BAND rather than nothing.
    // That is a monitor in the moment before the seed below catches up with it,
    // or the whole of a session where the config could not be read, and a
    // column with no workspaces in it is a column that draws nothing at all.
    function bandFor(screen: string): int {
        return Math.max(0, root.live.indexOf(screen)) * root.count + 1;
    }

    // WHERE EACH MONITOR IS, by monitor name, as a NUMBERED workspace.
    //
    // The per-screen `activeId`, and it applies that property's rule for the
    // same reason: a scratchpad pulled over a screen is focused and its id is
    // negative, but the workspace underneath has not changed and neither has
    // the answer to "where am I", so a negative id means ask the monitor's own
    // `activeWorkspace` instead of believing it.
    //
    // A MAP rather than a function that finds one monitor, for `occupancy`'s
    // reason further down this file: this is read by per-screen bindings that
    // have to re-run whenever anything anywhere moves, and a search that
    // returns the moment it finds its own monitor leaves the caller subscribed
    // to only as much as it happened to touch on the way. Computing every
    // monitor at once touches all of them every time and cannot go stale.
    readonly property var activeByMonitor: {
        const out = {};
        for (const mon of Hyprland.monitors.values) {
            const live = mon.activeWorkspace?.id ?? 0;
            out[mon.name] = live > 0 ? live : (mon.lastIpcObject?.activeWorkspace?.id ?? 0);
        }
        return out;
    }

    // One screen's answer, falling back to the head of that screen's own band.
    // A monitor the compositor has not spoken about yet still has a column to
    // draw, and the first plate of its own run is the only defensible guess;
    // this is `activeId`'s fallback of 1, said in bands.
    function activeOn(screen: string): int {
        return root.activeByMonitor[screen] || root.bandFor(screen);
    }

    // WHAT THE COMPOSITOR'S RULES ALREADY SAY, as { "6": "DP-1" }: which output
    // each numbered workspace is bound to in the config Hyprland has read.
    //
    // Asked of `hyprctl workspacerules` rather than read off `rules.conf`,
    // because the file is the user's to organise however they like and this is
    // only ever a question about what is in force. Two things are built on it:
    // the seed, which recovers the band order from it, and the apply, which
    // diffs against it so that nothing is pushed at a compositor that already
    // agrees.
    property var ruleMonitor: ({})

    // Whether that answer has arrived, which is NOT the same as it being empty.
    // A machine with no workspace rules at all is a real machine, and both the
    // seed and `home` below have to be able to tell "there are none" from "we
    // have not asked yet".
    property bool banded: false

    // BOTH ANSWERS THE SEED NEEDS, because it writes and a writer cannot go
    // early. The compositor's rules are one; the config file it would otherwise
    // be about to overwrite is the other. See Config.loaded for why an unread
    // file and an unset key are the same emptiness until that flips.
    readonly property bool settled: root.banded && Config.loaded

    // The outputs Quickshell knows about, by name, as a plain list so that a
    // monitor arriving or leaving is a value change this file can hear. Reading
    // `Quickshell.screens` inside `reband` alone would tie the seed to whenever
    // something else happened to run it.
    readonly property var outputs: {
        const out = [];
        for (const s of Quickshell.screens)
            out.push(s.name);
        return out;
    }

    onSettledChanged: {
        root.reband();
        root.home();
    }
    onOutputsChanged: root.reband()

    // AND WRITING THE KEY IS THE WHOLE OF REORDERING, which is what makes the
    // settings page a settings page rather than a second implementation of
    // this file. Move a name, `Config.set` the list, and the compositor is told
    // by the handler below; no caller has to remember to also call
    // `applyBands`, and no caller can forget and leave the shell drawing bands
    // the desktop does not have.
    //
    // It fires more often than it strictly needs to, because `Config.set` deep
    // copies the whole settings object and hands back a new array every time
    // ANY setting changes. That costs one comparison per workspace against a
    // map that already agrees, which is nothing, and the alternative is a
    // notification this file would have to be told about by hand.
    onOrderChanged: root.applyBands()

    // Seed, then tell the compositor if the two disagree.
    //
    // The apply is skipped when the seed WROTE, because writing the order fires
    // the handler above and that has already pushed it: asking again a line
    // later would be the same keywords a second time, at a compositor that
    // heard them the first time. The other path is the one that needs this
    // call, and it is the reload: the rules moved under an order that did not.
    function reband(): void {
        if (!root.settled)
            return;
        if (!root.adopt())
            root.applyBands();
    }

    // THE ORDER, SEEDED FROM THE COMPOSITOR AND THEN LEFT ALONE.
    //
    // The band model needs a list of names and there is no honest way to invent
    // one: which screen is "first" is a question about where you sit, and the
    // shell cannot see the desk. But the compositor has already been told the
    // answer. `rules.conf` binds workspaces to outputs, so grouping those rules
    // by monitor and sorting each monitor by the LOWEST workspace it was given
    // recovers the order the user has already written down. 1-5 on one output
    // and 6-10 on another IS "this one, then that one", spelled in the one
    // place a desktop ever spells it.
    //
    // Which means the first run reproduces exactly what the machine was already
    // doing, and nothing moves. That is the whole reason for seeding rather
    // than defaulting: a shell that picked an order of its own would reshuffle
    // a working desktop on the day it was installed, and would be right about
    // it roughly half the time.
    //
    // ONCE. After the seed the list belongs to the user, so a rule changed in
    // `rules.conf` afterwards does not quietly rewrite it: by then the list is
    // what the settings page reorders and the compositor is what gets told.
    //
    // A MONITOR NO RULE MENTIONS IS APPENDED, in the order Quickshell hands the
    // screens over, and that part is not once: a monitor plugged in next week
    // needs a band of its own rather than sharing the first one. Appended and
    // never removed, which is why unplugging a screen leaves its place in the
    // list and plugging it back in puts it on the same workspaces it had.
    //
    // ONLY EVER APPENDS, which is what makes the length a complete test for
    // "did anything change". Nothing here reorders and nothing drops, so a list
    // that is the same length is the same list, and the config file is left
    // alone on every run after the first. That test is also the return value,
    // for the one caller that has to know whether a write happened.
    function adopt(): bool {
        const next = root.order.slice();

        if (!next.length) {
            const lowest = {};
            for (const id in root.ruleMonitor) {
                const mon = root.ruleMonitor[id];
                const n = parseInt(id, 10);
                if (!(mon in lowest) || n < lowest[mon])
                    lowest[mon] = n;
            }
            for (const mon of Object.keys(lowest).sort((a, b) => lowest[a] - lowest[b]))
                next.push(mon);
        }

        for (const name of root.outputs)
            if (next.indexOf(name) < 0)
                next.push(name);

        if (next.length === root.order.length)
            return false;

        Config.set("sidebar.workspaces.order", next);
        return true;
    }

    // WHAT THE ORDER WANTS, in the same { workspace: monitor } shape the rules
    // come back in, so the two can simply be compared. Every band, every slot
    // in it, from the count.
    //
    // Off `live` for `bandFor`'s reason: binding a workspace to a monitor that
    // is not plugged in is a rule the compositor cannot honour, and it is the
    // rule that was stranding 1-5 on an absent screen.
    function wants(): var {
        const out = {};
        for (let k = 0; k < root.live.length; k++)
            for (let i = 0; i < root.count; i++)
                out[`${k * root.count + i + 1}`] = root.live[k];
        return out;
    }

    // TELL THE COMPOSITOR WHERE THE BANDS ARE, for the workspaces whose answer
    // has actually changed and for no others.
    //
    // A BINDING, AND NOTHING ELSE. `rules.conf` is never rewritten, and the
    // reason is load-bearing rather than tidy: `workspacerules -j` reports
    // `workspaceString`, `enabled` and `monitor`, and that is ALL it reports.
    // A rule carrying `layout:scrolling, layoutopt:direction:down` comes back
    // looking exactly like one that carries nothing, so a shell that read the
    // rules and wrote them out again would silently delete every option it
    // could not see. It can only ever add a binding on top of what is there,
    // which is precisely what `hyprctl keyword` does.
    //
    // AND A KEYWORD IS RUNTIME STATE. It lives until the next `hyprctl reload`,
    // which puts the file's own rules back over it, so this is re-run on
    // `configReloaded` and the diff is taken against the FILE's answer rather
    // than against whatever was pushed last time. That is also why the rules
    // are re-read there before this runs: a reload is the one moment the file
    // can have said something new.
    //
    // ONE BATCH rather than one process per workspace. Two screens of five is
    // ten keywords, and ten hyprctl processes to say one thing is nine more
    // than the compositor needs to hear it.
    //
    // NOTHING TO SAY IS SAID BY SAYING NOTHING, which is what keeps this off
    // the startup path. On any machine whose order was seeded from its own
    // rules the diff is empty, so the cost at boot is one comparison and no
    // process at all; it only speaks once somebody has actually moved a band.
    function applyBands(): void {
        // Nothing to diff against yet. Pushing here would compare every
        // workspace against an answer nobody has given and conclude that all of
        // them have moved, which is the one way this could shove a desktop
        // around at startup for no reason at all.
        if (!root.banded)
            return;

        // ONE PUSH AT A TIME, and the next answer is REMEMBERED rather than
        // dropped. A Process cannot be re-commanded while it is running, and
        // two clicks of a reorder button are milliseconds apart where an
        // hyprctl round trip is several: the second answer would be the true
        // one and the compositor would be left holding the first. Queued, it
        // goes out the moment the process is done.
        if (pusher.running) {
            root.pushAgain = true;
            return;
        }

        const want = root.wants();
        const cmds = [];
        for (const id in want)
            if (root.ruleMonitor[id] !== want[id])
                cmds.push(`keyword workspace ${id}, monitor:${want[id]}`);

        if (!cmds.length)
            return;

        pusher.command = ["hyprctl", "--batch", cmds.join(" ; ")];
        pusher.running = true;
    }

    property bool pushAgain: false

    Process {
        id: pusher

        onExited: if (root.pushAgain) {
            root.pushAgain = false;
            root.applyBands();
        }
    }

    Process {
        id: ruleScan

        running: true
        command: ["hyprctl", "-j", "workspacerules"]

        stdout: StdioCollector {
            onStreamFinished: {
                // Same tolerance the monitor seed below takes: hyprctl can come
                // back empty or half-written while the compositor is starting,
                // and a bad read is not worth an exception.
                let rules = [];
                try {
                    rules = JSON.parse(text);
                } catch (e) {}

                const bound = {};
                for (const r of rules) {
                    // NUMBERED WORKSPACES ONLY. A rule can be written against
                    // `special:music` or `name:build`, and neither is a place
                    // in a band: a scratchpad is pulled over wherever you
                    // already are, and a named workspace has no position in a
                    // run. All digits or it is not a number, because parseInt
                    // would happily read "10things" as ten and file a rule
                    // under a workspace nobody wrote.
                    if (r.monitor && /^\d+$/.test(r.workspaceString ?? ""))
                        bound[r.workspaceString] = r.monitor;
                }

                root.ruleMonitor = bound;
                root.banded = true;
                // Called rather than left to `settled`, because after the first
                // time `banded` is already true and a reload's re-read would
                // change nothing anybody was listening to.
                root.reband();
            }
        }
    }

    // HOME AT BOOT, and only when the shell would otherwise come up looking at
    // a workspace it has nowhere to draw. Where you are is the compositor's
    // business every other minute of the day; a session that starts on
    // workspace 11 with a five-slot column is the one moment it is the shell's,
    // because the accent then sits on no plate at all and the sidebar is
    // quietly wrong about where you are before you have touched it.
    //
    // MEASURED AGAINST THE FOCUSED SCREEN'S OWN BAND, which is the correction
    // bands forced and the one place they could have gone badly wrong. "Past
    // the end of the column" used to be `activeId > count`, and on a two-screen
    // machine the second screen's every workspace is past the end of five: a
    // session left on workspace 6, which is exactly where the second monitor
    // lives, would have been dragged back to workspace 1 on the other screen
    // every time the shell started. The question is whether you are on a
    // workspace YOUR screen draws, so it is asked of your screen's band, and
    // the way back is the head of that band rather than the number one.
    //
    // ONCE, and conditionally. A reload is a fresh `Component.onCompleted` as
    // far as this file is concerned, and being yanked back to the top of the
    // column every time a QML file is saved would be unusable; anywhere inside
    // your own band, which is nearly always, this does nothing whatsoever.
    //
    // WAITED FOR, THREE TIMES, rather than read at startup, because three
    // separate answers have to be in before the question means anything.
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
    // failing loudly.
    //
    // The third is `settled`, and it is the band's. Until the order has been
    // seeded, `bandFor` answers 1 for every screen, so the second monitor looks
    // like it is standing outside a band it in fact owns, and this would fire
    // the very switch the paragraph above says it must not.
    //
    // So it waits for all three, and every handler that watches one of them
    // calls in: the two below, and `onSettledChanged` up in the band section,
    // because any of the three can be the one that arrives last.
    readonly property int known: Hyprland.workspaces.values.length
    property bool homed: false

    onKnownChanged: root.home()
    onParserKnownChanged: root.home()
    Component.onCompleted: root.home()

    function home(): void {
        if (root.homed || root.known === 0 || !root.parserKnown || !root.settled)
            return;
        root.homed = true;
        const band = root.bandFor(root.focusedScreen);
        if (root.activeId < band || root.activeId >= band + root.count)
            root.switchTo(band);
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

    // ASK THE COMPOSITOR AGAIN, for anything that reads geometry at a moment of
    // its own choosing.
    //
    // `lastIpcObject` is filled by an IPC round trip, and this shell only makes
    // that trip when Hyprland announces something (see the event handler at the
    // bottom of this file). Most of what moves a window announces itself; a
    // window RESIZED by hand does not. So a reader that picks its own moment -
    // the mic indicator, when the microphone opens - asks here first rather than
    // drawing itself against a position from the last focus change.
    function resync(): void {
        Hyprland.refreshToplevels();
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
    //
    // AND THE SIDEBAR NO LONGER ASKS IT, which is the last step of that same
    // argument: a column is drawn per screen, so it wants `specialOn` and its
    // own name rather than whichever monitor happens to have the keyboard. This
    // stays because "the special over the screen you are looking at" is a real
    // question with real askers to come, and it is the right shape for anything
    // summoned by a keybind rather than reached for with the cursor.
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
    // A map is also what lets a per-screen consumer ask about ITS screen rather
    // than about the focused one, and `specialOn` below is the caller this note
    // used to say did not exist yet. It does now:
    // modules/sidebar/WorkspaceModel.qml takes a screen, and every column reads
    // the special lying over its own monitor, so pulling a scratchpad over the
    // laptop no longer greys out the plate you are on over on the desk.
    property var specialByMonitor: ({})

    // ONE SCREEN'S ANSWER, which is what `specialShown` is for the focused one.
    // "" for a monitor whose special has been dismissed and for one nothing has
    // been said about, and those two are the same fact as far as a column is
    // concerned: nothing is lying over it.
    function specialOn(screen: string): string {
        return root.specialByMonitor[screen] ?? "";
    }

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

    // ONE ENTRY PER MARK, for a column that draws applications rather than
    // windows: [{ client, cls, count }], in the order the windows arrive.
    //
    // A client folds into the entry for ITS OWN APPLICATION when the workspace
    // already has one; otherwise it starts one, in the place it appears. So the
    // list is one entry per application, in the order those applications first
    // turn up, and nothing is moved except the duplicates.
    //
    // EVERY APPLICATION, where this used to be a table of the ones you keep
    // several of (terminals). The table was wrong twice in a week: it started as
    // kitty, grew to every terminal, and then an Android emulator put four
    // identical windows on a workspace and hid everything else on it behind them.
    // There is no list of applications people run several of, there is only the
    // fact that a mark says WHICH application and a second copy of it says
    // nothing a number could not say better. So the rule is the same for all of
    // them and there is nothing to keep up to date.
    //
    // BY APPLICATION, NOT BY NEIGHBOUR, which is the correction the emulator
    // forced. Folding only into the entry immediately before kept more of the
    // workspace's shape and cannot hold, because the list this runs over is in
    // SCREEN order (see `clients`): four windows of one application sat two on
    // the left of a browser and two on its right, so a rule that merges only
    // neighbours drew the same application twice with the same glyph and no way
    // to tell the two marks apart. A column that answers "what is on this
    // workspace" must not be able to say a thing twice.
    function stackClients(clients: var): var {
        const out = [];
        for (const client of clients) {
            const cls = root.classOf(client);
            const held = out.find(m => m.cls === cls);
            if (held)
                held.count++;
            else
                out.push({
                    client,
                    cls,
                    count: 1
                });
        }
        return out;
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

    // WHICH MONITOR IS SHOWING THE WINDOW AT THIS ADDRESS, by name, and "" for
    // one no monitor is showing at all. Asked of the model rather than of the
    // compositor.
    //
    // `Hyprland.toplevels` is kept in step with the same event stream this file
    // reads, so the answer is already in the process and costs a walk of a list
    // that is never longer than the windows on the machine. `hyprctl clients`
    // would be the authority, and it was rejected for being an ASYNCHRONOUS
    // one: the caller below has to decide whether to dispatch in the turn it is
    // asked, and an answer that lands two frames later is no use to it.
    //
    // The two spellings are both here to be reconciled. Quickshell's model
    // writes an address bare and Hyprland's event stream writes it with its
    // `0x`, so both ends are stripped before they are compared; neither format
    // is this shell's to change, and comparing them as they come would answer
    // "no window" for every window there is.
    //
    // SHOWING means the window's workspace is the one a monitor is on, or is a
    // special pulled over one, which is the same pair `occupancy` below counts
    // and for the same reason: a scratchpad hidden again is off screen, and a
    // window on it is as unreachable as one two workspaces away. Every monitor
    // is asked rather than only the focused one.
    //
    // AND THE MONITOR THAT ANSWERS IS KEPT, which is the whole difference
    // between this and the bool it used to be. The walk always knew which
    // screen the window was on and threw the name away on the way to a yes; the
    // per-monitor focus map below is the caller that needs the name, and
    // `specialByMonitor` further up carries the same lesson learned from the
    // other end. A fact this file has already computed and discarded is a fact
    // somebody else will go and compute worse.
    //
    // Workspace id zero is a window the model has not placed yet, and an unplaced
    // window is not one anybody is looking at.
    function monitorOf(addr: string): string {
        const bare = (addr.startsWith("0x") ? addr.slice(2) : addr).toLowerCase();
        const client = Hyprland.toplevels.values.find(t => (t.address ?? "").toLowerCase() === bare);
        const id = client?.workspace?.id ?? 0;
        if (id === 0)
            return "";
        const shown = Hyprland.monitors.values.find(mon => {
            const special = mon.lastIpcObject?.specialWorkspace;
            return mon.activeWorkspace?.id === id || (!!special?.name && special.id === id);
        });
        return shown?.name ?? "";
    }

    // IS THERE A WINDOW AT THIS ADDRESS AND IS IT IN FRONT OF YOU: the question
    // above with the name dropped, for `restoreFocus`, which only ever wanted
    // the yes or no. Any monitor at all, because a window in plain sight on the
    // other screen is still in plain sight; see that function's own note for why
    // crossing monitors is the good half of its behaviour.
    function onScreen(addr: string): bool {
        return root.monitorOf(addr) !== "";
    }

    // CLOSE ONE WINDOW, NAMED, rather than whichever one holds the keyboard.
    //
    // `killactive` is the dispatcher everybody binds and it is the wrong one for
    // a gesture: what a finger swipes up is the window it landed on, and under
    // follow-mouse that is not reliably the focused one. A close that asks for
    // "the active one" would sometimes destroy a different window than the one
    // in your hand, and this is the shell's only destructive gesture.
    function closeWindow(addr: string): void {
        if (addr)
            root.send(`hl.dsp.window.close({ window = "address:${addr}" })`, `closewindow address:${addr}`);
    }

    // SEND A WINDOW SOMEWHERE ELSE AND STAY WHERE YOU ARE.
    //
    // `target` is a workspace id, or one of the compositor's own selectors as a
    // string: "empty" is the first workspace with nothing on it, which is what
    // "a new one" means to a compositor that numbers workspaces rather than
    // creating them.
    //
    // THE LUA PARSER HAS NO SILENT MOVE, which is the whole reason this is not
    // one line. `movetoworkspacesilent` exists in the old dialect and
    // `hl.dsp.window.move` has no flag for it: measured against 0.56.2, a
    // `silent = true` in the table is accepted, ignored, and the view follows
    // the window anyway. So the silence is COMPOSED here, exactly as
    // restoreFocus composes its cursor put-back: read where you are, move the
    // window, go back. One dispatch, so there is no frame in between for the
    // screen to be seen anywhere it was not sent.
    //
    // The workspace is handed back as the OBJECT that was read rather than as
    // its id, because that is what `hl.dsp.focus` takes and it costs an
    // arithmetic step to turn one into the other for no gain.
    function sendToWorkspace(addr: string, target: var, follow: bool): void {
        if (!addr)
            return;

        // A number goes in bare and a selector goes in quoted; the legacy
        // spelling takes both the same way.
        const ws = typeof target === "number" ? `${target}` : `"${target}"`;

        if (follow) {
            root.send(`hl.dsp.window.move({ window = "address:${addr}", workspace = ${ws} })`, `movetoworkspace ${target},address:${addr}`);
            return;
        }

        root.send(`(function() local w = hl.get_active_workspace() hl.dispatch(hl.dsp.window.move({ window = "address:${addr}", workspace = ${ws} })) return hl.dsp.focus({ workspace = w }) end)()`, `movetoworkspacesilent ${target},address:${addr}`);
    }

    // TWO WINDOWS TRADE PLACES, which is the whole of what rearranging a tiled
    // workspace is. There are no coordinates to hand a tiling layout, only
    // another window to go and stand where, so "put this one there" and "swap
    // these two" are the same sentence.
    //
    // LUA ONLY, and it is the one call in this file with no legacy spelling at
    // all. The old parser's `swapwindow` takes a DIRECTION and nothing else, so
    // there is no degraded version to fall back to: swapping by address did not
    // exist before the Lua dispatch table. It says so rather than sending a
    // sentence the old parser would refuse as a syntax error, which is the
    // failure mode `send` exists to prevent.
    function swapWith(addr: string, other: string): void {
        if (!addr || !other || addr === other)
            return;

        if (!root.lua) {
            console.warn("Hypr: swapping two windows by address needs Hyprland's Lua dispatcher; the old parser's swapwindow only takes a direction.");
            return;
        }

        Hyprland.dispatch(`hl.dsp.window.swap({ window = "address:${addr}", with = "address:${other}" })`);
    }

    // WALK A WINDOW'S COLUMN THROUGH THE LAYOUT, one place at a time. Negative
    // steps go left, positive right.
    //
    // This is the difference between MOVING a window and SWAPPING it: everything
    // the column passes shuffles up by one and keeps its own order, so three
    // windows and a move of the third onto the first leaves 3,1,2 where a swap
    // would leave 3,2,1.
    //
    // `swapcol` AND NOT `movewindow <direction>`, which is the obvious
    // dispatcher and the wrong one. In the scrolling layout a directional move
    // puts the window INTO the neighbouring column, stacking two windows where
    // there was one, and only moves it along on the next press; measured, one
    // press merged a pair and the second broke them apart in the wrong order.
    // `swapcol` is the layout's own column-level exchange and never stacks
    // anything. It is what the user's own SUPER+SHIFT+CONTROL+arrow is bound to.
    //
    // LAYOUTMSG HAS NO WINDOW SELECTOR, so the window has to hold the focus for
    // the message to be about it. The whole run is composed into ONE dispatch,
    // the way restoreFocus composes its cursor put-back: read the pointer and the
    // focus, take the focus, walk, hand it back, put the pointer where it was.
    // There is no frame in between for any of that to be seen, and a gesture that
    // rearranges a workspace must not also move somebody's keyboard or cursor.
    function walkColumn(addr: string, steps: int): void {
        if (!addr || steps === 0)
            return;

        if (!root.lua) {
            console.warn("Hypr: walking a column needs Hyprland's Lua dispatcher; the old parser cannot compose the focus around it.");
            return;
        }

        const dir = steps < 0 ? "l" : "r";
        let walk = "";
        for (let i = 0; i < Math.abs(steps); i++)
            walk += `hl.dispatch(hl.dsp.layout("swapcol ${dir}")) `;

        Hyprland.dispatch(`(function() local p = hl.get_cursor_pos() local w = hl.get_active_window() hl.dispatch(hl.dsp.focus({ window = "address:${addr}" })) ${walk}if w then hl.dispatch(hl.dsp.focus({ window = w })) end return hl.dsp.cursor.move({ x = p.x, y = p.y }) end)()`);
    }

    // Waiting for the window an application is about to open.
    //
    // Hyprland focuses a new window by itself, and that is not the whole job
    // here: with follow_mouse on, the pointer decides who has focus from the
    // next mouse movement onwards, so a window focused while the cursor sits
    // over the one you launched it from loses focus the moment you twitch.
    // Dispatching focus explicitly warps the pointer with it, which makes the
    // keyboard and the mouse agree about what you just asked for.
    //
    // ONE RECORD PER LAUNCH, and not one flag for the whole shell. It was a
    // bool, and a bool is a claim that can only be spent once however many
    // launches are in flight: two Returns inside the same second, which is one
    // launcher on each monitor or simply a fast hand on one, meant the first
    // window to map cleared the flag and the second launch was never focused at
    // all. Nothing said so. The notice still drew its pill and the window still
    // opened; the keyboard just stayed where it was, which from the outside is
    // indistinguishable from the compositor having decided that for itself.
    //
    // A LIST OF DEADLINES, which is all a claim has ever been. Every claim does
    // the same thing to the window it retires (focus it, pointer and all), so
    // which claim a given window spends cannot be observed from outside and
    // there is nothing here worth matching by class or by monitor: only the
    // COUNT was ever wrong. The oldest is spent first, which is what
    // services/Launching.qml does with the same question one layer up.
    //
    // AND EACH ONE KEEPS ITS OWN CLOCK. The single timer was RESTARTED by every
    // claim, so a second launch quietly extended the first claim's life and two
    // launches a second apart were both alive for claimMs after the LAST of
    // them; a deadline per claim is the same promise made to each launch
    // separately, which is what it was always described as.
    //
    // NOT MATCHED AGAINST WHAT WAS LAUNCHED, deliberately. Launching.qml holds
    // the marks a window's class can be tested against and does that matching
    // properly; this file is the layer underneath it and must not reach up into
    // it. The call sites settle it anyway: NiagaraLauncher's `launch(what)`
    // runs an arbitrary closure out of a row's menu and has no desktop entry to
    // name.
    property var claims: []

    function claimNextWindow(): void {
        root.claims = [...root.claims, Date.now() + Config.values.launcher.claimMs];
        claim.restart();
    }

    // SPEND THE OLDEST LIVE CLAIM, and say whether there was one.
    //
    // Expiry is decided HERE rather than trusted to the sweep below, because the
    // sweep only runs after the last claim has run out and the list can hold a
    // dead claim for a good while before that. A window mapping in between must
    // not be able to spend it.
    function takeClaim(): bool {
        const live = root.claims.filter(until => until > Date.now());
        if (!live.length) {
            if (root.claims.length)
                root.claims = live;
            return false;
        }
        root.claims = live.slice(1);
        return true;
    }

    // Applications are not quick, and some are very slow. Long enough for a
    // browser to get itself up, short enough that an unrelated window opening
    // later is never mistaken for the one that was asked for.
    //
    // EMPTIED WHOLE, and one timer for the lot of them. Restarted by every
    // claim, so it fires a full claimMs after the LAST one was made, by which
    // time every earlier claim has outlived its own deadline too. That is only
    // housekeeping: the deadlines are what `takeClaim` reads, so a claim is
    // dead to a window the instant it runs out whether or not this has been
    // round to sweep it up.
    Timer {
        id: claim

        interval: Config.values.launcher.claimMs
        onTriggered: root.claims = []
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
    //
    // THE LIVE ANSWER, AND SHELL-WIDE, which is exactly right for the two
    // things that still read it. `isFocused` asks whether a delegate is THE
    // focused window, and services/Launching.qml watches this change to notice
    // a single-instance application raising the window it already had instead
    // of mapping a new one. Neither of those is a question about a screen.
    //
    // A PANEL'S QUESTION IS, and panels ask `focusedOn` below instead. See the
    // map for what reading this one on the way up cost them.
    property string focusedAddress: ""

    // WHERE THE KEYBOARD LAST WAS ON EACH MONITOR, by monitor name:
    // { "DP-1": "0x55a1...", "eDP-1": "0x64bc..." }.
    //
    // THE HISTORY THE LIVE ANSWER CANNOT KEEP. `focusedAddress` is one slot, so
    // the moment the keyboard moves to the other screen the only record that
    // the first screen had a window in it at all is gone, overwritten by a
    // window nobody over there is looking at. Seven panels in this shell take a
    // snapshot when they open and hand the keyboard back to it when they close,
    // and every one of them read that slot; on one monitor the two answers are
    // the same fact said twice. On two they are not: a panel opened on DP-1
    // while the keyboard is on eDP-1 remembered eDP-1's window, and closing it
    // threw the keyboard across to the other screen.
    //
    // WHICH IS REACHABLE RATHER THAN THEORETICAL. Panels are per screen and are
    // summoned BY NAME: `Settings.toggle(win.screen.name)` in
    // modules/ShellWindow.qml and `Settings.show(root.screen.name)` in
    // modules/settings/SettingsPanel.qml both open the panel on the monitor the
    // gesture happened on, which is precisely the monitor that need not be the
    // focused one. An edge zone is under a hand, not under the keyboard.
    //
    // AND WORSE THAN MERELY WRONG, because `restoreFocus` deliberately leaves
    // the POINTER where it is. Under follow_mouse the handback to the other
    // screen is undone by the very next twitch of the mouse, so the keyboard
    // arrives somewhere nobody asked for it and then leaves again on its own,
    // and what the user sees is a panel that sometimes loses their cursor.
    //
    // A MAP, for `occupancy`'s and `specialByMonitor`'s reason: the question is
    // asked per screen, so the answer is kept per screen and nothing has to
    // guess afterwards which monitor an event was about. REASSIGNED rather than
    // mutated in place, because a `var` property notifies on the object changing
    // identity and not on a key being written into the one it already holds.
    //
    // THE SOURCE OF THE SNAPSHOT, AND ONLY THAT. `restoreFocus`'s `onScreen`
    // guard still lets a handback cross monitors and must: a window you were
    // last in that is sitting in plain sight on the other screen is still where
    // you were, and going back to it moves nothing and switches nothing. What
    // changes here is which window a panel decides it came from, not how far
    // the keyboard is allowed to travel to reach it.
    property var focusedByMonitor: ({})

    // ONE SCREEN'S ANSWER, which is what every panel wanted and what
    // `focusedAddress` only accidentally was.
    //
    // "" for a monitor nothing has been focused on this session, and that is a
    // real answer rather than a missing one: there is no window over there to
    // hand the keyboard back to, and `restoreFocus` says nothing at all when it
    // is given nothing. Handing back a window on some other screen instead is
    // the bug this whole map exists to end.
    //
    // A CALLER THAT CANNOT SAY WHERE IT IS gets the focused screen's answer,
    // which is exactly what reading `focusedAddress` used to give it. An item is
    // in no window for the frame before it is in one, and a preview harness has
    // no screen name to offer at all; neither is a reason to answer worse than
    // the shell answered before there were screens in this at all.
    function focusedOn(screen: string): string {
        return root.focusedByMonitor[screen || root.focusedScreen] ?? "";
    }

    // One monitor's answer, replacing whatever it said before. A monitor with no
    // name is no monitor, and filing an address under "" would be an answer
    // handed to every caller that could not say where it was.
    function noteFocus(monitor: string, addr: string): void {
        if (!monitor)
            return;
        const next = Object.assign({}, root.focusedByMonitor);
        next[monitor] = addr;
        root.focusedByMonitor = next;
    }

    // A DEAD WINDOW IS FORGOTTEN BY EVERY SCREEN THAT WAS HOLDING IT, which is
    // this map's share of the argument written over the closewindow handler
    // below: the address of a window that has gone must not be handed to the
    // NEXT panel that opens, or the one after that. `focusedAddress` clears
    // itself there for exactly this reason and clearing one slot no longer
    // covers it, because the screen holding the dead address is generally not
    // the screen the keyboard is on.
    //
    // Only a screen that was actually holding it is touched, and the map is
    // reassigned only if one was, so a window dying somewhere nothing was
    // remembering costs a walk of a map with one key per monitor and no
    // notification at all.
    function forgetFocus(addr: string): void {
        const next = {};
        let held = false;
        for (const mon in root.focusedByMonitor) {
            const was = root.focusedByMonitor[mon];
            held = held || was === addr;
            next[mon] = was === addr ? "" : was;
        }
        if (held)
            root.focusedByMonitor = next;
    }

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
    //
    // The CLASS comes along because it is the only thing in the event that says
    // WHAT opened: services/Launching.qml matches it against whatever the
    // launcher is still waiting for.
    signal windowOpened(addr: string, title: string, cls: string)

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
                    root.windowOpened(addr, parts.slice(3).join(","), parts[2] ?? "");

                // THE ADDRESS IS CHECKED FIRST, so that a payload this file
                // could not read does not spend somebody's claim on a window it
                // cannot name. `focusAddress` guards itself, so the old spelling
                // dispatched nothing either; it just retired the claim on the way
                // to doing nothing, and the launch that made it waited out the
                // rest of its deadline for a window that had already been and
                // gone.
                //
                // The sweep is left running when a claim is spent, because the
                // claims behind it in the list are still waiting for windows of
                // their own, and there is nothing left for it to sweep once they
                // have gone.
                if (addr && root.takeClaim())
                    root.focusAddress(addr);
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
                    // after that, out of whichever slot was holding it.
                    //
                    // BOTH SLOTS, which is why the map is swept alongside. The
                    // live answer and the screen the window was on are two
                    // different memories of the same window, panels read the
                    // second one, and a window generally dies on a screen that
                    // is not the one the keyboard ends up on: clearing only
                    // `focusedAddress` would leave the dead address sitting in
                    // its monitor's slot for the rest of the session, waiting
                    // for a panel to open over there and be handed it.
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
                    root.forgetFocus(gone);

                    root.windowClosed(gone);
                }
            }

            if (n === "configreloaded") {
                root.configReloaded();

                // AND THE BANDS ARE PUSHED AGAIN, which is this file taking its
                // own signal's advice: a reload drops every `hyprctl keyword`
                // and puts `rules.conf` back over it, so a band the user moved
                // has just been un-moved underneath them. Re-READ before
                // re-pushed, because a reload is the one moment the file can
                // have said something new, and `ruleMonitor` is what the push
                // diffs against; the scan calls `reband` when it lands.
                ruleScan.running = true;
            }

            if (n === "activewindowv2") {
                const addr = (event.data ?? "").trim();
                if (addr && addr !== ",") {
                    const now = addr.startsWith("0x") ? addr : `0x${addr}`;
                    root.focusedAddress = now;

                    // AND FILED UNDER THE SCREEN IT IS ON, which the event does
                    // not say: activewindowv2 carries an address and nothing
                    // else at all.
                    //
                    // ASKED OF THE WINDOW rather than of the focus. Where a
                    // window is, is a fact about the window, and it does not
                    // depend on the order two events happened to arrive in.
                    // `focusedmon` does come with a monitor's name on it and was
                    // the obvious source; it is only sent when focus CROSSES
                    // screens, so every focus change within one monitor, which
                    // is nearly all of them, would have had nothing to read and
                    // would have had to fall back to whatever the last crossing
                    // said. A lookup that is right every time beats a payload
                    // that is right occasionally.
                    //
                    // A WINDOW THE MODEL CANNOT PLACE IS ATTRIBUTED TO THE
                    // FOCUSED SCREEN, and that is the newly mapped window
                    // rather than a mystery: `Hyprland.toplevels` is refreshed
                    // by an IPC round trip that has not landed in the turn this
                    // event is handled in, so the newest window on the machine
                    // is exactly the one `monitorOf` cannot find. Dropping it
                    // would leave the screen you just launched something on
                    // remembering the window from before the launch, which is
                    // the staleness this map was built to remove, arrived at
                    // from the other end. The keyboard has just moved to that
                    // window, so the screen the keyboard is on is the
                    // compositor's own answer to where it went.
                    root.noteFocus(root.monitorOf(now) || root.focusedScreen, now);
                }
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
