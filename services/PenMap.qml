pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config

// WHERE THE DRAWING TABLET POINTS, and the fact that the person holding the pen
// is the one who decides.
//
// A tablet is an ABSOLUTE device. Its surface maps corner to corner onto
// whatever region it is aimed at, so the mapping is not a preference, it is the
// geometry of the instrument: point a 224x148mm surface at a 5120x1440 panel and
// a circle comes out 2.35 times too wide, and the pen crosses a metre of glass
// for a centimetre of wrist. ~/.config/hypr/lua/input.lua already computes one
// good region for this desk and writes it into the compositor's config, which is
// the right place for a mapping that never changes. This service exists because
// the mapping DOES change: the drawing is on the left screen, then it is on the
// right one, then it wants the middle third of the ultrawide, and editing a Lua
// file and reloading the compositor is not a thing anybody does mid-stroke.
//
// SO THE TABLET REMAPS ITSELF, FROM ITSELF. Hold a pad button, an outline
// appears over the region, push it around with the pen, let go. The hand never
// leaves the tablet and the keyboard is never touched, which is the whole point:
// reaching for a mouse to fix where the pen points is the exact interruption the
// feature removes.
//
// THIS FILE OWNS THE RECTANGLE, and nothing else does. modules/pen/ draws an
// outline and reports where the pen dragged it to; every question about whether
// that is a legal place for it, which monitor it belongs to, what shape it is
// allowed to be and how any of it is spelled to the compositor is answered here.
// The overlay calls proposeRegion() and reads `region`, and that is the entire
// contract between them. Two reasons, and the second is the load-bearing one:
// the overlay is per screen and a region can be dragged onto a screen the
// overlay instance holding the pen is not on, so no single overlay is in a
// position to answer "which monitor is this on"; and the rectangle outlives the
// overlay, because it has to be re-pushed at times when nothing is on screen at
// all (see the reload below). That is the definition of a service, DESIGN.md 8.
//
// NOT services/Tablet.qml, which is about the laptop's HINGE, the fold-over
// switch, and shares nothing with this but a word. The two are deliberately not
// merged and deliberately not named alike.
//
// WHAT IT TALKS TO, and why each one:
//
//   THE PAD, through scripts/pen-pad.py. The ExpressKeys are not keyboard keys.
//   The compositor swallows them as tablet-pad input, no Hyprland bind fires on
//   one, and no socket event mentions them, so the evdev node is the only place
//   a pad press exists as something a shell can hear. QML cannot read evdev, so
//   a python process does the reading and narrates it on stdout. The PEN needs
//   none of this: Hyprland forwards the stylus to surfaces as ordinary pointer
//   input, so a MouseArea in the overlay already sees the tip and the barrel.
//
//   THE COMPOSITOR, through `hyprctl eval`. Hyprland 0.56 made its config
//   parser Lua and `hyprctl keyword` died with it ("keyword can't work with
//   non-legacy parsers. Use eval."), so a runtime device setting is now a Lua
//   expression: hl.device({ name = ..., output = ..., region_position = {x,y},
//   region_size = {w,h} }). The fields are FLAT, there is no nested tablet
//   sub-table, a vec2 must be a two-number array or the string "x y" and never
//   {x=,y=}, and successive calls MERGE per key rather than resetting what they
//   do not mention. A process rather than a dispatch because `eval` answers,
//   and the answer is the only way to find out that the expression was wrong.
//
// AND EVERYTHING IT PUSHES IS WIPED BY `hyprctl reload`, which is the single
// fact that decides the shape of the rest of this file. A reload puts input.lua
// back over anything eval set, so the mapping somebody just spent a gesture
// choosing silently reverts, and it reverts at the moment least likely to be
// connected to a cause: some other config edit, hours later. services/Hypr.qml
// already hears `configreloaded` off the event socket and already re-pushes its
// own keywords there for the same reason, so this subscribes to that signal and
// pushes again too. Without it the feature works perfectly and then quietly
// stops having worked.
//
// AND THE PERSISTENCE IS THE SAME ARGUMENT ONE LEVEL OUT. The shell restarting
// is a reload the compositor did not send, so the region is written to
// ~/.local/state/banditshell/penmap.json and applied again at startup.
//
// TAKING OWNERSHIP IS ONE-WAY, and it is worth being honest about. There is no
// way to ask Hyprland what its config file said about a device, only to
// overwrite it, so the first time the editor opens, this service becomes the
// authority on the mapping for the rest of the session and every session after.
// The default region below is computed exactly the way input.lua computes its
// one, so on a machine set up like this one that first handover changes nothing
// at all, which is what makes it acceptable.
Singleton {
    id: root

    // ------------------------------------------------------------------
    // The public face, frozen. modules/pen/ is written against these names
    // and shapes, so they are not this file's to change.
    //
    // Every one of them is a read-only view onto a writable property below.
    // The alternative, a plain writable property, would let a widget assign
    // the rectangle directly and skip the clamping and the re-homing, which
    // is the one thing this service exists to make impossible.
    // ------------------------------------------------------------------

    // IS THE EDITOR UP. True between the pad button going down and it coming
    // back up, which is also exactly the window in which the tablet is unbound
    // and the region on screen is provisional.
    readonly property bool active: root.editing

    // IS THE REGION SHAPE-LOCKED to the tablet's own aspect.
    readonly property bool aspectLocked: root.locked

    // THE TABLET'S OWN ASPECT, width over height, from the surface millimetres
    // in the config. The units cancel, so what is in the config file can be
    // whatever the number on the box was.
    readonly property real surfaceAspect: {
        const surface = Config.values.pen.surface;
        const w = Number(surface?.width);
        const h = Number(surface?.height);
        // A config edited down to zero must not turn every later division into
        // an Infinity that then propagates into a rectangle. Square is a
        // nonsense answer, but it is a nonsense answer that still draws.
        return w > 0 && h > 0 ? w / h : 1;
    }

    // WHICH OUTPUT THE REGION IS HOMED TO, by name. The compositor's own name
    // for the screen, HDMI-A-1 and the like, because that is what `hl.device`
    // wants and because a name is the one handle on a monitor that survives
    // unplugging its neighbour (Hyprland renumbers ids in plug order).
    readonly property string monitorName: root.home

    // THE REGION, in GLOBAL LAYOUT COORDINATES, logical pixels.
    //
    // GLOBAL, and this is the deliberate part. The compositor is told a
    // monitor-relative offset and that is what actually gets applied, but the
    // question the editor spends its whole life answering is "which monitor is
    // this on", and that question is meaningless in a frame that already
    // presupposes an answer. In the global frame a drag is one continuous
    // motion across the whole desk and re-homing falls out of the arithmetic;
    // in a monitor-relative frame it would be a discontinuity that something
    // has to detect and special-case. The conversion happens once, in
    // applyRegion, at the moment it is spoken to Hyprland.
    //
    // REALS, not rounded. Rounding here would make a slow drag stutter and
    // would let repeated rounding walk a region a pixel at a time. The
    // rounding happens once, on the way out.
    readonly property rect region: root.mapping

    // IS THE PAD ACTUALLY THERE. The tablet is Bluetooth, so absent is the
    // normal weather rather than an error: it goes when the tablet sleeps, when
    // the machine suspends, and when the battery runs out.
    readonly property bool padConnected: root.padAlive

    // OPEN THE EDITOR.
    //
    // AND UNBIND THE TABLET TO THE WHOLE LAYOUT while it is open, which is the
    // non-obvious half and the half without which the feature does not work at
    // all. The pen can only reach what the tablet is mapped to. Leave the
    // mapping in place and the pen can only reach the inside of the region it
    // is trying to move, so it cannot drag that region onto another screen, and
    // it cannot even follow its own outline out to the edge of the one it is
    // on. Every gesture would be a feedback loop where moving the target moves
    // the reach. Pointed at the entire layout the pen addresses every monitor,
    // one to one, for exactly as long as the button is held.
    function begin(): void {
        if (root.editing)
            return;

        // WHAT CANCEL PUTS BACK. Taken before anything moves, and copied by
        // value: `rect` is a value type in QML, so this is a snapshot rather
        // than a second name for the live rectangle.
        root.before = {
            home: root.home,
            region: root.mapping,
            locked: root.locked
        };

        // THE HANDOVER, and it happens here rather than at commit because it
        // has already happened: the unbind on the next line has overwritten
        // whatever input.lua had to say about this device, and there is no way
        // to read that back. From this instant the region in this file is the
        // mapping, and cancel restores it to what was showing rather than to
        // something the compositor knows and we do not.
        root.mapped = true;
        root.editing = true;
        root.unbind();

        // AND THE SCREENS ARE RE-READ, because the edit is the one moment the
        // answer has to be current: a monitor plugged in, rotated or moved
        // since startup would otherwise be clamped against its old geometry for
        // the whole gesture. It lands a few milliseconds in, well inside the
        // time it takes to press a button and start moving a hand, and until it
        // does the previous answer is used, which is right nearly always.
        root.scanMonitors();
    }

    // APPLY IT FOR REAL, and remember it. The pad button coming back up.
    function commit(): void {
        if (!root.editing)
            return;

        root.editing = false;
        root.applyRegion();
        root.save();
    }

    // PUT IT BACK. Nothing was chosen, so nothing is changed, but the tablet is
    // currently unbound and cannot be left that way: an editor that exits
    // without re-binding leaves the pen addressing the entire desk at 2.35
    // times too wide, which is the broken state the whole feature is about.
    function cancel(): void {
        if (!root.editing)
            return;

        root.editing = false;

        const was = root.before;
        if (was) {
            root.home = was.home;
            root.mapping = was.region;
            root.locked = was.locked;
        }

        // `mapped` is NOT restored, for the reason begin() gives: ownership of
        // the mapping is not something this file can hand back.
        root.applyRegion();
        root.save();
    }

    // SHAPE LOCK ON OR OFF, from the pad button or from the pill in the
    // overlay. Both go through here so the two cannot drift apart.
    function toggleAspect(): void {
        root.locked = !root.locked;

        // SNAPPED NOW rather than on the next drag. Locking is a statement
        // about the rectangle that exists, and a lock that only took effect the
        // next time somebody moved something would leave the outline visibly
        // the wrong shape while claiming to be locked.
        root.proposeRegion(root.mapping.x, root.mapping.y, root.mapping.width, root.mapping.height);

        // Pressed outside an edit it is a decision on its own and lands at
        // once. Pressed inside one it is part of the gesture, and the commit or
        // the cancel at the end of that gesture is what settles it.
        if (!root.editing) {
            if (root.mapped)
                root.applyRegion();
            root.save();
        }
    }

    // WHERE THE OVERLAY WOULD LIKE THE REGION TO BE, in global layout
    // coordinates, and where it is actually allowed to be.
    //
    // The overlay does the arithmetic of the gesture (a drag adds a delta, a
    // corner handle moves one corner) and hands the raw result here without
    // checking any of it. Everything that makes the result legal happens below,
    // in one place, so a move, a resize, a restore from disk and a monitor
    // being unplugged all converge on the same rules instead of each carrying
    // their own copy.
    //
    // IN ORDER, and the order matters:
    //
    //   1. WHICH MONITOR. Asked of the proposal, not of the old region, which
    //      is what makes dragging onto another screen re-home rather than fail.
    //   2. THE SHAPE, if locked.
    //   3. THE SIZE, capped to that monitor.
    //   4. THE POSITION, clamped so no edge hangs off it.
    //
    // Size before position, because clamping a position against a size that is
    // about to change is clamping against the wrong rectangle.
    function proposeRegion(x: real, y: real, w: real, h: real): void {
        let px = x;
        let py = y;
        // A resize drag can hand back a negative extent when the pen crosses
        // the anchor corner. The overlay is responsible for keeping the corner
        // under the pen, so what arrives here is a magnitude either way.
        let pw = Math.abs(w);
        let ph = Math.abs(h);

        // A number that is not a number, from a division by a zero somewhere
        // upstream. Refused rather than propagated: a NaN in a rect draws
        // nothing, and it draws nothing forever, because every subsequent
        // proposal is computed from it.
        if (!isFinite(px) || !isFinite(py) || !isFinite(pw) || !isFinite(ph))
            return;

        const mon = root.homeFor(px, py, pw, ph);
        if (!mon) {
            // NO SCREENS TO CLAMP AGAINST, which happens for the few
            // milliseconds before the first `hyprctl -j monitors` lands and on
            // a compositor this file cannot ask. Taking the proposal whole is
            // wrong in principle and right in practice: the alternative is an
            // outline frozen under a moving pen, and the next scan re-proposes
            // and puts it right.
            root.mapping = Qt.rect(px, py, pw, ph);
            return;
        }

        const aspect = root.surfaceAspect;
        const floor = Math.max(1, Number(Config.values.pen.minSize) || 1);

        if (root.locked) {
            // ONE NUMBER, NOT TWO. Locked, the region is a point on the ray
            // (aspect*t, t), so the whole of its size is the scalar t and every
            // constraint below is an interval on it. That is also what makes
            // "shrink to fit rather than distort" fall out rather than being a
            // special case: there is no way to express a distortion.
            //
            // THE PROJECTION, and not the width or the height or their
            // geometric mean. A corner drag hands us a pen position that is
            // almost never on the ray, and the honest answer to "which legal
            // rectangle did they mean" is the nearest one, which is the
            // perpendicular projection of (pw, ph) onto that ray. It has the
            // property the hand actually notices: the corner tracks the pen as
            // closely as the constraint allows, and pulling along either axis
            // grows both. A proposal that is already the right shape projects
            // onto itself, so this is a no-op for a plain move.
            let t = (pw * aspect + ph) / (aspect * aspect + 1);

            // THE MONITOR WINS OVER THE FLOOR, which is what taking the min
            // last says: a screen too small to hold the minimum region gets the
            // biggest one it can hold instead of one that hangs off the edge.
            const ceiling = Math.min(mon.h, mon.w / aspect);
            t = Math.min(Math.max(t, Math.max(floor, floor / aspect)), ceiling);

            pw = t * aspect;
            ph = t;
        } else {
            pw = Math.min(Math.max(pw, floor), mon.w);
            ph = Math.min(Math.max(ph, floor), mon.h);
        }

        px = root.clamp(px, mon.x, mon.x + mon.w - pw);
        py = root.clamp(py, mon.y, mon.y + mon.h - ph);

        root.home = mon.name;
        root.mapping = Qt.rect(px, py, pw, ph);
    }

    // ------------------------------------------------------------------
    // The state behind that face.
    // ------------------------------------------------------------------

    property bool editing: false
    property rect mapping
    property string home: ""

    // THE LOCK, BOUND TO THE CONFIG UNTIL SOMEBODY DECIDES OTHERWISE.
    //
    // Left as a binding it follows `pen.aspectLock`, which is what a machine
    // that has never been asked should do. Assigning it, from the pad button or
    // from the state file, breaks the binding, which is exactly right: the
    // config key is the DEFAULT and the user's last answer beats it. It also
    // sidesteps a race that would otherwise be real, since Config's file and
    // this one's both arrive asynchronously and in either order: whichever way
    // round they land, an answer read off disk has broken the binding by the
    // time the config could re-evaluate it.
    property bool locked: Config.values.pen.aspectLock

    property bool padAlive: false

    // DOES THIS SERVICE OWN THE MAPPING YET. False on a machine where nobody
    // has ever opened the editor and no state file exists, and while it is
    // false nothing here pushes anything: the compositor's own config block is
    // left entirely alone, so installing the shell does not silently take over
    // a mapping somebody wrote by hand. See begin() for why it is one-way.
    property bool mapped: false

    // What cancel() puts back: {home, region, locked} as of the last begin().
    property var before: null

    // THE SCREENS, in LOGICAL layout pixels: [{name, x, y, w, h, focused}].
    //
    // Read from `hyprctl -j monitors` rather than from Quickshell's
    // HyprlandMonitor, and the reason is a field that model does not carry.
    // Hyprland reports `width`/`height` as the MODE, before the transform, so a
    // screen at transform 1 reports 1920x1200 while occupying 1200x1920 of the
    // layout. DP-1 on this desk is exactly that, which is why HDMI-A-1 sits at
    // x=1200 and not at x=1920. HyprlandMonitor exposes width, height and scale
    // but not transform, and its `lastIpcObject`, which does carry it, is
    // explicitly documented as not updating on its own. So the JSON is read
    // here and the logical footprint is computed from all three.
    property var monitors: []

    property bool monitorsKnown: false
    property bool stateKnown: false
    property bool settled: false

    // THE LAYOUT AS ONE STRING, so that "did anything move" is a comparison
    // rather than a walk. Kept from the last scan that produced a usable list.
    property string layoutSeen: ""

    // DID THE LAST SCAN FIND A DIFFERENT DESK from the one before it.
    property bool layoutMoved: false

    // MUST THE NEXT SCAN SPEAK TO THE COMPOSITOR whatever it finds.
    //
    // Set only by the reload, and the reason is the asymmetry between the two
    // things that ask for a scan. A monitor moving changes the geometry, so
    // "nothing changed" honestly means there is nothing to say. A reload
    // changes nothing HERE and everything THERE: the region is identical and
    // the compositor has just forgotten it, so that is exactly the case where
    // an unchanged scan still has to push. Getting this backwards would leave
    // the feature working perfectly until the first reload and silently not
    // afterwards, which is the failure this whole path exists to prevent.
    property bool pushAnyway: false

    // The mapping as the state file gave it, monitor-relative, held until there
    // are screens to resolve it against.
    property var stored: null

    // ------------------------------------------------------------------
    // Geometry.
    // ------------------------------------------------------------------

    function clamp(v: real, lo: real, hi: real): real {
        // A high bound below the low one means the region is wider than the
        // screen, which the size cap should already have prevented. Pinning to
        // the low edge keeps the top-left on the monitor, which is the half of
        // the rectangle somebody can still grab.
        if (hi < lo)
            return lo;
        return v < lo ? lo : v > hi ? hi : v;
    }

    function monitorNamed(name: string): var {
        return root.monitors.find(m => m.name === name) ?? null;
    }

    // WHICH SCREEN A PROPOSED RECTANGLE BELONGS TO. Three questions, asked in
    // descending order of how well they match what a hand thinks it is doing.
    function homeFor(x: real, y: real, w: real, h: real): var {
        const mons = root.monitors;
        if (!mons.length)
            return null;

        const cx = x + w / 2;
        const cy = y + h / 2;

        // 1. THE ONE UNDER THE MIDDLE OF IT. The predictable rule, and the one
        //    a person can feel: the region changes screen when its centre
        //    crosses, which is halfway, which is where a drag feels like it
        //    has committed.
        for (const m of mons)
            if (cx >= m.x && cx < m.x + m.w && cy >= m.y && cy < m.y + m.h)
                return m;

        // 2. THE ONE IT OVERLAPS MOST. The centre can be nowhere at all: two
        //    screens of different heights leave dead layout between them, and a
        //    region dragged through that gap must still belong somewhere.
        let best = null;
        let bestArea = 0;
        for (const m of mons) {
            const ox = Math.max(0, Math.min(x + w, m.x + m.w) - Math.max(x, m.x));
            const oy = Math.max(0, Math.min(y + h, m.y + m.h) - Math.max(y, m.y));
            if (ox * oy > bestArea) {
                bestArea = ox * oy;
                best = m;
            }
        }
        if (best)
            return best;

        // 3. THE NEAREST. Nothing overlaps, so the region is entirely off the
        //    desk: a saved rectangle from a layout that has since changed, or a
        //    monitor unplugged out from under it. It gets clamped back onto
        //    whichever screen it was closest to, which is the answer least
        //    likely to move it somewhere surprising.
        let near = mons[0];
        let nearD = Infinity;
        for (const m of mons) {
            const dx = cx - (m.x + m.w / 2);
            const dy = cy - (m.y + m.h / 2);
            const d = dx * dx + dy * dy;
            if (d < nearD) {
                nearD = d;
                near = m;
            }
        }
        return near;
    }

    // THE REGION A MACHINE THAT HAS NEVER BEEN ASKED STARTS WITH: the tablet's
    // own aspect, as tall as the focused screen allows, centred on it.
    //
    // It is computed rather than written down for the reason input.lua gives
    // for computing its own: a hardcoded 2179 is a number that silently goes
    // wrong the day the panel or the tablet changes. It is deliberately the
    // SAME computation, so that the first time this service takes the mapping
    // over on a desk configured like this one, nothing visibly happens.
    function defaultRegion(): void {
        const mon = root.monitors.find(m => m.focused) ?? root.monitors[0];
        if (!mon)
            return;

        const aspect = root.surfaceAspect;
        let h = mon.h;
        let w = h * aspect;
        // A screen wider than it is tall usually gives full height. A portrait
        // one does not, so the other axis binds instead. Which one it is falls
        // out of the numbers rather than out of a branch on the monitor.
        if (w > mon.w) {
            w = mon.w;
            h = w / aspect;
        }

        root.home = mon.name;
        root.proposeRegion(mon.x + (mon.w - w) / 2, mon.y + (mon.h - h) / 2, w, h);
    }

    // ------------------------------------------------------------------
    // Talking to the compositor.
    // ------------------------------------------------------------------

    // A LUA STRING LITERAL, quoted and escaped.
    //
    // Everything that goes into one of these comes from the config file, which
    // is to say from a human with a text editor, and a device name with a quote
    // in it would otherwise end the literal and leave the rest of the
    // expression as a syntax error the compositor reports and nothing reads.
    function luaString(s: string): string {
        return `"${String(s).replace(/\\/g, "\\\\").replace(/"/g, "\\\"")}"`;
    }

    // ONE hl.device CALL, addressed to the stylus, carrying whatever fields the
    // caller wants set. Everything device-specific about the address is in the
    // config, so this file never spells out what kind of tablet it is talking
    // to. Successive calls MERGE per key, which is why every call below states
    // every field it cares about rather than trusting what the last one left.
    function evalDevice(fields: string): void {
        root.evalLua(`hl.device({ name = ${root.luaString(Config.values.pen.device)}, ${fields} })`);
    }

    // POINT THE TABLET AT THE WHOLE LAYOUT. `output = ""` unbinds it from any
    // one screen and `region_size = {0,0}` means unset, which is to say the
    // whole of what it is bound to.
    //
    // `absolute_region_position` is stated explicitly even though it is only
    // consulted when the output is empty, which is precisely the case this call
    // creates. A merge keeps whatever a config block last said, so a machine
    // whose input.lua turned it on would otherwise have this call's {0,0}
    // interpreted as a global offset by a compositor that had not been told
    // otherwise.
    function unbind(): void {
        root.evalDevice(`output = "", absolute_region_position = false, region_position = {0,0}, region_size = {0,0}`);
    }

    // THE REGION, SPOKEN THE WAY HYPRLAND WANTS TO HEAR IT.
    //
    // THIS IS THE CONVERSION, and it is the one piece of arithmetic in the file
    // that is easy to get silently wrong. `region` is global. With `output`
    // set, `region_position` is an offset from THAT MONITOR's top-left, in
    // logical pixels, and `absolute_region_position` is ignored entirely. So
    // the monitor's own origin comes off first. Get it wrong on a single-screen
    // desk whose layout starts at 0,0 and the two frames are identical and the
    // bug is invisible; get it wrong here, where the ultrawide starts at
    // (1200,240), and the mapping lands 1200 pixels and 240 lines away.
    //
    // ROUNDED, once, here. The compositor takes integers, and the rectangle is
    // kept in reals right up to this point so that repeated rounding cannot
    // walk it.
    function applyRegion(): void {
        if (!root.mapped)
            return;

        const mon = root.monitorNamed(root.home);
        if (!mon) {
            // The screen went away between the region being chosen and it being
            // pushed. Saying nothing leaves the tablet on its previous mapping,
            // which is stale but usable; guessing a different monitor would
            // move the pen somewhere nobody asked for.
            console.warn(`PenMap: no monitor named "${root.home}" is connected, so the mapping was not applied.`);
            return;
        }

        const rx = Math.round(root.mapping.x - mon.x);
        const ry = Math.round(root.mapping.y - mon.y);
        const rw = Math.max(1, Math.round(root.mapping.width));
        const rh = Math.max(1, Math.round(root.mapping.height));

        root.evalDevice(`output = ${root.luaString(mon.name)}, region_position = {${rx},${ry}}, region_size = {${rw},${rh}}`);
    }

    // The expression waiting for the process to be free. ONE, not a queue: each
    // of these states the mapping in full rather than adjusting the last one,
    // so when two land close together the older one has nothing left to say.
    property string queued: ""

    function evalLua(expr: string): void {
        // A different compositor has no `hyprctl` to run, and spawning one per
        // gesture to watch it fail is worse than doing nothing. The overlay and
        // the pad reader still work; only the push is silently skipped.
        if (!Compositor.isHyprland)
            return;

        if (applier.running) {
            root.queued = expr;
            return;
        }
        root.runLua(expr);
    }

    function runLua(expr: string): void {
        applier.command = ["hyprctl", "eval", expr];
        applier.running = true;
    }

    Process {
        id: applier

        // ARGV, NOT A SHELL. The expression is a Lua table full of braces,
        // quotes and commas built from strings a human typed into a config
        // file, and handing that to `sh -c` would put three levels of quoting
        // between here and the compositor. Passed as a single argument there is
        // no shell to quote for at all.
        stdout: StdioCollector {
            onStreamFinished: {
                const answer = text.trim();
                // "ok" is the whole of a successful answer. Anything else is
                // real and worth a line, because this is the ONLY place a bad
                // expression ever shows up: a device name that matches nothing
                // is accepted in silence, and a malformed one comes back as
                // "error: [string ...]" that nothing else would read.
                if (answer && answer !== "ok")
                    console.warn(`PenMap: hyprctl eval answered "${answer}".`);
            }
        }

        stderr: StdioCollector {
            onStreamFinished: if (text.trim())
                console.warn(`PenMap: hyprctl eval: ${text.trim()}`)
        }

        onExited: if (root.queued) {
            const next = root.queued;
            root.queued = "";
            root.runLua(next);
        }
    }

    // ------------------------------------------------------------------
    // The screens.
    // ------------------------------------------------------------------

    property bool scanAgain: false

    function scanMonitors(): void {
        // A Process cannot be re-commanded while it is running, and the things
        // that ask for a scan (a reload, a monitor arriving, a button going
        // down) arrive in bursts. The last one is remembered and goes out when
        // the current one is done, the same way Hypr.applyBands queues its own.
        if (monScan.running) {
            root.scanAgain = true;
            return;
        }
        monScan.running = true;
    }

    Process {
        id: monScan

        command: ["hyprctl", "-j", "monitors"]

        stdout: StdioCollector {
            onStreamFinished: root.readMonitors(text)
        }

        onExited: {
            if (root.scanAgain) {
                root.scanAgain = false;
                return root.scanMonitors();
            }
            root.afterScan();
        }
    }

    function readMonitors(text: string): void {
        let raw = [];
        try {
            raw = JSON.parse(text);
        } catch (e) {
            // hyprctl comes back empty or half-written while the compositor is
            // starting or dying, the same tolerance Hypr's own monitor seed
            // takes. The previous list is kept and the next scan corrects it.
        }
        if (!Array.isArray(raw))
            raw = [];

        const next = [];
        for (const m of raw) {
            if (!m || !m.name || m.disabled === true)
                continue;

            const scale = typeof m.scale === "number" && m.scale > 0 ? m.scale : 1;

            // THE QUARTER TURNS ARE THE ODD ONES. Hyprland's transform is the
            // Wayland enum: 0/2/4/6 leave the axes alone, 1/3/5/7 are the 90
            // and 270 degree turns with and without a flip, and those are the
            // ones whose reported mode has to be read the other way round.
            // Odd-or-even rather than a list of four, because it is a fact
            // about the enum and not four coincidences.
            const turned = Number(m.transform) % 2 === 1;
            const w = (turned ? m.height : m.width) / scale;
            const h = (turned ? m.width : m.height) / scale;
            if (!(w > 0) || !(h > 0))
                continue;

            next.push({
                name: m.name,
                x: Number(m.x) || 0,
                y: Number(m.y) || 0,
                w: w,
                h: h,
                focused: m.focused === true
            });
        }

        // AN EMPTY ANSWER IS NOT AN ANSWER. A machine genuinely has at least
        // one screen while this shell is drawing on it, so nothing here means
        // the read failed, and replacing a good list with an empty one would
        // make every proposal fall through to the no-screens branch.
        root.layoutMoved = false;
        if (!next.length)
            return;

        // THE SAME DESK, WORD FOR WORD. Most scans find nothing new: the
        // watcher below fires on any monitor property Quickshell notices, and
        // the answer is usually the geometry that was already here. Saying so
        // is what keeps a shell start down to one push instead of two.
        const seen = next.map(m => `${m.name}@${m.x},${m.y}+${m.w}x${m.h}`).join("|");
        root.layoutMoved = seen !== root.layoutSeen;
        root.layoutSeen = seen;

        root.monitors = next;
        root.monitorsKnown = true;
    }

    // WHAT A FRESH SET OF SCREENS MEANS, whichever of the reasons for scanning
    // brought us here. All of them converge on this, so a reload, a monitor
    // being plugged in and the editor opening are one code path with one set of
    // consequences rather than three that have to be kept in agreement.
    function afterScan(): void {
        const forced = root.pushAnyway;
        root.pushAnyway = false;

        if (!root.settled)
            return root.settle();

        // A SCAN THAT FOUND THE DESK IT LEFT, AND NOBODY ASKING FOR A PUSH, has
        // nothing to do. The region is already clamped against these exact
        // screens and the compositor is already holding it.
        if (!forced && !root.layoutMoved)
            return;

        // THE SCREENS MOVED UNDER THE REGION. Re-proposing re-homes it and
        // re-clamps it against whatever is there now, which is the whole of
        // what "a monitor was unplugged" has to mean to this file.
        root.proposeRegion(root.mapping.x, root.mapping.y, root.mapping.width, root.mapping.height);

        // AND THE COMPOSITOR IS TOLD AGAIN. This is the re-push that survives
        // `hyprctl reload`, arriving here because configReloaded asks for a
        // scan: the mapping has just been wiped back to input.lua's, and the
        // fresh geometry is exactly what the re-push needs anyway. Mid-edit the
        // right thing to restate is the unbind, not the region, because the
        // region on screen is still provisional.
        if (root.editing)
            root.unbind();
        else
            root.applyRegion();
    }

    // ------------------------------------------------------------------
    // Remembering it.
    // ------------------------------------------------------------------

    // The directory AppIcons and Usage already write, so the shell's memory
    // lives in one place.
    readonly property string stateDir: `${Quickshell.env("HOME")}/.local/state/banditshell`
    readonly property string statePath: `${root.stateDir}/penmap.json`

    // WRITTEN MONITOR-RELATIVE, which is the opposite of how it is held in
    // memory and is deliberate.
    //
    // A saved mapping is a fact about a screen: "the middle third of the
    // ultrawide". Saved globally it would be a fact about a LAYOUT, so
    // rearranging the desk, or plugging the second monitor in on the other
    // side, would leave a rectangle whose absolute coordinates now describe a
    // different screen or no screen at all. Saved against its output's name and
    // origin it follows that screen wherever the layout puts it, which is what
    // somebody who moved a monitor would expect. It is also exactly the form
    // the compositor is told, so the file is a faithful record of the mapping
    // rather than a second encoding of it.
    function save(): void {
        const out = {
            aspectLocked: root.locked
        };

        const mon = root.mapped ? root.monitorNamed(root.home) : null;
        if (mon) {
            out.monitor = mon.name;
            out.x = Math.round(root.mapping.x - mon.x);
            out.y = Math.round(root.mapping.y - mon.y);
            out.width = Math.round(root.mapping.width);
            out.height = Math.round(root.mapping.height);
        }

        store.setText(JSON.stringify(out, null, 4) + "\n");
    }

    // WHAT THE FILE SAID, taken a field at a time and none of it on faith.
    // State files get truncated by full disks and edited by hand, and the
    // failure mode worth avoiding is not an exception, it is a rectangle made
    // of undefined that then propagates into everything computed from it.
    function absorb(data: var): void {
        if (!data || typeof data !== "object")
            return;

        if (typeof data.aspectLocked === "boolean")
            root.locked = data.aspectLocked;

        const name = typeof data.monitor === "string" ? data.monitor : "";
        const nums = [data.x, data.y, data.width, data.height].map(Number);
        // A region needs all four, all finite, and a positive extent. Anything
        // less is not a partially usable region, it is no region, and the
        // machine starts as though it had never been asked.
        if (!name || nums.some(n => !isFinite(n)) || !(nums[2] > 0) || !(nums[3] > 0))
            return;

        root.stored = {
            monitor: name,
            x: nums[0],
            y: nums[1],
            width: nums[2],
            height: nums[3]
        };
    }

    // BOTH ANSWERS, ONCE. The screens and the file arrive asynchronously and in
    // either order, and neither is usable alone: a saved rectangle is
    // monitor-relative so it cannot be placed without the screens, and the
    // screens cannot be clamped against without knowing whether there is a
    // saved rectangle to clamp. Whichever lands second calls this.
    function settle(): void {
        if (root.settled || !root.monitorsKnown || !root.stateKnown)
            return;
        root.settled = true;

        const s = root.stored;
        const mon = s ? root.monitorNamed(s.monitor) : null;

        if (s && mon) {
            root.mapped = true;
            root.home = mon.name;

            // PINNED TO THE SCREEN THE FILE NAMED, before the general rules get
            // a say. The saved offset was legal against the geometry that
            // screen had when it was written, and a screen can change
            // resolution without changing its name: swap the ultrawide from
            // 5120 wide to 1920 and a saved offset of 2941 now describes a
            // point past its right edge. Handed to homeFor as it stands, a
            // rectangle that overlaps nothing falls through to "nearest", and
            // the nearest screen to somewhere off the right of this desk is the
            // OTHER one. The mapping would silently move to a monitor the file
            // never mentioned.
            //
            // Nudging it inside the named monitor first makes its centre land
            // there, so homeFor's first question answers itself and every rule
            // below still runs normally. Only the starting point is decided
            // here; the clamping and the shape are still proposeRegion's.
            const w = Math.min(s.width, mon.w);
            const h = Math.min(s.height, mon.h);
            root.proposeRegion(mon.x + root.clamp(s.x, 0, mon.w - w), mon.y + root.clamp(s.y, 0, mon.h - h), s.width, s.height);

            root.applyRegion();
            return;
        }

        if (s)
            console.warn(`PenMap: the saved mapping is on "${s.monitor}", which is not connected; starting from the focused screen instead.`);

        // NOTHING SAVED, SO NOTHING PUSHED. The outline has somewhere sensible
        // to appear the first time the button is held, and until it is held the
        // compositor's own device block is the mapping and is untouched.
        root.defaultRegion();
    }

    FileView {
        id: store

        path: root.statePath
        printErrors: false

        onLoaded: {
            let data = null;
            try {
                data = JSON.parse(text());
            } catch (e) {
                // NOT REFUSED TO WRITE OVER, unlike Usage's log. That file is a
                // year of history that a bad parse might still be hiding;
                // this one is a rectangle somebody can redraw with one gesture,
                // and refusing to save would mean the next gesture silently
                // failed to stick as well.
                console.warn(`PenMap: ${root.statePath} is not valid JSON; starting from the defaults and overwriting it on the next commit.`, e);
            }

            root.absorb(data);
            root.stateKnown = true;
            root.settle();
        }

        onLoadFailed: err => {
            // No file is simply a machine this feature has not been used on.
            // The directory is made now rather than at save time, so the first
            // commit does not have to wait on a process before it can write.
            if (err === FileViewError.FileNotFound)
                mkdir.running = true;
            else
                console.warn(`PenMap: could not read ${root.statePath} (${err}); starting from the defaults.`);

            root.stateKnown = true;
            root.settle();
        }
    }

    Process {
        id: mkdir

        command: ["mkdir", "-p", root.stateDir]
    }

    // ------------------------------------------------------------------
    // The pad.
    // ------------------------------------------------------------------

    function startPad(): void {
        if (pad.running)
            return;

        // SET HERE RATHER THAN BOUND, because a binding would re-command the
        // process every time the config file was written, and a Process cannot
        // be re-commanded while it runs. The name is therefore read at start:
        // pointing `pen.pad` at a different tablet takes effect the next time
        // the reader restarts, which it does every two seconds when the pad it
        // was given is not there.
        pad.command = ["python3", Quickshell.shellPath("scripts/pen-pad.py"), "--device-name", String(Config.values.pen.pad ?? "")];
        pad.running = true;
    }

    // SHOULD THE READER BE RUNNING AT ALL, asked whenever the answer could have
    // changed. Waiting for `Config.loaded` matters here in a way it does not
    // for a setting that is merely read: starting the process on the defaults
    // and killing it a moment later when the user's file says `enabled: false`
    // would spawn a python interpreter on every fleet machine that does not
    // have this tablet, once per shell start, for nothing.
    function syncPad(): void {
        if (Config.loaded && Config.values.pen.enabled === true)
            root.startPad();
        else if (pad.running)
            pad.running = false;
    }

    Connections {
        target: Config

        function onValuesChanged(): void {
            root.syncPad();
        }

        function onLoadedChanged(): void {
            root.syncPad();
        }
    }

    // THE PROTOCOL, one event per line: `ready`, `gone`, `down <code>`,
    // `up <code>`, `ring <value>`. Anything else is ignored in silence rather
    // than warned about, because the reader is allowed to grow a word without
    // this file needing to be edited in the same commit.
    function padLine(line: string): void {
        const words = line.trim().split(/\s+/);
        const verb = words[0];
        if (!verb)
            return;

        if (verb === "ready") {
            root.padAlive = true;
            return;
        }

        if (verb === "gone") {
            root.padAlive = false;

            // A PAD THAT VANISHES MID-EDIT NEVER SENDS THE `up`, and without
            // this the editor would stay open forever with the tablet unbound
            // to the whole layout: the exact broken state the feature exists to
            // fix, entered by the feature itself, and unfixable with the pen
            // because the pad is the only way back out. Bluetooth going away is
            // the normal weather here, so this is not an edge case.
            if (root.editing)
                root.cancel();
            return;
        }

        // THE RING IS READ AND DELIBERATELY UNUSED. The reader narrates the
        // whole pad because that is the honest thing for a device reader to do,
        // and nothing in this interaction has decided what a ring means yet.
        // Named here so that "unhandled" is a decision rather than an oversight.
        if (verb === "ring")
            return;

        if (verb !== "down" && verb !== "up")
            return;

        const code = parseInt(words[1], 10);
        if (!isFinite(code))
            return;

        const cfg = Config.values.pen;

        // HELD, NOT TOGGLED. Down opens the editor and up commits it, so the
        // gesture is one press with a drag inside it and there is no state to
        // get stuck in: let go of everything and the mapping is whatever the
        // outline was showing.
        if (code === cfg.holdButton) {
            if (verb === "down")
                root.begin();
            else
                root.commit();
        } else if (code === cfg.aspectButton && verb === "down") {
            root.toggleAspect();
        }
    }

    Process {
        id: pad

        stdout: SplitParser {
            onRead: line => root.padLine(line)
        }

        stderr: SplitParser {
            // The reader keeps stderr for things genuinely worth a human's
            // attention: a broken python-evdev, or nodes this user is not
            // allowed to read. A missing pad is not one of them, it is `gone`.
            onRead: line => console.warn("PenMap(pad):", line)
        }

        onExited: {
            root.padAlive = false;

            // The reader is written never to exit on its own, so being here at
            // all means something outside it went wrong: no python3, the script
            // gone from the checkout, or it was killed. The feature is dead
            // until it comes back and nothing else would say so, hence the
            // retry; the delay is there so that a script that cannot start
            // fails twice a second forever instead of as fast as fork allows.
            if (root.editing)
                root.cancel();
            padRetry.restart();
        }
    }

    Timer {
        id: padRetry

        interval: 2000
        onTriggered: root.syncPad()
    }

    // ------------------------------------------------------------------
    // Keeping in step with the compositor.
    // ------------------------------------------------------------------

    // WHAT THE LAYOUT LOOKS LIKE, as one string, so that any change to any
    // screen's identity or geometry is one comparison rather than a signal per
    // monitor per field. Built from Quickshell's model, which updates itself,
    // purely as the TRIGGER: the numbers this file actually uses come from the
    // scan it kicks off, because the model cannot say which screens are turned.
    readonly property string layoutKey: Hyprland.monitors.values.map(m => `${m.name}@${m.x},${m.y}+${m.width}x${m.height}*${m.scale}`).join("|")

    onLayoutKeyChanged: layoutSettle.restart()

    Timer {
        id: layoutSettle

        // Monitors arrive in pieces: a screen being plugged in changes its own
        // geometry and then every neighbour's position as the layout reflows,
        // and scanning on each of those is several processes to answer one
        // question. Long enough to let a hotplug finish, short enough to be
        // over before a hand could reach the pen.
        interval: 200
        onTriggered: root.scanMonitors()
    }

    Connections {
        target: Hypr

        // A RELOAD IS A WIPE. `hyprctl reload` re-parses the config and puts
        // input.lua's device block back over anything `eval` set, so the region
        // the user chose is gone and nothing in the shell would otherwise
        // notice. Hypr already hears this event off the event socket and
        // re-pushes its own workspace keywords for exactly the same reason.
        //
        // THROUGH A SCAN rather than straight to applyRegion, because a reload
        // is also the one moment the monitor configuration can have changed:
        // the geometry has to be re-read before the region is clamped against
        // it. afterScan does the push. The mapping is briefly the config's own
        // during the round trip, which is a few milliseconds of the pen being
        // where it used to be.
        function onConfigReloaded(): void {
            root.pushAnyway = true;
            root.scanMonitors();
        }
    }

    Component.onCompleted: {
        root.scanMonitors();
        root.syncPad();
    }
}
