pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// MONITORS: what the compositor thinks of every output, and the one place that
// changes it.
//
// The facts come from `hyprctl -j monitors` rather than from Quickshell's
// own monitor model, and that is not a shortcut taken by accident. The page
// needs three things only the compositor's own JSON carries: the AVAILABLE
// modes (every resolution and refresh the panel can be driven at -- Quickshell
// exposes the current one only), the LAYOUT POSITION (where this output sits
// relative to the others, the thing the arrangement canvas drags), and the
// live vrr and transform flags. One process answers all of it.
//
// A SPEC CARRIES THE WHOLE TRUTH, never a delta. A monitor entry replaces the
// output's configuration wholesale, and a field left off it falls back to the
// default -- so a position-only change written without `vrr` would silently
// turn VRR off on an output whose source line turned it on. Every apply
// therefore builds the full current spec and merges the requested fields into
// it; which fields the SOURCE EDIT then rewrites is composeMonitor's finer
// eye, and an unchanged field keeps the line it was read from.
//
// PERSISTENCE LIVES IN THE SOURCE, as of the day this file stopped keeping
// its own. The page's edits are splices into the config tree the user
// already owns -- lua/monitors.lua's table entries, matched through the
// output names that file defines -- said through HyprConfig's write chain:
// splice, verify the whole config parses, reload, rescan. A write that does
// not verify is put back before the compositor has blinked. There is no
// override layer to sync and nothing to adopt: the file is the only
// representation, which is why the page always draws the compositor's live
// state rather than anything it remembers.
//
// An output no source line has ever named is ADDED to the source: joined to
// the outputs list its file keeps, or said as one literal call at the end of
// the file when the file keeps no list. Both are edits to the user's config,
// which is the workflow's own point -- the first one warns, because a
// desktop that quietly rewrites a hand-commented file is a desktop that
// gets uninstalled.
Singleton {
    id: root

    // The compositor's picture of every output, freshest poll wins. Parsed
    // rather than raw: see `probe` below for what each entry carries.
    property var outputs: []

    // Which output the page's property card is editing, by name. A name with
    // no output behind it (unplugged while selected) answers through
    // `selectedOutput` being null, and every consumer handles that case by
    // showing nothing rather than by guessing.
    property string selected: ""

    readonly property var selectedOutput: root.outputs.find(m => m.name === root.selected) ?? null

    // The scale list the properties card cycles. Deliberately finite and
    // deliberate rather than a spinner: Hyprland accepts arbitrary fractions,
    // and a slider's worth of precision on a setting that decides how big
    // every pixel is invites values nobody can read.
    readonly property var scaleChoices: [0.5, 0.6667, 0.75, 1, 1.25, 1.5, 1.75, 2]

    // Transform is Hyprland's own 0..3 for the quarter turns. The flips (4..7)
    // are real but rare, and a row that cycles through eight states to get
    // from normal back to normal is a row nobody cycles twice.
    readonly property var transformChoices: [{
            value: 0,
            label: "normal"
        }, {
            value: 1,
            label: "90°"
        }, {
            value: 2,
            label: "180°"
        }, {
            value: 3,
            label: "270°"
        }]

    // "3840x2160@59.94Hz" -> { w, h, hz }. The only shape the compositor
    // prints its modes in, so one regex and no fallback that could lie.
    function parseMode(s: string): var {
        const m = /^(\d+)x(\d+)@([\d.]+)Hz$/.exec(s ?? "");
        return m ? {
            w: +m[1],
            h: +m[2],
            hz: +m[3]
        } : null;
    }

    // The mode string a monitor line wants, without the Hz suffix Hyprland
    // prints but its own config examples do not carry: "3840x2160@60". The
    // refresh is rounded to the nearest whole hertz, which is what the user's
    // own monitors.lua already does (`5120x1440@144` against a panel that
    // reports 143.987) and what Hyprland documents as nearest-match.
    function modeString(w: int, h: int, hz: real): string {
        return `${w}x${h}@${Math.round(hz)}`;
    }

    // THE CURRENT SPEC of one output, as a monitor line's fields. The json's
    // width and height are the MODE's dimensions, unturned and unscaled --
    // the layout size is derived, never read -- so the mode match against
    // availableModes is direct, with the refresh rate as the tiebreaker.
    function specFor(m: var): var {
        let mode = root.modeString(m.width, m.height, m.refreshRate);
        for (const s of m.availableModes ?? []) {
            const p = root.parseMode(s);
            if (p && p.w === m.width && p.h === m.height && Math.round(p.hz) === Math.round(m.refreshRate)) {
                mode = root.modeString(p.w, p.h, p.hz);
                break;
            }
        }
        return {
            output: m.name,
            mode,
            position: `${m.x}x${m.y}`,
            scale: m.scale,
            transform: m.transform,
            vrr: m.vrr ? 1 : 0
        };
    }

    // THE LAYOUT RECTANGLE of one output, in layout pixels: the mode divided
    // by the scale, and swapped for the odd transforms, which turn the panel
    // on its side. `x` and `y` are already layout, but the SIZE is not -- the
    // json says what the panel is driven at, not what it occupies, and the
    // canvas and every overlap test live on the occupied kind.
    function layoutOf(m: var): var {
        const odd = m.transform % 2 === 1;
        return {
            w: Math.round((odd ? m.height : m.width) / m.scale),
            h: Math.round((odd ? m.width : m.height) / m.scale)
        };
    }

    // THE ONE APPLY, for a full spec, and it is a source edit: the entry the
    // config already keeps for this output is re-composed with the spec's
    // fields merged in -- its own aliases and unmanaged fields untouched --
    // or, an output no line has ever named, the spec joins the outputs list
    // the config keeps. There is no runtime dispatch beside it: the file is
    // the deed, the chain verifies it before the compositor reloads it, and
    // the poll brings back the truth that survived.
    //
    // QUEUED WHILE THE CHAIN IS BUSY. A commit is a verify, a reload and a
    // rescan -- well over a second -- and a slider re-fires inside that. The
    // old answer was to refuse ("a write is still in flight"), which is a
    // silent drop the page keeps displaying as pending; and an apply landing
    // in a rescan's window found the model mid-rebuild and, entryless, took
    // the add branch -- a second entry in the user's file for an output that
    // already had one. So a spec that arrives while the chain is mid-write
    // or the scan is mid-walk waits here, one per output (a spec is the
    // whole truth, so the newest for an output is the only one worth
    // keeping), and the scan's ready flip brings them out one at a time:
    // each flush runs through applySpec below, which re-finds the entry in
    // the model as the file now has it.
    property var queued: ({})

    function flushQueued(): void {
        const name = Object.keys(root.queued)[0];
        if (!name)
            return;
        const spec = root.queued[name];
        const rest = Object.assign({}, root.queued);
        delete rest[name];
        root.queued = rest;
        root.applySpec(spec);
    }

    Connections {
        target: HyprConfig

        // One spec per flip: the first flush starts a chain of its own, and
        // the rest ride the flips that chain's rescan ends with.
        function onReadyChanged(): void {
            if (HyprConfig.ready)
                root.flushQueued();
        }
    }

    function applySpec(spec: var): void {
        if (!spec?.output)
            return;

        if (HyprConfig.applying || !HyprConfig.ready) {
            root.queued = Object.assign({}, root.queued, {
                [spec.output]: spec
            });
            return;
        }

        root.pending = Object.assign({}, root.pending, {
            [spec.output]: spec
        });

        const entry = HyprConfig.monitors.find(m => !m.dynamic && m.output === spec.output);
        if (entry)
            HyprConfig.updateMonitor(entry.id, {
                mode: spec.mode,
                position: spec.position,
                scale: spec.scale,
                transform: spec.transform,
                vrr: spec.vrr
            });
        else
            // Where a new entry goes is the config's own shape to answer:
            // the first outputs list the scan found, or the end of that
            // file. The scan order is hyprland.lua's own require order, so
            // "first" is the file the user's config reads first.
            HyprConfig.addMonitor((HyprConfig.outputTables[0]?.file ?? "lua/monitors.lua"), spec);

        // The compositor may refuse, round, or reposition; the poll is the
        // page's source of truth. The write chain's own reload fires
        // configReloaded, which re-asks after that; the timers catch the
        // edit whose reload raced them.
        settle.restart();
    }

    // THE SPEC THE PAGE SHOULD SHOW for an output: what we have ASKED for,
    // until the compositor confirms it, and what it confirmed afterwards. A
    // pending entry is cleared the moment the poll reproduces it -- which is
    // also the guard against a fast second change building on stale truth:
    // two applies inside one poll window stack, because the second's base is
    // the first's spec, not the output the poll has not caught up with yet.
    property var pending: ({})

    function displaySpec(name: string): var {
        if (root.pending[name])
            return root.pending[name];
        const m = root.outputs.find(o => o.name === name);
        return m ? root.specFor(m) : null;
    }

    function apply(name: string, fields: var): void {
        const base = root.pending[name] ?? root.specFor(root.outputs.find(o => o.name === name));
        if (!base)
            return;
        root.applySpec(Object.assign({}, base, fields));
    }

    // THE POLL. `hyprctl` can come back empty or half-written while the
    // compositor is starting; a failed poll leaves the last truth standing
    // and the next one corrects it, exactly the tolerance Hypr.qml's own
    // monitor seed takes.
    function refresh(): void {
        probe.running = true;
    }

    Process {
        id: probe

        command: ["hyprctl", "-j", "monitors"]

        stdout: StdioCollector {
            onStreamFinished: {
                let mons = [];
                try {
                    mons = JSON.parse(text);
                } catch (e) {}
                if (!mons.length)
                    return;
                root.outputs = mons.map(m => ({
                        name: m.name,
                        description: [m.make, m.model].filter(p => p).join(" "),
                        x: m.x,
                        y: m.y,
                        width: m.width,
                        height: m.height,
                        scale: m.scale,
                        transform: m.transform,
                        vrr: !!m.vrr,
                        refreshRate: m.refreshRate,
                        availableModes: m.availableModes ?? [],
                        focused: !!m.focused,
                        disabled: !!m.disabled
                    }));
                // A selection that was never made, or was made on an output
                // since unplugged, falls to the focused screen: the one
                // monitor the user can point at.
                if (!root.outputs.some(m => m.name === root.selected))
                    root.selected = root.outputs.find(m => m.focused)?.name ?? root.outputs[0]?.name ?? "";

                // CONFIRMED: a pending spec the compositor now reproduces
                // field for field is no longer an ask, it is the answer.
                const still = Object.assign({}, root.pending);
                for (const name in still) {
                    const m = root.outputs.find(o => o.name === name);
                    if (m) {
                        const s = still[name];
                        const cur = root.specFor(m);
                        if (s.mode === cur.mode && s.position === cur.position && Math.abs(s.scale - cur.scale) < 0.001 && s.transform === cur.transform && s.vrr === cur.vrr)
                            delete still[name];
                    } else {
                        delete still[name];
                    }
                }
                root.pending = still;
            }
        }
    }

    Timer {
        id: settle

        interval: 400
        onTriggered: {
            root.refresh();
            // The catch-up, scheduled here rather than bound to `settle.running`:
            // that binding stopped this timer the moment settle fired, with most
            // of the interval still on its clock, and a poll that cannot fire
            // catches nothing.
            late.restart();
        }
    }

    Timer {
        id: late

        interval: 800
        onTriggered: root.refresh()
    }

    // A CABLE MOVED. Plug events change everything the page draws -- the
    // canvas, the mode lists, which outputs exist -- and the compositor's
    // event arrives before its JSON would say anything useful, so the poll
    // waits a moment for the dust rather than racing it.
    Connections {
        target: Hyprland

        function onMonitorAdded(): void {
            settle.restart();
        }

        function onMonitorRemoved(): void {
            settle.restart();
        }
    }

    // A reload by any hand -- the user's own, the monitors page's write
    // chain, another tool -- is the file having its say again, and the poll
    // exists to catch up with exactly that.
    Connections {
        target: Hypr

        function onConfigReloaded(): void {
            root.refresh();
        }
    }

    Component.onCompleted: root.refresh()
}
