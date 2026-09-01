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
// SO THE TABLET REMAPS ITSELF, FROM ITSELF. Press a pad button, an outline
// appears over the region, push it around with the pen, press the same button
// again and it is applied. The hand never leaves the tablet and the keyboard is
// never touched, which is the whole point: reaching for a mouse to fix where the
// pen points is the exact interruption the feature removes.
//
// A TOGGLE RATHER THAN A HOLD, and that is a correction rather than a
// preference. Held was the obvious shape and it works on a pad whose contacts
// are clean. This one's are not: BTN_0 chatters, and a contact that lets go for
// six milliseconds in the middle of a drag reads as a release, which under a
// hold meant the mapping was committed halfway through a move with the pen
// still down and the hand still going. So the button now only ever means "the
// other thing": press to open, press to apply. The release edge carries nothing
// at all, which removes the event a bad contact was inventing. What chatter can
// still invent is a second PRESS, and that is what the debounce in padLine is
// for; it is the one piece of this file that exists because of the hardware
// rather than because of the geometry.
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

    // IS THE EDITOR UP. True between the press that opened it and the press
    // that applies it, which is also exactly the window in which the tablet is
    // unbound and the region on screen is provisional.
    readonly property bool active: root.editing

    // IS THE REGION SHAPE-LOCKED to the tablet's own aspect.
    readonly property bool aspectLocked: root.locked

    // IS THE SECOND PRESS GOING TO TAKE A WINDOW rather than the rectangle the
    // pen has been pushing around. Persisted beside the shape lock, because it
    // is the same kind of answer: a standing decision about how the editor
    // behaves rather than a fact about any one gesture.
    readonly property bool followWindow: root.following

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

    // THE WINDOW UNDER THE PEN, in the same GLOBAL layout coordinates `region`
    // is in, and an EMPTY rect when there is not one.
    //
    // EMPTY IS THE ORDINARY ANSWER rather than a failure, and it is worth
    // saying because a caller only has to handle the one case: the editor is
    // shut, the mode is off, the pen is over bare desktop, or the compositor
    // has not answered yet. All four mean there is nothing to draw and nothing
    // a press would take, so all four look the same from out here.
    readonly property rect hoveredWindow: root.hovered

    // SOMETHING SHORT TO PUT ON THAT HIGHLIGHT, so a rectangle covering most of
    // a screen says which window it is instead of leaving somebody to work it
    // out from its edges. Empty exactly when `hoveredWindow` is.
    readonly property string hoveredWindowName: root.hoveredName

    // THE WINDOW THE MAPPING IS BOUND TO, by address, and "" when the mapping
    // is a rectangle somebody placed rather than a window somebody chose.
    //
    // AN ADDRESS AND NOT A RECTANGLE, because the rectangle is `region` and
    // always was. What a binding adds is a REASON for the region to be where it
    // is, and that reason outlives every particular rectangle it produces: the
    // window is moved, the region moves with it, and the address is the only
    // thing that held still across the two. Anything wanting the shape of the
    // bound window can read `region`, which is that shape aspect-fitted, which
    // is the shape the tablet is actually pointing at.
    readonly property string boundWindow: root.bound

    // SOMETHING SHORT TO CALL IT, taken at the moment of binding and then left
    // alone. A window's class does not change while it is open, and a label
    // that held still is worth more here than one re-derived every update:
    // this one has to go on saying which window is being followed while that
    // window sits on a workspace nobody is looking at and there is nothing live
    // to re-derive it from.
    readonly property string boundWindowName: root.boundName

    // IS THE MAPPING FOLLOWING SOMETHING RIGHT NOW. The same fact as
    // `boundWindow` being non-empty, said as a bool because that is the shape
    // it gets used in: it is the whole of the poll's stop condition below, and
    // it is what a pill in the overlay is asking when it wants to know whether
    // to say so.
    //
    // NOT THE SAME QUESTION AS `followWindow`, which is about what the NEXT
    // press will mean and is true for the whole time somebody is deciding.
    // This one is about whether a decision has been made.
    readonly property bool tracking: root.bound !== ""

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
    // one to one, for exactly as long as the editor is open.
    function begin(): void {
        if (root.editing)
            return;

        // WHAT CANCEL PUTS BACK. Taken before anything moves, and copied by
        // value: `rect` is a value type in QML, so this is a snapshot rather
        // than a second name for the live rectangle.
        // The binding is in it for the same reason the rectangle is: it is
        // part of what was showing when the edit started. An edit that ends in
        // a cancel has not chosen a different window any more than it has
        // chosen a different rectangle.
        root.before = {
            home: root.home,
            region: root.mapping,
            locked: root.locked,
            bound: root.bound,
            boundName: root.boundName
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

        // AND THE WINDOWS ARE READ, but only in the mode that is going to point
        // at one.
        //
        // FRESH, AND NOT FROM services/Hypr.qml, which keeps a client list and
        // whose own comment says why it cannot answer this: `lastIpcObject` is
        // filled by an IPC round trip that only happens when the compositor
        // announces something, and a window resized by hand announces nothing.
        // A stale rectangle in that file is a readout a few pixels out. A stale
        // rectangle in this one is the tablet snapped to where a window used to
        // be, which is a mapping nobody asked for with nothing on screen to say
        // it happened.
        //
        // ONCE PER OPEN, AND NOT ON A TIMER. Windows do not move while somebody
        // is holding a pen still over one, and what happens between this press
        // and the next is a person aiming. A poll would spend a process several
        // times a second re-answering a question whose answer is not changing.
        //
        // AND ONLY WHEN THE MODE IS ON, so a machine that never uses it never
        // spawns the process at all. Switching the mode on mid-edit asks for the
        // read itself; see toggleFollowWindow.
        root.forgetWindows();
        if (root.following)
            root.scanClients();

        // AND ANY GRACE LEFT OVER FROM A DISCONNECT IS CALLED OFF, because it
        // was counting down against an edit that is over. An edit opened while
        // the pad is absent gets no grace of its own: the pad is not what
        // opened it, so the pad is not what has to be able to close it.
        padLost.stop();
    }

    // APPLY IT FOR REAL, and remember it. The same pad button pressed a second
    // time, or `banditshell penmap commit`.
    function commit(): void {
        if (!root.editing)
            return;

        // THE SECOND PRESS CHOOSES THE WINDOW, and that is the whole of what
        // Follow Window changes. Everything below this line runs exactly as it
        // does in the ordinary mode; the only difference is which rectangle it
        // is running on, and whether that rectangle has a reason to keep
        // changing afterwards.
        //
        // CHOOSES, NOT COPIES. The snap on the next line is only the first
        // frame of the answer; the bind after it is what makes the mapping go
        // on being that window's rectangle as the window is moved, resized,
        // retiled, floated, fullscreened and carried to the other monitor. See
        // the Following section below for how, and for what it costs.
        //
        // WITH NOTHING UNDER THE PEN IT DOES NOTHING, deliberately, and the
        // check is for a rectangle with area rather than for the mode being on.
        // The pen can perfectly well be over bare desktop, over a screen with
        // nothing open on it, or over a window the compositor had not told us
        // about yet, and the honest answer in all of those is that no window was
        // chosen. Committing to an empty rectangle instead would take the
        // mapping away entirely, and the way back from that is another gesture
        // made with a pen that no longer points anywhere useful.
        //
        // AND IT DROPS ANY BINDING IT DID NOT REPLACE, which is this file's
        // answer to who wins between a live binding and a hand. The hand does.
        // Somebody who has just dragged an outline somewhere and pressed the
        // button has said where the mapping goes in the most direct terms
        // available, and an old binding left standing would drag it back within
        // a quarter of a second, which is the mapping undoing a deliberate
        // gesture in front of the person who made it.
        //
        // The unbind is deliberately BEFORE `editing` goes false, so that its
        // own save is suppressed and the one below covers it. Inside a gesture
        // it is part of the gesture; the end of the gesture writes everything
        // down at once, which is toggleAspect's rule.
        if (root.following && root.hovered.width > 0 && root.hovered.height > 0) {
            root.snapToWindow(root.hovered);
            root.bindWindow(root.hoveredAddr, root.hoveredName);
        } else {
            root.unbindWindow();
        }

        root.editing = false;
        root.applyRegion();
        root.save();
        root.forgetWindows();
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

            // THE BINDING COMES BACK WITH THE RECTANGLE, because it is the
            // reason that rectangle was where it was. Cancelling means nothing
            // was chosen, and a window that was being followed before the
            // editor opened was not chosen during it.
            //
            // UNLESS THE MODE WENT OUT UNDER IT. `following` is deliberately
            // not restored, for the reason below, so an edit that switched the
            // mode off and then ended badly would otherwise put a live binding
            // back underneath a switch that says it is off. That is exactly the
            // haunted state unbindWindow exists to prevent, and it must not be
            // reachable by the back door either.
            root.bound = root.following ? was.bound : "";
            root.boundName = root.following ? was.boundName : "";
            root.boundMisses = 0;
        }

        // `mapped` is NOT restored, for the reason begin() gives: ownership of
        // the mapping is not something this file can hand back. Neither is
        // `following`, and that one is a choice rather than an impossibility.
        // The shape lock comes back because it is part of the definition of the
        // rectangle being put back; Follow Window is not part of any rectangle,
        // it is a standing decision about what the next press will mean, and an
        // edit ending badly is no reason to have changed somebody's mind about
        // that.
        root.applyRegion();
        root.save();
        root.forgetWindows();

        // AND THE BINDING GETS THE LAST WORD, if one survived the edit. The
        // rectangle just put back is where the window was when the editor
        // opened, and the window has had the whole length of the gesture to
        // move; tracking is suspended for that length, so nothing has corrected
        // it. Asked for here rather than waited for, because the next thing to
        // change `boundRect` might be minutes away, and a cancel that left the
        // mapping on a stale rectangle until the window happened to move again
        // is the binding looking broken at the exact moment somebody chose to
        // keep it.
        root.followBound();
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

    // FOLLOW WINDOW ON OR OFF, from the control in the overlay.
    //
    // Written down at once when it is pressed outside an edit and left to the
    // commit or the cancel when it is pressed inside one, which is toggleAspect's
    // rule and is here for the same reason: inside a gesture it is part of that
    // gesture, and the end of the gesture is what settles everything at once.
    // There is nothing to push to the compositor either way, because this
    // changes what a press MEANS and never where the tablet currently points.
    function toggleFollowWindow(): void {
        root.following = !root.following;

        if (!root.following) {
            // SWITCHED OFF, SO THERE IS NOTHING TO POINT AT. Dropping the
            // snapshot here rather than leaving it to the end of the edit is
            // what makes the highlight go out on the same press that turned the
            // mode off, instead of one motion later.
            root.forgetWindows();

            // AND NOTHING TO FOLLOW EITHER, which is the more important half.
            // A binding still steering the mapping under a mode whose switch
            // says it is off is the kind of thing that looks haunted: windows
            // get moved, the tablet moves with them, and the one control that
            // claims to govern that is sitting there switched off. The save
            // this needs is unbindWindow's, which is why there is no longer one
            // written out here.
            root.unbindWindow();
            return;
        }

        // SWITCHED ON WHILE THE EDITOR IS ALREADY OPEN is the case that has to
        // be said out loud, because begin() is where the snapshot normally comes
        // from and an edit that started with the mode off never took one. So the
        // read is asked for here too. It lands a few milliseconds later, the
        // candidate list is rebuilt from it, and the pen position this file has
        // been remembering since the editor opened is tested against it without
        // the hand having to move at all.
        if (root.editing)
            root.scanClients();
        else
            root.save();
    }

    // STOP FOLLOWING, KEEP THE REGION.
    //
    // THE RECTANGLE IS DELIBERATELY NOT TOUCHED. It is where the window was
    // when the binding ended, which is where the tablet has been pointing and
    // where a hand expects it to still be. Taking the mapping away as well
    // would turn "stop following" into "lose the mapping", and the way back
    // from that is another gesture made with a pen that no longer points
    // anywhere useful, which is the same argument commit() makes for refusing
    // to commit an empty rectangle.
    //
    // AND IT IS WRITTEN DOWN, unless an edit is in progress. That is
    // toggleAspect's rule and it is here for toggleAspect's reason: inside a
    // gesture this is part of the gesture, and the commit or the cancel that
    // ends it saves everything at once.
    //
    // IT DOES NOT ASK WHETHER ANYTHING WAS BOUND, on purpose. Every caller that
    // reaches it is saying "there must be no binding after this", and half of
    // them cannot know whether there was one; an early return would make the
    // save conditional on a fact none of them are asking about.
    function unbindWindow(): void {
        root.bound = "";
        root.boundName = "";
        root.boundMisses = 0;

        if (!root.editing)
            root.save();
    }

    // WHERE THE PEN IS, in global layout coordinates, published by the overlay
    // on every motion.
    //
    // THE OVERLAY IS THE ONLY THING THAT CAN SAY. Hyprland forwards the stylus
    // to surfaces as ordinary pointer input, so a MouseArea sees it; nothing in
    // here does, and asking the compositor where the cursor is would mean a
    // process several times a second for as long as the editor is open. That
    // trade is the reason this mode is not click-through, and the reason it does
    // not need to be: the selection is made with the PAD button and never with
    // the pen tip, so nothing underneath the overlay ever has to be clicked.
    //
    // REMEMBERED WHETHER OR NOT THE MODE IS ON, which is the small thing that
    // makes switching it on mid-edit feel instant rather than needing a nudge of
    // the hand first. The hit test itself is gated in refreshHover, so an editor
    // in the ordinary mode does the storing and none of the work.
    //
    // AND CHEAP, because this runs on every pen event and a tablet reports a
    // few hundred a second. The hit test is one pass over a list that is usually
    // under a dozen entries, and setHover below refuses to republish a rectangle
    // that has not changed, which is what keeps the overlay's bindings from
    // re-running several hundred times a second to draw the same highlight.
    function setPointer(gx: real, gy: real): void {
        // THE EDITOR IS THE ONLY TIME THIS MEANS ANYTHING. Outside one the
        // tablet is bound to its region, the overlay is not on screen, and there
        // is no pen position for this file to have an opinion about.
        if (!root.editing)
            return;

        // The same refusal proposeRegion makes, for the same reason: a NaN here
        // would compare false against every edge and quietly turn the hit test
        // into one that never hits anything.
        if (!isFinite(gx) || !isFinite(gy))
            return;

        root.pointerX = gx;
        root.pointerY = gy;
        root.pointerKnown = true;
        root.refreshHover();
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

    // FOLLOW WINDOW, off until somebody says otherwise and then remembered.
    //
    // NOT BOUND TO A CONFIG KEY, unlike the lock above, and the asymmetry is
    // deliberate. The shape lock is a statement about this desk that is true
    // before anybody has touched anything, so it has a default worth shipping.
    // This is a mode somebody switches on for a minute to grab a window and
    // switches off again, and a config key for it would only be a way for a
    // machine to start up in a state nobody chose.
    property bool following: false

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

    // ARE THESE THE SAME RECTANGLE, field by field.
    //
    // Asked in the two places that exist to refuse to publish an answer which
    // has not changed: the hover highlight, recomputed a few hundred times a
    // second by the pen, and the tracked binding, where an unchanged rectangle
    // must not turn into another `hyprctl eval`. Written once, because the two
    // would otherwise be two copies of the same four comparisons and a copy
    // that drifts is a thrash somebody has to find twice.
    function sameRect(a: rect, b: rect): bool {
        return a.x === b.x && a.y === b.y && a.width === b.width && a.height === b.height;
    }

    // AN ADDRESS AS SOMETHING TWO SPELLINGS CAN BE COMPARED IN.
    //
    // Hyprland writes an address with its `0x`, in the client JSON and on the
    // event stream both; Quickshell's model writes the same address bare. This
    // shell talks to both and owns neither spelling, so both ends are stripped
    // before they are compared, which is the reconciliation Hypr.monitorOf
    // makes for the same reason. Comparing them as they come answers "no
    // window" for every window there is, which is a bug that looks exactly like
    // the feature never having worked.
    function bareAddress(addr: string): string {
        const s = String(addr ?? "");
        return (s.startsWith("0x") ? s.slice(2) : s).toLowerCase();
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
                // THE COMPOSITOR'S OWN NUMBER FOR IT, which is the only handle
                // a CLIENT gives on which screen it belongs to: a window says
                // `monitor: 0` and never says HDMI-A-1. Kept alongside the name
                // rather than instead of it, because ids are handed out in plug
                // order and are renumbered by unplugging a neighbour, which is
                // exactly why `home` is a name and this is not.
                id: typeof m.id === "number" ? m.id : -1,
                x: Number(m.x) || 0,
                y: Number(m.y) || 0,
                w: w,
                h: h,
                focused: m.focused === true,
                // WHAT THIS SCREEN IS SHOWING RIGHT NOW, which is the only way
                // to tell a window that is on screen from one that is merely
                // open. A workspace is visible when a monitor says it is on it,
                // and a scratchpad is visible only while a monitor has it pulled
                // over; both read zero when there is none. They cost nothing,
                // because they arrive in an answer this file is already asking
                // for, which is why the window hit test does not go and ask a
                // second time.
                //
                // AND THEY ARE DELIBERATELY LEFT OUT OF `layoutSeen` below.
                // Changing workspace is not the desk moving, so it must not
                // count as a layout change and must not drag a re-push of the
                // mapping along behind it.
                ws: Number(m.activeWorkspace?.id) || 0,
                special: Number(m.specialWorkspace?.id) || 0
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
    // The windows, and which one the pen is over.
    // ------------------------------------------------------------------

    // WHAT FOLLOW WINDOW IS: a different meaning for the second press, and
    // nothing else at all.
    //
    // The gesture is untouched. The pad button opens the editor and unbinds the
    // tablet to the whole layout, which is the part that makes pointing at any
    // window on any screen possible in the first place; the pen moves; the pad
    // button closes it. The only thing that changes is which rectangle the
    // closing press takes, the one that was dragged or the one belonging to the
    // window the pen was on.
    //
    // A SNAP AND NOT A BINDING. The region takes the window's shape at the
    // instant of the press and from then on has nothing to do with that window:
    // it does not follow it when it is moved and it does not notice when it is
    // closed. A mapping that chased a window would be a pen whose reach changed
    // under the hand every time something was dragged, which is the same
    // feedback loop begin() unbinds the tablet to escape.
    //
    // AND IT IS NOT CLICK-THROUGH, which is worth writing down because
    // click-through is what was asked for. An overlay with an empty input region
    // does let the pen reach what is underneath, and it also stops the overlay
    // hearing the pen, so the only way left to know what to highlight would be
    // to ask the compositor where the cursor is several times a second. Since
    // the selection is made with the PAD button and never with the pen tip,
    // nothing underneath ever has to be clicked, so the input region stays and
    // the poll never has to exist. The pen still cannot press what is under the
    // overlay while the editor is open, and no part of this pretends otherwise.

    // THE CLIENT LIST AS THE COMPOSITOR LAST PRINTED IT, raw and unfiltered,
    // taken once per open by begin(). Emptied the moment the editor closes,
    // because a list of where windows were several minutes ago is precisely the
    // thing this mode must never be allowed to point at.
    property var snapshot: []

    // WHERE THE PEN WAS LAST HEARD FROM, global, and whether it has said yet.
    // Plain properties rather than anything cleverer: nothing binds to them, so
    // the change signal they emit a few hundred times a second reaches nobody.
    property real pointerX: 0
    property real pointerY: 0
    property bool pointerKnown: false

    // The rect and the label behind hoveredWindow and hoveredWindowName. A rect
    // that was never assigned is 0x0 at the origin, which is the empty this
    // whole path uses to mean "no window", so there is nothing to initialise.
    property rect hovered
    property string hoveredName: ""

    // AND THE ADDRESS OF THE SAME WINDOW, which is the one thing about it that
    // is not on the highlight and is the only thing a binding can be made of.
    // Internal, because nothing outside this file has ever needed to name a
    // window: the overlay draws the rectangle and reads the label, and the
    // press that chooses is handled in here.
    property string hoveredAddr: ""

    // THE WINDOWS AS THE HIT TEST NEEDS THEM, derived rather than stored,
    // because it takes two answers that arrive separately and in either order.
    // The client list says where each window is and which screen it is on; the
    // monitor list says which workspaces are actually being shown and where the
    // edges of those screens are. Written out by whichever of the two landed
    // last, the list would be a scan behind whenever the other one won the race;
    // recomputed from both, it is right as soon as both are in and stays right
    // when either changes underneath it.
    readonly property var candidates: root.buildCandidates(root.snapshot, root.monitors)

    // AND THE PEN IS RE-ASKED whenever that list is rebuilt, because the hand is
    // usually holding still at exactly this moment. The press that opened the
    // editor is barely over, the compositor's answer is the thing everybody is
    // waiting for, and a highlight that waited for the next motion would leave a
    // pen already aimed at the right window looking like it was aimed at
    // nothing.
    onCandidatesChanged: root.refreshHover()

    // WHICH RECTANGLES ARE REALLY ON SCREEN, out of everything the compositor is
    // holding, and where each of them sits in the stack.
    //
    // THE COORDINATES NEED NO CONVERSION, which is the first thing to be sure of
    // and the easiest to be quietly wrong about. Hyprland reports a client's
    // `at` and `size` in GLOBAL LAYOUT coordinates, the same frame `region` is
    // kept in, already through that monitor's transform and scale. On this desk
    // that is checkable rather than a matter of faith, in two independent ways.
    // The ultrawide's origin is (1200,240) and its windows report x values above
    // 1200, so the frame is not monitor-relative. DP-1 is at transform 1, a
    // quarter turn, so its 1920x1200 mode occupies a 1200x1920 footprint, and
    // the window on it reports 1104x1876, which is the turned shape and not the
    // mode. Either of those would read the other way round if a conversion were
    // owed here. What is NOT verified, because this desk cannot exercise it, is
    // a fractional monitor scale under an XWayland window; both screens here are
    // at scale 1, where the question does not arise.
    //
    // ONLY WHAT IS BEING SHOWN. A window lives on a workspace and a workspace is
    // only on screen while a monitor says it is on it, so the test is against
    // the set of workspaces the monitors report, plus whatever special workspace
    // each one currently has pulled over. A scratchpad nobody has pulled out is
    // a window with a perfectly good rectangle that nobody can see, and on this
    // machine every one of them sits exactly on top of the windows that ARE
    // visible, so leaving them in would mean aiming at a terminal and being
    // handed Discord.
    //
    // AND `visible` IS NOT THAT TEST, though the field is right there in the
    // JSON and reads as though it were. Hyprland 0.56 prints `visible: true` for
    // every client including the ones on closed special workspaces, so it is
    // answering some other question than the one it appears to answer. The
    // workspace comparison is done here instead, out of numbers whose meaning is
    // not in doubt.
    //
    // CLIPPED TO ITS OWN SCREEN, which is not a nicety on this desk. The layout
    // is a scrolling one, so a window on the active workspace routinely sits
    // half or entirely outside the monitor showing it and the compositor draws
    // only the part that lands there. Untrimmed, a terminal scrolled off the
    // left of the ultrawide reaches right across the portrait screen beside it,
    // and pointing at bare desktop over there would light it up. A window
    // trimmed to nothing has been scrolled away completely and is dropped.
    //
    // The trim also settles a question proposeRegion would otherwise get wrong.
    // That function decides which monitor a rectangle belongs to by where its
    // CENTRE falls, and the centre of a window hanging off one screen is easily
    // on the next one, so an untrimmed rectangle handed to it could re-home the
    // mapping to a screen the window is not even on. settle() nudges a saved
    // rectangle inside its named monitor before proposing it for exactly this
    // reason; this is the same move for the same reason.
    function buildCandidates(raw: var, mons: var): var {
        const out = [];
        if (!Array.isArray(raw) || !Array.isArray(mons))
            return out;

        // NO SCREENS MEANS NO CANDIDATES, and that is the safe way round. It
        // happens for the few milliseconds before the first monitor scan lands,
        // and the cost is a highlight that appears a frame late rather than one
        // that appears over the wrong window; the binding above rebuilds this
        // list the instant the scan arrives.
        const byId = {};
        const shown = {};
        for (const m of mons) {
            byId[m.id] = m;
            if (m.ws)
                shown[m.ws] = true;
            if (m.special)
                shown[m.special] = true;
        }

        for (let i = 0; i < raw.length; i++) {
            const c = raw[i];
            if (!c || c.mapped !== true || c.hidden === true)
                continue;

            const ws = Number(c.workspace?.id);
            if (!isFinite(ws))
                continue;

            // A PINNED WINDOW IS ON WHATEVER YOU ARE LOOKING AT, which is the
            // whole of what pinning means, so it is not asked which workspace it
            // is on. If the compositor also reassigns its workspace as you
            // switch, this line is a harmless no-op; if it does not, this line
            // is the difference between a pinned window being pointable and not.
            if (c.pinned !== true && shown[ws] !== true)
                continue;

            // A PAIR OF NUMBERS, ASKED FOR BY LENGTH RATHER THAN BY TYPE, and
            // the distinction is not pedantry: it is the difference between
            // this function working for both its callers and working for one.
            // The same client object arrives here two ways. Out of JSON.parse
            // on `hyprctl -j clients`, `at` is a plain JS array. Out of a
            // toplevel's `lastIpcObject` it is a QVariantList, which reaches JS
            // as a sequence that indexes, has a length, holds the same two
            // numbers, and answers FALSE to Array.isArray. Asking the type
            // therefore threw away every tracked rectangle in silence, with no
            // error anywhere and a mapping that simply never moved. What is
            // actually being asked is whether there are two numbers in there,
            // and the isFinite tests just below are what decide that.
            const at = c.at;
            const size = c.size;
            if (!at || !size || at.length < 2 || size.length < 2)
                continue;

            let x = Number(at[0]);
            let y = Number(at[1]);
            let w = Number(size[0]);
            let h = Number(size[1]);
            if (!isFinite(x) || !isFinite(y) || !(w > 0) || !(h > 0))
                continue;

            const mon = byId[Number(c.monitor)];
            if (mon) {
                const x0 = Math.max(x, mon.x);
                const y0 = Math.max(y, mon.y);
                const x1 = Math.min(x + w, mon.x + mon.w);
                const y1 = Math.min(y + h, mon.y + mon.h);
                if (!(x1 > x0) || !(y1 > y0))
                    continue;
                x = x0;
                y = y0;
                w = x1 - x0;
                h = y1 - y0;
            }

            // WHERE IT SITS IN THE STACK, which is what decides the winner when
            // two rectangles both contain the pen.
            //
            // TWO QUESTIONS, AND THEY MULTIPLY RATHER THAN ADD. The first is
            // which SURFACE the window is on: a special workspace is pulled over
            // the whole of the ordinary one, so anything on it is above
            // everything that is not, whatever either of them happens to be
            // doing. The second is where in that surface it sits, which is the
            // ladder below. Composing them as surface * rungs + rung reads the
            // pair in the right order without either of them having a number
            // written down beside it.
            //
            // THE LADDER IS A LIST so that a rung IS its position in the list.
            // The last line that matches wins, which is what puts a float over
            // the tiling and a pinned float over a plain one, and adding a rung
            // means adding a line rather than renumbering the ones around it.
            const above = [Number(c.fullscreen) > 0, c.floating === true, c.pinned === true];
            let rung = 0;
            for (let r = 0; r < above.length; r++)
                if (above[r])
                    rung = r + 1;

            // SOMETHING SHORT TO CALL IT. The class rather than the title,
            // because a title is whatever document happens to be open and can be
            // a sentence long, while the class is what the thing IS and holds
            // still while you aim at it. Application ids are reverse DNS by
            // convention, so the last dotted segment of one is the word a person
            // would actually say, qBittorrent rather than
            // org.qbittorrent.qBittorrent, and a class with no dots in it is its
            // own last segment, so kitty is left alone by the same line. The
            // title is what is left for a window carrying no class at all.
            const parts = String(c["class"] ?? "").split(".").filter(s => s.length > 0);

            out.push({
                x: x,
                y: y,
                w: w,
                h: h,
                // THE ONE FIELD THAT IS NOT GEOMETRY, and the only handle on
                // this window that will still mean something after the pen has
                // moved on. Kept in the spelling it arrived in, `0x` and all,
                // because that is also the spelling Hypr's closewindow signal
                // uses; bareAddress is what reconciles it with Quickshell's.
                address: String(c.address ?? ""),
                // The list's own order is the tie-break inside a rung. Hyprland
                // prints its window list in stacking order and raising a window
                // moves it towards the end, so later is nearer the top; two
                // floats overlapping is the case it decides.
                order: i,
                rank: (ws < 0 ? 1 : 0) * (above.length + 1) + rung,
                name: parts.length ? parts[parts.length - 1] : String(c.title ?? "")
            });
        }

        return out;
    }

    // THE TOPMOST ONE CONTAINING THE POINT, or null.
    //
    // Half-open on the right and the bottom, the way homeFor asks the same
    // question of a monitor, so two rectangles that share an edge hand the pen
    // to exactly one of them rather than to both or to neither.
    //
    // THE SHELL'S OWN SURFACES ARE NOT IN HERE AT ALL, and that is worth
    // knowing rather than fixing. The bar, the wallpaper and this editor's own
    // overlay are layer surfaces, and layer surfaces are not clients, so nothing
    // in the snapshot can ever be one of them. Aiming at the bar therefore
    // highlights the window BEHIND the bar, which is the only answer available
    // and, since the press that chooses comes from the pad rather than from the
    // pen tip, is also the useful one.
    function windowAt(gx: real, gy: real): var {
        let best = null;
        for (const c of root.candidates) {
            if (gx < c.x || gy < c.y || gx >= c.x + c.w || gy >= c.y + c.h)
                continue;
            if (!best || c.rank > best.rank || (c.rank === best.rank && c.order > best.order))
                best = c;
        }
        return best;
    }

    // ASK AGAIN WITH WHAT WE ALREADY KNOW. Called from every pen motion and from
    // every rebuild of the candidate list, so both of the things that can change
    // the answer converge on one place rather than each carrying a copy of the
    // rules.
    //
    // ONE PATH THROUGH IT, including the failures: an editor that is shut, a
    // mode that is off, a pen that has not reported yet and a pen over bare
    // desktop all fall out of the same expression as no window, which is what
    // makes "empty means nothing to draw" true for every reason at once.
    function refreshHover(): void {
        const hit = root.editing && root.following && root.pointerKnown ? root.windowAt(root.pointerX, root.pointerY) : null;
        root.setHover(hit ? Qt.rect(hit.x, hit.y, hit.w, hit.h) : Qt.rect(0, 0, 0, 0), hit ? hit.name : "", hit ? hit.address : "");
    }

    // THE SAME RECTANGLE SAYS NOTHING. refreshHover runs on every pen event, a
    // tablet reports a few hundred a second, and very nearly every one of them
    // lands on the window the last one did. Assigning the same rectangle again
    // would re-run every binding in the overlay that draws the highlight, a few
    // hundred times a second, to arrive back at the picture already on screen.
    // The comparison lives here, once, rather than in each of the readers.
    // THE ADDRESS IS PART OF THE COMPARISON and not merely carried alongside
    // it, because two different windows can present the identical rectangle and
    // the identical label: a tile handed straight from a terminal that closed to
    // a terminal that opened is exactly that, and leaving the address out would
    // let a press bind to the window that is no longer there.
    function setHover(r: rect, name: string, addr: string): void {
        if (root.hoveredName === name && root.hoveredAddr === addr && root.sameRect(root.hovered, r))
            return;

        root.hovered = r;
        root.hoveredName = name;
        root.hoveredAddr = addr;
    }

    // THERE IS NOTHING TO POINT AT ANY MORE, which is what closing the editor
    // and switching the mode off both amount to. The snapshot goes rather than
    // being kept for next time, because the next edit reads a fresh one anyway
    // and the only thing a kept one could do is be wrong later. The pen position
    // goes with it so that the first frame of the next edit cannot briefly
    // highlight whatever happens to be under where the pen was left last time.
    //
    // AND THE BINDING IS NOT IN HERE, which is the distinction the whole
    // Following section rests on. What this forgets is where the pen was aiming,
    // which is a fact about an editor that is now shut. What a binding is, is a
    // fact about the mapping, and the mapping outlives the editor by design.
    function forgetWindows(): void {
        root.snapshot = [];
        root.pointerKnown = false;
        root.refreshHover();
    }

    // THE WINDOW'S RECTANGLE, TAKEN AS THE REGION.
    //
    // SHRUNK TO THE TABLET'S SHAPE WHEN THE LOCK IS ON, and centred in the
    // window rather than pinned to a corner of it. A window is not the tablet's
    // shape, and stretching the pen to match one would hand back exactly the
    // distortion this whole service exists to remove: aim at a wide browser
    // window with the lock on and every circle drawn in it comes out an ellipse.
    // So the largest tablet-shaped rectangle that fits INSIDE the window is what
    // gets taken, and the leftover strip is split evenly on the two sides of
    // whichever axis had it to spare.
    //
    // ONE NUMBER AGAIN, for proposeRegion's reason: locked, the region is a
    // point on the ray (aspect*t, t), so the largest one that fits is whichever
    // of the two axes runs out first. That is a min and not a branch on the
    // window's shape. It also means the rectangle handed on below is already on
    // the ray, so proposeRegion's projection is a no-op and the shape survives
    // the trip unchanged.
    //
    // AND IT GOES THROUGH proposeRegion LIKE EVERYTHING ELSE, which is the
    // point: a window can be smaller than the minimum region, and the clamp
    // still has the last word on where a rectangle is allowed to sit. Nothing
    // here is a second copy of those rules.
    function snapToWindow(r: rect): void {
        let x = r.x;
        let y = r.y;
        let w = r.width;
        let h = r.height;

        if (root.locked) {
            const aspect = root.surfaceAspect;
            const t = Math.min(w / aspect, h);
            x += (w - t * aspect) / 2;
            y += (h - t) / 2;
            w = t * aspect;
            h = t;
        }

        root.proposeRegion(x, y, w, h);
    }

    // ------------------------------------------------------------------
    // Following the window that was chosen.
    // ------------------------------------------------------------------

    // CHOOSING A WINDOW IS CHOOSING A WINDOW, and this section is the
    // correction that makes that true. The first version of Follow Window took
    // the hovered rectangle at the instant of the press and then forgot which
    // window it had come from. That is a defensible thing to have built and it
    // is not what anybody meant: move the window afterwards and the tablet goes
    // on pointing at the hole it left. The mapping is BOUND to the window now.
    // It follows it moved, resized, retiled by a neighbour opening, dragged to
    // the other screen, made floating and made fullscreen, and it goes on
    // following while the editor is shut, because the binding IS the mapping
    // rather than a mode of the editor.
    //
    // HYPRLAND HAS NO GEOMETRY EVENT, which is the whole of the difficulty and
    // is written down here because the next person will go looking for one too.
    // The socket2 stream carries openwindow, closewindow, movewindowv2,
    // activewindowv2, changefloatingmode, fullscreen, workspace, focusedmon,
    // monitorlayoutchanged and their friends, and not one of them means "this
    // window's rectangle changed". Quickshell forwards what there is and
    // invents nothing: its own IPC handles exactly openwindow, closewindow,
    // movewindowv2, windowtitlev2, activewindowv2, urgent and configreloaded,
    // and movewindowv2 is a workspace move rather than a geometry one. A tiling
    // reflow is therefore covered by accident, because the open or the close
    // that caused it is itself an event. An interactive resize is covered by
    // nothing at all: dragging a window edge with the mouse is silence on the
    // socket from the first pixel to the last.
    //
    // SO WHAT DOES A READ COST. Read out of Quickshell 0.3.0 (b66495f), the
    // revision this machine is running, rather than assumed, because the answer
    // is what decides whether a poll is allowed to exist here at all:
    //
    //   `Hyprland.refreshToplevels()` IS NOT A PROCESS. It opens
    //   `.socket.sock`, writes `j/clients`, reads the answer and parses it, all
    //   on the Qt event loop inside this process. There is no QProcess and no
    //   `hyprctl` anywhere in Quickshell's Hyprland IPC. On this desk the
    //   answer is about seven kilobytes for eight clients. That is one unix
    //   socket round trip and one JSON parse against the fork, the exec, the
    //   dynamic link and the second socket connection that running
    //   `hyprctl -j clients` costs, and it is the entire reason a poll is
    //   affordable.
    //
    //   IT REFRESHES EVERY TOPLEVEL, not just the list. There is no per-window
    //   refresh; the granularity is all or nothing, which costs nothing here
    //   because the whole answer arrives in one read anyway.
    //
    //   `lastIpcObject` CARRIES THE WHOLE CLIENT OBJECT, unfiltered, the same
    //   shape `hyprctl -j clients` prints, `at` and `size` included. That is
    //   why buildCandidates can be handed one of them directly and this section
    //   needs no second copy of the rules about what is on screen and where.
    //   It is documented as not updating on its own, and that is exactly right:
    //   it changes when somebody refreshes and never otherwise, so it cannot
    //   drive its own loop.
    //
    //   AND IT IS SELF-DEBOUNCING against a refresh already in flight, and rate
    //   limited against nothing else.
    //
    // AND THE SOCKET IS ALREADY OPEN, once, in services/Hypr.qml, which hears
    // the raw event stream and already calls refreshToplevels() on every event
    // whose name mentions a window, a workspace or a monitor. So the event half
    // of this costs nothing at all here: binding to the model that file is
    // already keeping fresh catches every geometry change any event caused,
    // within a millisecond of the event, with no second connection and no
    // second subscription. Hypr.resync() is that same call under the name it
    // was given for exactly this, a reader that picks its own moment.
    //
    // WHICH LEAVES THE POLL AS THE SAFETY NET, for the interactive resize and
    // the interactive drag of a floating window, which are the two things the
    // event stream says nothing about.
    //
    // A QUARTER OF A SECOND, and the number comes from the hand rather than
    // from the eye. This is where a PEN points. Nobody draws while dragging a
    // window, so what actually has to be true is that the mapping has settled
    // by the time a hand that let go of the mouse has got back to the tablet
    // and put a nib down, which is several hundred milliseconds at its very
    // fastest. 250ms is inside that with room to spare, and it is four socket
    // round trips a second rather than the sixty a frame-rate poll would spend
    // beating a deadline nothing is measuring against. Rejected in both
    // directions: 16ms, because it buys smoothness for an outline that is not
    // on screen while a window is being dragged, and a second or more, because
    // a mapping still visibly catching up when the pen arrives is worse than
    // one that never followed.
    //
    // AND IT STOPS DEAD WITH NOTHING BOUND, which is the one part of this that
    // is not a trade. This is a desktop that stays up for days; a timer still
    // waking four times a second because a mode was switched off last Tuesday
    // is a defect and not a rounding error.

    // THE ADDRESS, AND THE LABEL THAT WAS TAKEN WITH IT.
    property string bound: ""
    property string boundName: ""

    // HOW MANY POLLS IN A ROW HAVE NOT FOUND IT. See pollBound for what this is
    // really guarding, which is not the window closing.
    property int boundMisses: 0

    readonly property int trackPoll: 250

    // HOW LONG AN ADDRESS IS ALLOWED TO BE MISSING before the binding is given
    // up on, in milliseconds. See pollBound; kept beside the interval because
    // the two are only meaningful against each other.
    readonly property int trackGrace: 1000

    // THE TOPLEVEL BEHIND THE ADDRESS, or null. Quickshell's model rather than
    // a client list of this file's own, because services/Hypr.qml already keeps
    // that model in step with the event stream and a second copy would be a
    // second thing to keep in step, out of a second process, for the same
    // answer.
    readonly property var boundToplevel: {
        if (!root.bound)
            return null;
        const want = root.bareAddress(root.bound);
        return Hyprland.toplevels.values.find(t => root.bareAddress(t.address) === want) ?? null;
    }

    // WHERE THAT WINDOW IS NOW, in the same global layout coordinates
    // everything else here is in, and EMPTY when there is nothing to point at.
    //
    // THROUGH buildCandidates, which is the point of computing it this way.
    // That function already knows every rule this rectangle has to obey: that a
    // window on a workspace nobody is looking at is not on screen, that a
    // scrolling layout leaves windows hanging off the side of the monitor
    // showing them and only the part that lands there is real, and that
    // `lastIpcObject` is exactly the shape it reads. Handing it a list of one
    // gets all of that for nothing and leaves one copy of those rules in the
    // file instead of two that drift apart.
    //
    // EMPTY MEANS FREEZE, and it covers three situations that all want the same
    // answer: the window has gone, the window is on a workspace that is not
    // being shown, and the window has been scrolled entirely off its own
    // monitor. In all three there is no rectangle to follow, and the honest
    // thing is to leave the mapping exactly where it last was rather than move
    // it somewhere nobody chose. It picks itself up again the moment the window
    // is visible again, with no state in between.
    //
    // A BINDING, which is what makes the event half free: Hypr's refreshes
    // change `lastIpcObject`, this re-evaluates, and QML publishes nothing at
    // all when the rectangle it computes is the one it computed last time,
    // which is nearly every time. A window gaining focus rewrites most of its
    // client object and moves it not at all, and that whole class of update
    // dies here without anything downstream hearing about it.
    readonly property rect boundRect: {
        const tl = root.boundToplevel;
        const shown = tl ? root.buildCandidates([tl.lastIpcObject], root.monitors) : [];
        return shown.length ? Qt.rect(shown[0].x, shown[0].y, shown[0].w, shown[0].h) : Qt.rect(0, 0, 0, 0);
    }

    onBoundRectChanged: root.followBound()

    // BIND THE MAPPING TO A WINDOW. The region has already been snapped to it
    // by the caller; this is the part that makes it stay there.
    function bindWindow(addr: string, name: string): void {
        // A CANDIDATE WITH NO ADDRESS CANNOT BE FOLLOWED, and there is nothing
        // useful to do about that but the old thing. The region has already
        // taken the window's shape, so the gesture still did what it looked
        // like it did; it simply does not track. Not a shape this compositor
        // has been seen to produce, and here because the alternative is a
        // binding to the empty string, which matches no window, never resolves,
        // and would poll forever.
        if (!addr)
            return root.unbindWindow();

        root.bound = addr;
        root.boundName = name;
        root.boundMisses = 0;
    }

    // THE WINDOW MOVED, SO THE MAPPING MOVES.
    function followBound(): void {
        // NOT BEFORE THERE IS A MAPPING TO MOVE. Until the state file and the
        // screens have both landed this file has no region of its own and
        // settle() is what places the saved one. Moving it first would be this
        // path racing that one for the first rectangle of the session, and a
        // binding restored from disk arrives precisely in that window.
        if (!root.bound || !root.settled)
            return;

        // AND NOT WHILE THE EDITOR IS OPEN, which is the answer to who wins
        // between a live binding and a hand. The hand does, always. Inside an
        // edit the pen is pushing an outline around, and a binding dragging it
        // back a quarter of a second later would be a rectangle fighting the
        // person holding it. So tracking is suspended for the length of the
        // gesture and the press that ends it settles the question: aimed at a
        // window it rebinds, aimed at nothing it drops the binding and keeps
        // the rectangle that was placed by hand. `boundRect` goes on updating
        // throughout, because the overlay still has a bound window to draw and
        // the fact that it is not currently steering the mapping does not make
        // it any less true.
        if (root.editing)
            return;

        const r = root.boundRect;
        if (!(r.width > 0) || !(r.height > 0))
            return;

        // COPIED, FIELD BY FIELD, and this is a trap rather than a style
        // choice. `const was = root.mapping` does NOT take a snapshot: reading
        // a value-type property into a JS variable hands back a reference that
        // reads through to the property, so `was` would silently follow the
        // assignment two lines down and the comparison below would compare the
        // new rectangle against itself and answer "unchanged" every single
        // time. Tracking then looked like it worked, because `region` really
        // did move, and pushed nothing to the compositor unless the MONITOR had
        // also changed, which is the one term of that comparison that is a
        // plain string. Building a fresh rect is what makes it a value.
        const wasHome = root.home;
        const was = Qt.rect(root.mapping.x, root.mapping.y, root.mapping.width, root.mapping.height);

        // THE SAME PATH A SNAPPED RECTANGLE TOOK, and not a second one. The
        // aspect fit, the size cap, the clamp and the choice of monitor all
        // live behind snapToWindow and proposeRegion, so a window dragged to
        // the other screen re-homes here by the same arithmetic that re-homes a
        // rectangle dragged there by hand, and the shape lock is recomputed on
        // every update rather than being a fact about the moment of the press.
        root.snapToWindow(r);

        // AND A RECTANGLE THAT DID NOT MOVE SAYS NOTHING. `hyprctl eval` is a
        // process, and this runs up to four times a second for as long as a
        // binding is live, so re-pushing an identical mapping would be the
        // worst thing in this file by a wide margin: a fork several times a
        // second, forever, to tell the compositor what it is already holding.
        //
        // THE COMPARISON IS ON THE REGION AND NOT ON THE WINDOW, because they
        // are not the same question. A window can change in the axis the aspect
        // lock is not using, or move under a clamp that was already pinning it,
        // and leave the region exactly where it was. Asking the question about
        // the thing that actually gets pushed is the only version of it that
        // cannot be wrong.
        if (root.home === wasHome && root.sameRect(root.mapping, was))
            return;

        root.applyRegion();
        boundSave.restart();
    }

    // ASK AGAIN, ON THE CLOCK, for the changes no event covers.
    function pollBound(): void {
        if (!root.bound)
            return;

        // IS IT STILL THERE, and this is NOT how a closing window is normally
        // noticed. `closewindow` is, off the event stream, through Hypr's own
        // signal, and it lands in milliseconds. This is the backstop for what
        // that signal cannot cover: a binding restored from disk whose address
        // died with a previous compositor, which is the ordinary case after any
        // reboot and is not a fault, and the general case of an address this
        // shell is holding that nothing is ever going to mention again. Without
        // it such a binding would keep this timer waking forever, which is
        // exactly the defect the timer's `running` was written to avoid,
        // arrived at from the other side.
        //
        // A WHOLE SECOND OF ABSENCE, not a single miss, and the grace is why
        // this is a count rather than a test. Quickshell's client model is
        // empty for the first moments of a shell start, before its own first
        // read has landed, and a restored binding checked inside that window
        // would drop itself every single time the shell restarted. A second is
        // several times what that read takes and is still far too fast for
        // anybody to wonder why a dead binding was still showing.
        //
        // COUNTED AGAINST THE INTERVAL rather than as a number of ticks, so
        // that changing the poll rate cannot silently change the grace with it.
        if (root.boundToplevel) {
            root.boundMisses = 0;
        } else {
            root.boundMisses += 1;
            if (root.boundMisses * root.trackPoll >= root.trackGrace)
                return root.unbindWindow();
        }

        // AND THAT IS ALL A TICK DOES: it asks. It deliberately does NOT
        // re-derive the region from what it already has, and that restraint is
        // the whole reason this reads as one line.
        //
        // WHAT IS ALREADY IN HAND CAN BE ARBITRARILY OLD. `lastIpcObject` only
        // changes when somebody refreshes, so at the instant a binding begins
        // it holds wherever that window was the last time anything asked, which
        // can be minutes and several moves ago. A tick that acted on it would
        // push that stale rectangle to the compositor, and the tablet would
        // jump to where the window used to be for as long as it takes the very
        // refresh on the next line to come back. Measured, not imagined: the
        // first draft of this did exactly that, and the trace showed a mapping
        // landing on a window's position from before it had been moved,
        // corrected a millisecond and a half later.
        //
        // SO ONLY A FRESH ANSWER MOVES ANYTHING. `boundRect` changes when a
        // refresh brings back something different, and its change is what calls
        // followBound. The two moments where a binding is live and something
        // ELSE set the region ask for it by hand instead, which is settle() for
        // a restore and cancel() for an abandoned edit; both are named and both
        // are one call.
        //
        // services/Hypr.qml's own name for `Hyprland.refreshToplevels()`, asked
        // for through that file rather than called directly, so the one place
        // this shell re-reads window geometry stays one place.
        Hypr.resync();
    }

    Timer {
        id: boundPoll

        // THE WHOLE OF THE STOP CONDITION, and deliberately nothing else in it.
        // No editor state, no mode, no monitor count: a binding exists or it
        // does not, and this timer exists exactly when it does.
        running: root.tracking
        repeat: true
        interval: root.trackPoll

        // THE FIRST TICK IS IMMEDIATE, which is what makes a binding correct
        // itself the instant it is made or restored rather than a quarter of a
        // second afterwards. It matters most on the restore, where the
        // rectangle read off disk is from whenever the shell last wrote it and
        // the window has had a whole reboot in which to move.
        triggeredOnStart: true
        onTriggered: root.pollBound()
    }

    // HOW LONG AFTER THE WINDOW STOPS BEFORE THE FILE IS WRITTEN.
    //
    // THE STATE FILE IS A RECORD OF WHERE THINGS ENDED UP, not a transcript of
    // the drag. A tracked region changes several times a second while somebody
    // resizes a window, and writing on each of those would be a few hundred
    // writes to say what the last one says. Deferring costs a second of drift
    // in exactly one situation, a shell killed mid-drag coming back to a
    // compositor that also restarted, where the frozen rectangle it restores is
    // a second stale. Nobody can tell, and every other path through this file
    // saves directly and cancels this.
    Timer {
        id: boundSave

        interval: 1000
        onTriggered: root.save()
    }

    function scanClients(): void {
        // ALREADY RUNNING IS ALREADY ANSWERED, which is why there is no queue
        // here and there is one for the monitor scan. Every one of these reads
        // asks the identical question and comes back with a list milliseconds
        // old either way, so a second request while one is in flight has nothing
        // to add to it. The monitor scan queues because the things that ask for
        // one want a push afterwards, and the last one to ask has to get it.
        if (winScan.running)
            return;
        winScan.running = true;
    }

    Process {
        id: winScan

        command: ["hyprctl", "-j", "clients"]

        stdout: StdioCollector {
            onStreamFinished: root.readClients(text)
        }
    }

    function readClients(text: string): void {
        let raw = [];
        try {
            raw = JSON.parse(text);
        } catch (e) {
            // hyprctl answers with nothing, or with half a document, while the
            // compositor is starting or dying, which is the same tolerance
            // readMonitors takes above.
        }

        // AND A BAD ANSWER AND AN EMPTY DESK END UP THE SAME WAY, on purpose.
        // An empty monitor list is refused above because a machine genuinely has
        // screens while this shell is drawing on them, so nothing there means
        // the read failed. A machine genuinely can have no windows open, so
        // nothing here is an answer, and both a real one and a failed parse land
        // as no candidates, no highlight, and a press that commits the dragged
        // rectangle. That is the mode quietly behaving as though it were off,
        // which is the right way for this to fail: an editor that still does
        // something ordinary rather than one that has broken.
        root.snapshot = Array.isArray(raw) ? raw : [];
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
        // ANY DEFERRED WRITE IS ABSORBED BY THIS ONE. boundSave exists to turn
        // a drag's worth of tracked rectangles into a single write, and every
        // caller that reaches here is stating the whole of the truth anyway, so
        // a pending timer behind it has nothing left to add.
        boundSave.stop();

        const out = {
            aspectLocked: root.locked,
            followWindow: root.following,

            // THE BINDING, WHICH IS THE REASON THE RECTANGLE BELOW IS WHERE IT
            // IS. Written even when it is empty, so that the file's shape does
            // not depend on the mode and absorb() never has to tell a machine
            // that stopped following from one that never started.
            //
            // AN ADDRESS DOES NOT SURVIVE A COMPOSITOR RESTART, which is worth
            // saying beside the thing being saved: what is written here is
            // usually dead by the time it is read, and that is not a fault. It
            // is live and worth restoring in the one case that matters, the
            // shell being restarted under a compositor that kept running, which
            // is the case somebody hits a dozen times an evening while working
            // on the shell itself. See settle() for what happens to the other.
            boundWindow: root.bound,
            boundWindowName: root.boundName
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

        // A FILE WRITTEN BEFORE THIS MODE EXISTED HAS NO SUCH KEY, and an older
        // file is not a damaged one. So the question asked is what type the
        // value has and never whether it is there, which is how every other
        // field in here is read: a key that is missing leaves the default
        // standing and says nothing about it. Warning would be worse than
        // useless, because it would fire exactly once on every machine that had
        // used the feature before today, and the correct response to it would be
        // to do nothing.
        if (typeof data.followWindow === "boolean")
            root.following = data.followWindow;

        // AND THE BINDING, RESTORED OPTIMISTICALLY AND NOT CHECKED HERE. There
        // is nothing to check it against yet: Quickshell's client model is
        // still empty this early and would answer "gone" for a window that is
        // perfectly alive. So the address is taken at face value and the poll
        // is left to find out, which it does within a second either way; see
        // pollBound for why that is a count and not a test.
        //
        // UNDER THE MODE, THOUGH. A file claiming a binding while claiming the
        // mode is off has been edited by hand or written by something older,
        // and the mode is the one to believe: a binding that outlives its own
        // switch is the state unbindWindow exists to make unreachable, and a
        // state file is not a licence to reach it.
        if (root.following && typeof data.boundWindow === "string" && typeof data.boundWindowName === "string" && data.boundWindow) {
            root.bound = data.boundWindow;
            root.boundName = data.boundWindowName;
        }

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

            // AND THE BINDING GETS THE LAST WORD HERE TOO, for cancel()'s
            // reason read from the other end. The rectangle above is the one
            // the file remembered, which is where the bound window was when the
            // shell last wrote it down, and a window is under no obligation to
            // still be there after a restart. This is also the first moment at
            // which followBound is willing to act at all, since it refuses to
            // move anything before `settled`, so without this call a restored
            // binding whose window then held still would have gone on pointing
            // at the remembered rectangle for as long as nothing moved.
            root.followBound();
            return;
        }

        if (s)
            console.warn(`PenMap: the saved mapping is on "${s.monitor}", which is not connected; starting from the focused screen instead.`);

        // NOTHING SAVED, SO NOTHING PUSHED. The outline has somewhere sensible
        // to appear the first time the editor is opened, and until it is opened
        // the compositor's own device block is the mapping and is untouched.
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

    // HOW LONG A CONTACT HAS TO BE QUIET before the next press off the same
    // button is believed, in milliseconds.
    //
    // THE TWO THINGS BEING TOLD APART are switch bounce and a person pressing
    // twice, and they are nowhere near each other. A contact bounces for
    // single-digit milliseconds when it is healthy and for a few tens of them
    // when it is worn, which is what this pad's BTN_0 is.
    // The fastest a hand can press, release and press again on purpose is
    // around a fifth of a second, which is roughly where every toolkit's
    // double-click threshold sits for the same reason. The line therefore goes
    // between them, and nearer the bounce than the hand.
    //
    // REJECTED, both ends: the 20 to 30ms a textbook switch debounce uses,
    // because that is sized for a contact in good order and this one
    // demonstrably is not, and the 400 to 500ms of a double-click window,
    // because that is long enough to eat a real second press from somebody who
    // already knew where they wanted the rectangle. 150 gives a worn contact an
    // order of magnitude more settling time than a healthy one needs and is
    // still over before a hand could deliberately ask again.
    //
    // AND THE TWO MISTAKES DO NOT COST THE SAME, which is what decides which
    // way to err. Swallowing a real press costs one more press. Believing a
    // bounce opens the editor and commits it in the same millisecond, which is
    // the failure this whole toggle exists to remove, so the guard is sized to
    // be generous about the first in order to be strict about the second.
    readonly property int chatterGuard: 150

    // WHEN EACH PAD BUTTON'S CONTACT LAST MOVED, keyed by evdev code, in
    // milliseconds.
    //
    // PER CODE, NOT ONE CLOCK FOR THE PAD. The buttons are separate contacts
    // and bounce separately, so what the aspect key is doing says nothing about
    // the state of the one that opens the editor. Sharing a single timestamp
    // between them would let a press of either swallow a press of the other,
    // which is a pad that ignores people for no reason they can see.
    property var padEdgeAt: ({})

    // IS THIS EDGE THE HAND OR THE CONTACT, and the clock is reset either way.
    //
    // RETRIGGERABLE, and counted from EVERY edge rather than from the last
    // press that was believed, because a release bounces exactly as a press
    // does and the reader faithfully narrates that bounce as `up`, `down`,
    // `up`, `down`. Under the old hold those spare lines were ugly and
    // harmless: they committed the same rectangle two or three times over as
    // the finger came off. Under a toggle the first spare `down` is a second
    // press, so it would close the editor at the exact moment the button was
    // released, which is the hold rebuilt by accident out of the very fault the
    // toggle was meant to escape. Letting an `up` reset the clock too puts the
    // whole burst inside one quiet window, and none of it is heard.
    function padSteady(code: int): bool {
        const now = Date.now();
        const last = root.padEdgeAt[code];
        root.padEdgeAt[code] = now;
        return last === undefined || now - last >= root.chatterGuard;
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

            // THE PAD IS BACK, SO THE EDIT IT INTERRUPTED SURVIVES. The grace
            // started by `gone` is called off and an editor that was open is
            // left open, in the state the hand left it in.
            padLost.stop();

            // AND THE DEBOUNCE STARTS FROM NOTHING. The reader documents this
            // word as "opened, and nothing is held", which makes it a hard
            // resync point rather than an event: it is not a `down`, so it
            // opens and closes nothing, and the only state it touches is the
            // record of when each contact last moved, which is stale by however
            // long the tablet was away. Clearing it means the first press after
            // a reconnect is believed at once instead of being weighed against
            // an edge from before the disconnect.
            root.padEdgeAt = {};
            return;
        }

        if (verb === "gone") {
            root.padAlive = false;
            root.padEdgeAt = {};

            // A PAD THAT VANISHES MID-EDIT IS NO LONGER A RELEASE, and that is
            // the part of this the toggle changed. Under a hold it was one: the
            // finger came off with the connection whether the user meant it or
            // not, so cancelling was the only honest reading and the only way
            // not to be left with an overlay the pen could never dismiss. Now
            // the editor is open because somebody opened it, and the tablet
            // dropping off Bluetooth says nothing about whether they are done.
            // It goes when the tablet sleeps, when the machine suspends and
            // when the thing is picked up and carried to the sofa, all of which
            // a half-placed rectangle should survive, because the pad nearly
            // always comes back and the `ready` above hands the gesture back
            // exactly where it was.
            //
            // NEARLY ALWAYS IS NOT ALWAYS, hence the grace. A flat battery is a
            // pad that never returns, the overlay swallows the pointer on every
            // screen while it is up, and an editor whose only button is gone is
            // the worst state this file can leave a desk in. The timer is the
            // whole of the difference between the two cases: quiet for long
            // enough and the disconnect was real, so the edit is cancelled, the
            // tablet is re-bound and the mouse comes back on its own.
            // `banditshell penmap cancel` is the way out for the seconds in
            // between, and it stays the way out whatever this timer decides.
            if (root.editing)
                padLost.restart();
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

        // EVERY EDGE RESETS THAT BUTTON'S CLOCK, believed or not, which is why
        // this is asked out here rather than inside the branches: an `up` has
        // to count as movement on the contact even though nothing acts on one
        // any more. See padSteady for why that is the half a toggle needs.
        const steady = root.padSteady(code);
        if (verb !== "down" || !steady)
            return;

        const cfg = Config.values.pen;

        // TOGGLED, NOT HELD. A press opens the editor and the next press
        // applies it, so the gesture is bounded by two deliberate presses
        // instead of by a contact staying shut for the length of a drag. The
        // release edge means nothing here at all now, which is the point of the
        // change: on this pad the button chatters, and one dropped contact
        // mid-drag used to commit the mapping halfway through a move.
        //
        // A STATE IT CAN GET STUCK IN is what a toggle buys with that, and it
        // is paid for twice: `gone` above will not leave an editor open forever
        // with no pad behind it, and `banditshell penmap cancel` puts the
        // tablet back from outside the shell whatever else has gone wrong.
        if (code === cfg.toggleButton) {
            if (root.editing)
                root.commit();
            else
                root.begin();
        } else if (code === cfg.aspectButton) {
            // STILL A PLAIN PRESS-TO-TOGGLE, and independent of the other
            // button in every way that matters: its own contact, its own entry
            // in padEdgeAt, its own quiet window.
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
            root.padEdgeAt = {};

            // The reader is written never to exit on its own, so being here at
            // all means something outside it went wrong: no python3, the script
            // gone from the checkout, or it was killed. The feature is dead
            // until it comes back and nothing else would say so, hence the
            // retry; the delay is there so that a script that cannot start
            // fails twice a second forever instead of as fast as fork allows.
            //
            // AN OPEN EDITOR IS TREATED EXACTLY AS `gone` TREATS ONE, on
            // purpose. From in here a reader that died and a tablet that went
            // to sleep are the same event, an edit with no button behind it any
            // more, and the retry means both usually end the same way, in a
            // `ready` a second or two later that hands the gesture back. One
            // grace decides "it came back" against "it is not coming back", in
            // one place, rather than this path holding an opinion of its own.
            if (root.editing)
                padLost.restart();
            padRetry.restart();
        }
    }

    Timer {
        id: padRetry

        interval: 2000
        onTriggered: root.syncPad()
    }

    // HOW LONG AN OPEN EDITOR OUTLIVES THE PAD IT WAS OPENED FROM.
    //
    // LONG ENOUGH TO BE A RECONNECT, SHORT ENOUGH TO BE NOTICED. The reader
    // rescans every two seconds, so a tablet that wakes up is heard from within
    // about that, and a Bluetooth link that drops and re-establishes itself is
    // a handful of seconds at its worst. Half a minute covers both several
    // times over and is still shorter than the time it would take somebody to
    // work out why the pointer had stopped answering.
    //
    // IT CANCELS RATHER THAN COMMITS, because a rectangle that was still being
    // moved when the tablet went away was never agreed to, and the one thing
    // known for certain about this moment is that nobody is watching the pen.
    // cancel() is also the call that re-binds the tablet, which is the whole
    // reason there is a deadline at all.
    Timer {
        id: padLost

        interval: 30000
        onTriggered: root.cancel()
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

        // THE WINDOW WENT, so there is nothing left to follow.
        //
        // AND THE REGION STAYS EXACTLY WHERE IT IS, which is the part worth
        // being deliberate about. The window's last rectangle is the last thing
        // the tablet was pointing at and is where the hand still expects to be
        // pointing; the alternatives are all worse. Snapping back to whatever
        // was mapped before the binding would move the pen at the moment
        // somebody closed an unrelated window. Falling to a default would throw
        // away a mapping that was chosen on purpose. Following the window into
        // nothing is not a thing a rectangle can do. So the binding is dropped,
        // the rectangle is frozen, and the next gesture decides what happens
        // next, which is the same answer boundRect gives for a window that has
        // merely gone off screen.
        //
        // HEARD HERE RATHER THAN INFERRED from the client model going quiet,
        // because this signal says which window and says it at once, and
        // Hypr already emits it for its own reasons. The poll's miss count is
        // the backstop for the closures no signal can carry, not the mechanism.
        function onWindowClosed(addr: string): void {
            if (root.bound && root.bareAddress(addr) === root.bareAddress(root.bound))
                root.unbindWindow();
        }
    }

    Component.onCompleted: {
        root.scanMonitors();
        root.syncPad();
    }
}
