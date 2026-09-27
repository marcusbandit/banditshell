pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.config

// MONITORS: what the compositor thinks of every output, and the one place that
// changes it.
//
// The facts come from `hyprctl -j monitors` rather than from Quickshell's
// own monitor model, and that is not a shortcut taken by accident. The page
// needs three things only the compositor's own JSON carries: the AVAILABLE
// modes (every resolution and refresh the panel can be driven at -- Quickshell
// exposes the current one only), the LAYOUT POSITION (where this output sits
// relative to the others, the thing the arrangement canvas drags), and the
// live vrr and transform flags. One process answers all of it, in both parser
// dialects, because reading is reading.
//
// APPLYING is dialect work, and this is the same split Settings.qml's ruler
// makes: under the Lua parser `keyword` is refused outright, so a monitor
// line is said as `hyprctl eval` running `hl.monitor({...})` -- the very
// function the user's own lua/monitors.lua speaks. Under the legacy parser it
// is `hyprctl keyword monitor ...` in the positional form every example on
// the internet uses. Both spellings live in one function, adjacent, so they
// cannot drift.
//
// A LINE CARRIES THE WHOLE SPEC, never a delta. A monitor line replaces the
// output's configuration wholesale, and a field left off it falls back to the
// default -- so a position-only change sent without `vrr` would silently turn
// VRR off on an output whose config line turned it on. Every apply therefore
// builds the full current spec and merges the requested fields into it, and
// the SAME merged spec is what gets persisted.
//
// PERSISTENCE LIVES IN THE SHELL'S OWN CONFIG, as the `monitors` block: one
// entry per output the shell has ever been asked to change, each the full
// spec, re-applied on top of the user's config at startup and after every
// compositor reload. The division of labour is the one the rest of the shell
// already practises: lua/monitors.lua is the user's hand-written baseline and
// stays byte-for-byte theirs, and what the UI changes is an override layer the
// shell owns, applied after the baseline has had its say. Hand-editing the Lua
// file still works; the overrides win because they are applied later, and the
// page says so by always drawing the compositor's live state rather than
// anything it remembers.
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

    // The persisted layer, straight from the shell's config. A map the UI
    // writes whole and reads whole: `Config.set` replaces by key, so per-field
    // writes would be three saves of one decision.
    readonly property var overrides: Config.values.monitors ?? ({})

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

    // THE ONE APPLY, for a full spec. Runtime first, then the persisted layer,
    // then the compositor is re-asked for the truth it actually settled on.
    function applySpec(spec: var): void {
        if (!spec?.output)
            return;

        root.pending = Object.assign({}, root.pending, {
            [spec.output]: spec
        });

        const q = JSON.stringify(spec.output);

        if (Hypr.lua)
            applier.exec(["hyprctl", "eval", `(function() hl.monitor({ output = ${q}, mode = ${JSON.stringify(spec.mode)}, position = ${JSON.stringify(spec.position)}, scale = ${spec.scale}, transform = ${spec.transform}, vrr = ${spec.vrr} }) end)()`]);
        else
            applier.exec(["hyprctl", "keyword", "monitor", `${spec.output},${spec.mode},${spec.position},${spec.scale},transform,${spec.transform},vrr,${spec.vrr}`]);

        // The override is the WHOLE spec, written whole: what the shell
        // re-applies at startup must be exactly what it just applied, not the
        // fields that happened to change this time.
        const next = Object.assign({}, root.overrides);
        next[spec.output] = spec;
        Config.set("monitors", next);

        // The compositor may refuse, round, or reposition; the poll is the
        // page's source of truth, and it runs after the dispatch has had its
        // exit and again after the mode change has had time to land.
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

    // Startup and reload: the persisted layer, on top of whatever the user's
    // own config just did. Gated on the parser being KNOWN, not on it being
    // Lua -- the legacy branch of applySpec is a real answer, and "asking"
    // is not a reason to send nothing.
    function applyOverrides(): void {
        root.overridesLanded = true;

        for (const name in root.overrides) {
            const spec = root.overrides[name];
            // Only outputs that are there: a reservation in config.json for a
            // monitor in a cupboard must not fail the whole sweep, and one
            // refused line says so in the log without stopping the rest.
            if (root.outputs.some(m => m.name === name))
                root.applySpec(Object.assign({}, spec, {
                    output: name
                }));
        }
    }

    // THE POLL. `hyprctl` can come back empty or half-written while the
    // compositor is starting; a failed poll leaves the last truth standing
    // and the next one corrects it, exactly the tolerance Hypr.qml's own
    // monitor seed takes.
    function refresh(): void {
        probe.running = true;
    }

    // Once per boot: the first good poll is the trigger for the persisted
    // layer, because Component.onCompleted has an empty `outputs` to apply
    // overrides ONTO. After it is true, polls apply nothing -- a poll that
    // re-applied would be a service fighting the changes it exists to serve.
    property bool overridesLanded: false

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

                if (!root.overridesLanded) {
                    root.overridesLanded = true;
                    root.applyOverrides();
                }
            }
        }
    }

    // Applied lines are followed by the truth. Two hops: the first reads what
    // the dispatch immediately did, the second catches the mode change that
    // lands a frame or two later.
    Process {
        id: applier

        onExited: settle.restart()
    }

    Timer {
        id: settle

        interval: 400
        onTriggered: root.refresh()
    }

    Timer {
        interval: 1200
        running: settle.running
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

    // The user's own config re-ran its monitor lines; the overrides win by
    // being later, and here is later.
    Connections {
        target: Hypr

        function onConfigReloaded(): void {
            root.applyOverrides();
            root.refresh();
        }
    }

    Component.onCompleted: root.refresh()

    // And after the parser has answered, for the boot where the overrides
    // were applied before anyone knew which spelling to say them in.
    Connections {
        target: Hypr

        function onParserKnownChanged(): void {
            root.applyOverrides();
        }
    }
}
