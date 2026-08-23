pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import qs.config
import qs.components
import qs.services

// STYLE: plates. A column of floating cells, and ONE marker that travels to the
// one you are on.
//
// A workspace is not a number, it is the windows you left there, so each cell
// carries one mark per window. Nothing here is labelled 1..N: the column IS the
// order.
//
// THEY FLOAT, and that is the whole of what changed. This used to be a rack of
// index tabs hinged on the screen's edge: every plate started at x = 0, ended
// flat there, and said its state by how far it reached in. It drew well and it
// belonged to nothing, because the rest of this shell is made of sheets that sit
// CLEAR of the edges they are near - the gauges, the tray, the menus, the power
// panel, all of them a rounded box with the band's own air on every side. One
// group hinged on the display while everything above and below it floated read
// as a different shell's idea that had been left in.
//
// So a workspace is a G2 cell in the same lane the gauges stand in, held off the
// screen by the same band it is drawn on, rounded on all four corners by the one
// primitive (components/G2Rect.qml, ~/.claude/rules/g2-corners.md). Nothing here
// picks a radius: everything drawn in this file asks for the shell's own, and at
// these sizes the corner budget clamps it to half the short side, so each shape
// is as round as its size allows and the whole column is one family with the
// status icons below it.
//
// WHERE YOU ARE IS ONE SHAPE THAT MOVES. It used to be a property of each plate:
// the one you were on grew to full reach and lit an accent sheet, the one under
// the cursor swelled, and every other plate answered by not doing that. Nothing
// travelled, so switching workspace was one plate ending and another beginning
// somewhere else and the eye had to re-find the mark each time. The power menu
// and both sidebar groups are built on the other answer, and this is that answer
// applied to the column they sit around: ONE accent marker that chases the
// active cell, and ONE neutral marker that chases whatever the cursor is on,
// both on the exponential smoothing everything in this shell tracks with (fast
// when far, gentle when close, correct at any frame time: components/Follow.qml
// and ~/.claude/rules/animation-smoothing.md).
//
// The markers chase the layout's TARGET geometry rather than its live smoothed
// geometry, and that is not a detail. The model is already chasing the same
// target at the same rate, so a marker aimed at the target decays along exactly
// the trajectory the cell under it is decaying along: the two stay in lockstep
// through a reflow, and a workspace switch is the only thing that ever puts
// daylight between them. Aimed at the live value instead, the marker would be
// smoothing an already smoothed number and would trail its own cell every time a
// window opened.
//
// LENGTH IS STILL THE STATE, measured on the axis that survived the move. A cell
// is as tall as the windows on it, an empty workspace is a dot rather than a full
// cell, and the marker takes the size of the cell it lands on. What is gone is
// the tick: three saturated pixels hard against the display made sense as a ruler
// down the edge, and there is no edge in this drawing to rule. The accent lives
// in the marker's own sheet now, which is the thing that moves.
//
// SCRATCHPADS GET A RACK OF THEIR OWN, under the column and clear of it, in the
// same lane and floating by the same rule. One bar each, an icon tall where a
// workspace is a whole slot, carrying their own marks. They keep the plates' grammar because it is
// the same grammar: a bar with nothing on it is a stub, a bar with windows is as
// long as its marks need, and the one you have pulled open is gone from the rack
// because it is out on the cell you are on. The hover marker runs down here too,
// so the cursor is answered by one shape from the top of the column to the bottom
// of the rack rather than by two different mechanisms that happen to look alike.
//
// THE COLUMN IS ALSO A SURFACE YOU SCRUB. A vertical drag anywhere on the
// numbered part of it steps the active workspace along with the hand, one
// step per one-row pitch, switching at every boundary so the desktop is the
// preview (DESIGN.md 15: the drag is the primary gesture, the tap is the
// fallback that stays). Two fingers scrolled down the column are the same
// gesture and not a second one: same direction, same pitch, same switch at
// every boundary, because a laptop's touchpad is how this shell is used most
// and a gesture that only exists for a press does not exist there. The
// tracking lives in WorkspaceModel for both inputs; this file only wires its
// three surfaces into it and keeps the rack out of it.
Item {
    id: root

    // WHICH SCREEN THIS COLUMN IS ON, by output name, handed straight to the
    // model and never read here: a style draws what the model says, and which
    // workspaces those are is the model's question. See WorkspaceModel.screen.
    required property string screen

    // WHAT A WINDOW IS DRAWN AS: the Nerd Fonts mark for the application itself
    // (`brand`), the icon theme's artwork as shipped (`colour`), or the Material
    // Symbol for what kind of thing it is (`glyph`). See config.json.
    readonly property string iconMode: Appearance.sizes.wsIconMode

    readonly property int slot: Appearance.sizes.wsSlot
    readonly property int iconSize: Appearance.sizes.wsIcon
    readonly property int pitch: Appearance.sizes.wsWindowPitch

    // THE LANE: where a full-width cell stands, centred in the whole band.
    //
    // This item is given the band's entire width because its targets are (a cell
    // is aimed at across the bar, not at the 32px it draws), so the drawing has
    // to place itself. Centred, the cell ends up standing the band's own
    // thickness off the display, which is the distance every other sheet in this
    // shell is held off the edge it is near: the workspaces float on the same
    // rule as the gauges below them rather than on a number of their own.
    readonly property real lane: Math.round((root.width - root.slot) / 2)

    // AN EMPTY WORKSPACE IS A DOT. Same fraction the old style spent on how far
    // an empty plate reached, spent on the cell's own size instead: a place you
    // can go, said as quietly as this drawing can say it, and unmistakably not a
    // workspace with something on it. It is round because the corner budget
    // rounds it (see the header), not because a circle was picked.
    readonly property int dot: Math.round(root.slot * Appearance.sizes.wsEmptyReach)

    // The one corner in this file. Everything drawn here is a G2Rect at this
    // radius, so the marker and the cell it is under are the same shape and the
    // clamp does the rest.
    readonly property real radius: Appearance.rounding.normal

    // HOW FAR A SLOT'S TARGET REACHES PAST THE SLOT, above and below, and the
    // two halves add up to exactly the gap between slots.
    //
    // The column is a run of things to press with air between them, and the air
    // belonged to nobody: run the cursor slowly down the sidebar and it turned
    // from a hand to an arrow and back at every gap, four times on the way past
    // five workspaces. Nothing was wrong except that the pointer kept saying so.
    //
    // Split rather than overlapped, and floor above with the remainder below, so
    // that slot i's target ends on the exact pixel slot i+1's begins whatever the
    // gap is set to. An odd gap leaves no seam and no double-claimed row; the
    // boundary lands nearer the slot whose air it was.
    //
    // It also does what a bigger target always does: the empty workspaces are
    // 9px dots, and this is another twelve pixels of column that hits one.
    readonly property int bleedUp: Math.floor(Appearance.sizes.wsGap / 2)
    readonly property int bleedDown: Appearance.sizes.wsGap - root.bleedUp

    // THE RACK'S OWN RHYTHM: a bar is ONE ORDINARY ICON tall, where a cell is a
    // whole workspace slot.
    //
    // That difference is the only thing keeping the rack from reading as more
    // workspaces, and it has to be a real one. Floating put the bars in the
    // cells' own lane, so they lost the thing that used to separate them (a
    // hinged row against a hinged column, at different lengths) and gained the
    // cells' shape; a bar within a few pixels of a cell's height is then simply a
    // sixth workspace with a smaller icon in it. Held to the size an icon is
    // everywhere else in this shell, a bar is visibly furniture of a different
    // order, and the stand-off above the rack is a break rather than one more
    // step down the column.
    readonly property int barH: Appearance.font.iconSize
    readonly property int barGap: Math.round(Appearance.padding.small / 2)
    readonly property int rackGap: Appearance.padding.large

    // The bar's one mark, sized off the bar rather than off the cell's mark: a
    // scratchpad is answering "which one is this" and not "what is on this
    // workspace", so it needs a mark you can name, not a mark you can read a list
    // of. See `barSpec` for what that mark actually is.
    readonly property int barMark: Math.round(root.barH * 0.7)

    // How much narrower an open card is than the cell it lies on, so the thing it
    // is covering stays visible past its sides and the stack reads as a stack.
    // Small: this is still a card on a card.
    readonly property real overhang: Math.round(Appearance.padding.small / 2)

    property int hovered: -1
    property int racked: -1

    // WHICH SCRATCHPADS THERE ARE, IN AN ORDER THAT HOLDS STILL.
    //
    // Hyprland lists them in the order they were created, so closing Spotify and
    // opening it again moves it past Discord and the rack you learned last week
    // is a different rack today. Names listed in `sidebar.workspaces.specials`
    // are pinned to their place in that list and KEEP it while they are empty, so
    // a scratchpad that is not open yet leaves its own slot rather than shoving
    // the others along when it arrives. Anything unlisted follows, by name, which
    // is at least the same order every session.
    readonly property var deck: {
        const want = Appearance.sizes.wsSpecials;
        const live = Hypr.specials;
        const out = [];
        for (const name of want)
            out.push(live.find(s => s.label === name) ?? ({
                        id: 0,
                        name: `special:${name}`,
                        label: name,
                        windows: []
                    }));
        for (const s of live.slice().sort((a, b) => a.label.localeCompare(b.label)))
            if (want.indexOf(s.label) < 0)
                out.push(s);
        return out;
    }

    readonly property real rackTop: layout.total + root.rackGap
    readonly property real rackHeight: root.deck.length ? root.deck.length * root.barH + (root.deck.length - 1) * root.barGap : 0

    function barY(i: int): real {
        return root.rackTop + i * (root.barH + root.barGap);
    }

    // ONE MARK PER BAR, AND IT IS THE APPLICATION'S OWN.
    //
    // A bar answers "which one is this" and never "what is on this workspace":
    // that second question belongs to the card, which is where the windows are
    // drawn one per row. So the bar carries a single mark, and the whole job of
    // the four functions below is to make it as SPECIFIC as the contents allow.
    //
    // It used to carry a mark per window, capped by how many fit, and the lane is
    // exactly one mark wide: so a scratchpad with two windows in it drew nothing
    // but an "and more" ellipsis, which is the one drawing that answers neither
    // question. Spotify with a popup open stopped looking like Spotify.
    //
    // THE LADDER, most specific first: the application's own brand mark when
    // every window on the bar is the same application, the category glyph they
    // agree on when they are not (Discord and Telegram are both a globe, which is
    // exactly right for a bar holding both), and the generic mark when even that
    // disagrees. The name over the bar is the same ladder in words, so the label
    // and the mark can never say different things.
    function barClass(entry: var): string {
        const classes = entry.windows.map(w => Hypr.classOf(w));
        if (!classes.length)
            return "";
        return classes.every(c => c === classes[0]) ? classes[0] : "";
    }

    // The mark's spec, asked for as BRAND whatever the column is set to: the
    // category glyph is the one mode that cannot say which application this is,
    // and that is the only thing a bar has to say. Empty when the bar is holding
    // more than one application, so the glyph below is what gets drawn.
    function barSpec(entry: var): string {
        const cls = root.barClass(entry);
        return cls ? AppIcons.markFor(cls, "brand") : "";
    }

    function barGlyph(entry: var): string {
        const icons = entry.windows.map(w => Apps.iconFor(Hypr.classOf(w)));
        if (!icons.length)
            return "";
        return icons.every(i => i === icons[0]) ? icons[0] : Apps.genericIcon;
    }

    // WHAT THE BAR IS CALLED, which is what is ON it rather than what the slot
    // was named. A rack of scratchpads is a rack of applications: `music` is
    // Spotify and will only ever be Spotify, and `communication` is Discord until
    // Telegram is open too. The workspace's own name is the fallback, for a bar
    // holding several things or nothing, and it is the name you chose for the
    // slot, so it is exactly right for "more than one of these".
    function barName(entry: var): string {
        const cls = root.barClass(entry);
        if (cls)
            return Apps.nameFor(cls);
        const label = entry.label ?? "";
        return label ? label.charAt(0).toUpperCase() + label.slice(1) : "";
    }

    // HOW LONG A BAR IS, in the plates' own language: a stub when there is
    // nothing on it, and the lane's own share when it is carrying something.
    // Length is the state here too, it is just measured along the other axis.
    function barWidth(entry: var): real {
        return entry.windows.length ? Math.max(Math.round(root.slot * Appearance.sizes.wsBusyReach), root.barMark + root.barGap * 2) : root.dot;
    }

    implicitHeight: layout.total + (root.deck.length ? root.rackGap + root.rackHeight : 0)

    WorkspaceModel {
        id: layout

        screen: root.screen
        base: root.slot
        pitch: root.pitch
        // THIS COLUMN DRAWS APPLICATIONS, so the several windows of one that
        // stacks are one row and a count rather than a run of identical marks.
        // See WorkspaceModel.stack and Apps.stackClasses.
        stack: true
    }

    // WHICH SLOT THE ACCENT MARKER IS AIMED AT, and whether it is on this column
    // at all.
    //
    // The active id is an absolute workspace number and this column is a run of
    // them, so the slot it lands on is how far into THIS screen's run it sits.
    // It can be outside the run: the compositor will happily put you on a
    // workspace this monitor's band does not contain, and the honest drawing of
    // that is no marker, not a marker parked on the nearest end. `held` keeps the
    // last slot it was legitimately on, so leaving the band fades the marker out
    // where it stands rather than sliding it home first.
    readonly property int activeIndex: layout.active - layout.band
    readonly property bool onColumn: root.activeIndex >= 0 && root.activeIndex < layout.slots.length

    property int held: 0

    // THE TARGET GEOMETRY, not the live one: see the header. A binding rather
    // than a value copied in the handler below, so a reflow under the marker
    // moves it with the cell instead of leaving it where the cell used to be.
    readonly property var heldGeom: layout.slots[root.held] ?? ({
            y: 0,
            h: root.slot
        })

    // Where the cell you are on currently IS, smoothed by the model, so a card
    // lying on it travels with it rather than after it. The card is pinned to
    // what is drawn, which is the live value; the marker chases the target. They
    // are the same number at rest and that is the only time either is read.
    readonly property var activeGeom: layout.at(root.held)

    onActiveIndexChanged: {
        if (!root.onColumn)
            return;

        // ARRIVING COLD, LAND ON IT. A marker faded out has nothing to travel
        // from: flying in from wherever the column left it a minute ago is
        // motion across workspaces nobody went to. Sampled off the reveal's live
        // value rather than off the index, so a workspace that leaves the band
        // and comes straight back is still travelling.
        const cold = markShown.value < 0.01;
        root.held = root.activeIndex;
        if (cold) {
            markY.snap();
            markH.snap();
        }
    }

    // WHAT THE CURSOR IS ON, as one held answer for the whole column.
    //
    // Exactly one of these is set: a slot index, or a bar index, or neither,
    // which is the cursor having left. Leaving HOLDS the marker where it is and
    // fades it; only arriving somewhere real moves it. That is why this is driven
    // from the two change handlers rather than from a binding: "nothing" is not a
    // position, and a binding written to express "hold" reads its own value back
    // and loops.
    property int heldSlot: 0
    property int heldBar: -1

    readonly property bool hovering: root.hovered >= 0 || root.racked >= 0

    readonly property var hoverGeom: {
        if (root.heldBar >= 0) {
            const e = root.deck[root.heldBar];
            return {
                y: root.barY(root.heldBar),
                h: root.barH,
                w: e ? root.barWidth(e) : root.dot
            };
        }
        const s = layout.slots[root.heldSlot] ?? ({
                y: 0,
                h: root.slot
            });
        // THE SIZE OF THE THING UNDER THE CURSOR, which for an empty workspace is
        // the dot and not the slot it stands in. The marker is a highlight, and a
        // highlight is the shape of what it is highlighting: a full cell drawn
        // around a dot is the shell answering with a workspace that is not there,
        // and it makes the empty slots look like they grow when you point at them.
        // Centred in the slot, because the dot is.
        const solid = root.slotSolid(s);
        const h = solid ? s.h : root.dot;
        return {
            y: s.y + (s.h - h) / 2,
            h,
            w: solid ? root.slot : root.dot
        };
    }

    // WHETHER A SLOT IS DRAWN AS A FULL CELL OR AS A DOT. Asked here rather than
    // worked out in the delegate, because the hover marker has to agree with the
    // cell it lands on to the pixel and the two are not in the same object: the
    // marker is one shape outside the Repeater, and a second copy of this test
    // would be the one thing standing between them.
    function slotSolid(s: var): bool {
        return !!s && (s.windows.length > 0 || layout.active === s.id);
    }

    onHoveredChanged: if (root.hovered >= 0)
        root.mark(root.hovered, -1)

    onRackedChanged: if (root.racked >= 0)
        root.mark(-1, root.racked)

    function mark(slotIndex: int, barIndex: int): void {
        const cold = lit.value < 0.01;
        root.heldSlot = slotIndex;
        root.heldBar = barIndex;
        if (cold) {
            hoverY.snap();
            hoverH.snap();
            hoverW.snap();
        }
    }

    // THE COUNT TAGS: how many windows each stacked mark on the hovered workspace
    // stands for, as data rather than as something a delegate owns.
    //
    // Computed here because two different things need the same numbers and they
    // are not in the same place: the drawing, which is a Repeater below, and the
    // BLOB, which has to travel all the way up to the chassis so the shell grows
    // material under a tag that hangs past the band (see `blobs`). A tag built
    // inside a slot's delegate can draw itself and cannot tell anyone where it
    // is, and a second copy of this arithmetic up there would be a second copy to
    // keep in step.
    //
    // Only the hovered workspace has any, which is the whole point of a tag: the
    // column at rest is a column of marks, and "three of them" is a question you
    // ask about the one you are already pointing at.
    readonly property var tags: {
        if (root.heldBar >= 0)
            return [];
        const s = layout.slots[root.heldSlot];
        if (!s)
            return [];
        return s.marks.filter(m => m.count > 1).map(m => ({
                    row: m.row,
                    count: m.count
                }));
    }

    // WIDTH FROM THE DIGITS, measured once rather than per tag.
    //
    // The shell's face is MONOSPACED, so every numeral takes the same advance and
    // the ink of a number is the advance times one less than its length, plus a
    // single digit's ink. One TextMetrics answers for every count there will ever
    // be, where a tag that measured its own string would need one apiece and
    // could not be arithmetic at all.
    TextMetrics {
        id: digit

        font.family: Appearance.font.family
        font.pixelSize: Appearance.font.size.small
        text: "0"
    }

    readonly property real tagAir: Math.round(Appearance.padding.small / 2)

    function tagWidth(count: int): real {
        const digits = `${count}`.length;
        return Math.round((digits - 1) * digit.advanceWidth + digit.tightBoundingRect.width) + root.tagAir * 2;
    }

    readonly property real tagHeight: Math.round(digit.tightBoundingRect.height) + root.tagAir * 2

    // WHERE A TAG STANDS: just clear of the mark, and hanging off the band's
    // inner edge on purpose.
    //
    // It used to be right-aligned INSIDE the band, which put it hard against the
    // screen's edge with no shell either side of it, and a tag two digits long
    // grew back over the mark it belongs to. Out here it is the same size
    // whatever the count, it never covers the mark, and the part past the band is
    // carried by the shell itself: the blob below grows the body around it, so it
    // reads as a tab pulled out of the bar rather than a pill floating on the
    // desktop.
    readonly property real tagX: root.lane + (root.slot + root.iconSize) / 2 + root.tagAir

    // How much shell there is around a tag, which is what makes it look SET IN
    // the body rather than stamped on it. The blob is the tag's box grown by this
    // on every side.
    readonly property real tagBed: Appearance.padding.small

    function tagY(row: int, h: real): real {
        return hoverY.value + (root.slot - root.pitch) / 2 + row * root.pitch + (root.pitch - h) / 2;
    }

    // WHAT THE CHASSIS HAS TO GROW, in this item's coordinates, for the sidebar
    // to pass up (Sidebar.blobs, ShellWindow's panel list). A blob is not drawn
    // here at all: it is one more shape in the shell's distance field, so where
    // it pokes out past the band the two MELT together instead of one being
    // parked against the other. Same construction the tooltip uses, at the same
    // third of a panel's melt, because it is the same kind of thing: a small
    // shape that has to look like it came out of the body.
    readonly property var blobs: root.grown.value < 0.01 ? [] : root.tags.map(t => {
        const w = root.tagWidth(t.count) * root.grown.value + root.tagBed * 2;
        const h = root.tagHeight * root.grown.value + root.tagBed * 2;
        return {
            x: root.tagX + (root.tagWidth(t.count) - w) / 2 + root.tagBed,
            y: root.tagY(t.row, h - root.tagBed * 2) - root.tagBed,
            w,
            h,
            radius: Math.min(Appearance.rounding.normal, h / 2),
            smooth: Appearance.sizes.melt / 3
        };
    })

    readonly property Follow grown: growth

    // A TAG GROWS, it does not fade. Everything else in this shell that arrives
    // beside something arrives by swelling out of it, and with the blob under it
    // that is what the melt has to work with: a shape at full size behind a
    // rising opacity would pop a bulge into the band's edge at frame one.
    Follow {
        id: growth

        speed: Appearance.anim.revealSpeed
        target: root.tags.length && root.hovering && !layout.scrubbing ? 1 : 0
        epsilon: 0.005
    }

    // THE FOUR CHASES. Position and size run at the same rate on purpose: a
    // marker that slides and resizes at once is ONE object changing shape, and
    // its edges only read that way while both motions decay together. The two
    // reveals are the other kind of question (is there a marker at all) and run
    // at the reveal rate, which is faster, because a fade is a state changing
    // rather than a movement you follow.
    Follow {
        id: markY

        speed: Appearance.anim.trackSpeed
        target: root.heldGeom.y
    }

    Follow {
        id: markH

        speed: Appearance.anim.trackSpeed
        target: root.heldGeom.h
    }

    Follow {
        id: markShown

        speed: Appearance.anim.revealSpeed
        target: root.onColumn ? 1 : 0
        epsilon: 0.005
    }

    Follow {
        id: hoverY

        speed: Appearance.anim.trackSpeed
        target: root.hoverGeom.y
    }

    Follow {
        id: hoverH

        speed: Appearance.anim.trackSpeed
        target: root.hoverGeom.h
    }

    Follow {
        id: hoverW

        speed: Appearance.anim.trackSpeed
        target: root.hoverGeom.w
    }

    Follow {
        id: lit

        speed: Appearance.anim.revealSpeed
        // Held flat while the scrub is latched, with the cells' own hover answer
        // and for its reason: a hand mid-drag is not choosing the cell it happens
        // to be over, and a second marker lighting under the press argues with
        // the accent one stepping down the column.
        target: root.hovering && !layout.scrubbing ? 1 : 0
        epsilon: 0.005
    }

    // The column exists before it is looked at, so the first frame is a state
    // rather than a transition: the marker is ON the workspace you are on, it did
    // not arrive there.
    Component.onCompleted: {
        root.held = root.onColumn ? root.activeIndex : 0;
        root.heldSlot = root.held;
        markY.snap();
        markH.snap();
        markShown.snap();
        hoverY.snap();
        hoverH.snap();
        hoverW.snap();
    }

    // THE BACKSTOP: the gap pixels, made part of the scrub. The drag is a
    // gesture on the COLUMN, and the column is not one surface: each slot
    // answers its own presses and the gaps between them answered nobody, so a
    // drag that happened to start on one would simply not exist. Declared
    // BEFORE everything drawn, because declaration order is input order (see
    // components/Pull.qml): the cells and the rack keep winning every press
    // they already won, and this catches only what fell between.
    //
    // It ends at the column's end, ON PURPOSE, and that line is the boundary
    // of the whole gesture. The rack below is not part of the scrub: a
    // scratchpad is not a place along the column, it is a card pulled over
    // wherever you already are, so a drag on its bars has no workspace to
    // scrub to. The bars keep their tap and their hold, the stand-off above
    // them stays dead, and the open card (drawn last, over the active cell)
    // keeps its own tap for the same reason.
    //
    // THE BOUNDARY IS THE SAME ONE FOR TWO FINGERS, and for the rack it costs
    // nothing to hold: this rectangle stops at the column's end, the bars sit
    // a whole stand-off below it, and nothing of the scrub lies underneath
    // them, so a scroll over a bar reaches the same nothing a drag on one
    // does. The open card is the single exception and answers it itself, down
    // where it is drawn: it lies ON the active cell, so it is the one
    // surface with a doorway underneath to fall through to.
    MouseArea {
        id: backstop

        x: 0
        y: 0
        width: root.width
        height: layout.total

        // Only once the drag is latched: before that a press is still allowed
        // to turn out to be a tap, and nothing above should be told otherwise.
        preventStealing: layout.scrubbing

        // Mapped to the WINDOW, not to the column: the column re-centres
        // whenever any workspace's height changes, and a moving frame would
        // hand the model that shift as if the hand had made it. The model's
        // scrub block carries the full argument; all three doorways map the
        // same way, or they would disagree about where the drag began.
        onPressed: mouse => {
            const p = backstop.mapToItem(null, mouse.x, mouse.y);
            layout.scrubPress(p.x, p.y);
        }

        onPositionChanged: mouse => {
            if (!backstop.pressed)
                return;
            const p = backstop.mapToItem(null, mouse.x, mouse.y);
            layout.scrubMove(p.x, p.y);
        }

        // A tap on a gap was nothing before this existed and is still
        // nothing: the release is read only to close the gesture out.
        onReleased: layout.scrubRelease()
        onCanceled: layout.scrubCancel()

        // AND THE SAME GESTURE MADE WITH TWO FINGERS, in one line, because
        // the model tracks the scroll through the very functions these
        // handlers call and the primitive writes `accepted` into the event
        // itself. So a touchpad stream becomes a scrub and a mouse wheel is
        // handed straight back to fall through to whatever wanted it, which
        // above this column is nothing: the sidebar holds no scrollable
        // anything, so there is no list here to take a scroll away from.
        onWheel: wheel => layout.scrubWheel(wheel)
    }

    // THE HOVER MARKER, and under it the accent one. Both are declared before
    // anything else that draws, so they sit UNDER the cells and the bars: a
    // marker is the surface a workspace is standing on while it is answered, not
    // a pane over it. The cells are translucent by a few percent, so a marker
    // beneath one reads exactly as the second sheet the active plate used to wear
    // on top of itself, with the difference that this one can move.
    //
    // THE ACCENT FIRST, so a cell that is both active and under the cursor gets
    // the hover marker over the accent rather than instead of it. Two markers on
    // one cell is not two answers: the accent says where you are, the hover says
    // what you are pointing at, and those really are the same cell often enough
    // that the stack has to read.
    G2Rect {
        x: root.lane
        y: markY.value
        width: root.slot
        height: markH.value
        radius: root.radius
        color: Appearance.colour.fillStrong
        opacity: markShown.value

        // THE ACCENT SHEET, over the neutral one rather than instead of it, so
        // the workspace you are on reads as thicker glass with colour in it and
        // not as a stain on the bar.
        //
        // GONE ENTIRELY while a scratchpad card lies on the cell, which is the
        // whole of the ghost this style used to spell out at length. The sheet
        // means "the thing you are looking at" and the card is now wearing it;
        // two tinted shapes in one stack is the focus claimed twice. The neutral
        // sheet stays and keeps its full size, because the workspace is still the
        // one you are on and it is still holding the place you come back to.
        G2Rect {
            anchors.fill: parent
            radius: root.radius
            color: Appearance.colour.accentFill
            opacity: layout.eclipsed ? 0 : 1

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }
    }

    // THE HOVER MARKER: one shape for the whole column, cells and rack alike.
    //
    // It used to be a fill per cell, each brightening on its own hover, and a
    // fixed column of those reads as a flicker rather than as a highlight:
    // nothing travels, so dragging the cursor down the bar is a run of unrelated
    // appearances and the eye has to re-find the mark after every one. One shape
    // carries your attention with it, which is the argument the power menu's
    // marker and both sidebar groups are built on.
    G2Rect {
        x: Math.round((root.width - width) / 2)
        y: hoverY.value
        width: hoverW.value
        height: hoverH.value
        radius: root.radius
        color: Appearance.colour.fillStrong
        opacity: lit.value
    }

    // THE RACK: one bar per scratchpad, at the end of the column.
    //
    // A special workspace is not a sixth workspace, and this is not a sixth slot:
    // it is thinner than any cell, it is the other side of a gap wide enough to
    // be a break rather than a step, and it is a ROW where the column is a
    // column. What it shares with a cell is the only thing worth sharing, which
    // is that the length of the thing tells you the state of the thing.
    //
    // A bar is where the card sleeps. Pulling one open lifts it out of the rack
    // and onto the cell you are on, which is drawn further down this file
    // because a card on top of a cell cannot also be under it; the bar it left
    // stays empty until it comes back, because that is where it is not.
    Repeater {
        // Modelled by a COUNT, for the same reason the cells are: `deck` is
        // rebuilt whenever anything happens to a window, and a Repeater over the
        // array itself would throw away every bar and build it again each time,
        // taking the animation it was in the middle of and the hover it was under
        // with it.
        model: root.deck.length

        delegate: G2Rect {
            id: bar

            required property int index
            readonly property var entry: root.deck[bar.index] ?? ({
                    name: "",
                    label: "",
                    windows: []
                })
            // Matched against the MODEL's shown special, which rides the event
            // stream (services/Hypr.qml): the bar lights, and the card lifts,
            // on the same frame the compositor says so, not an IPC round trip
            // later.
            readonly property bool open: !!bar.entry.name && layout.special === bar.entry.name
            readonly property string name: root.barName(bar.entry)

            // A bar whose card is OUT falls back to the empty stub rather than
            // disappearing: the rack is a set of slots and one of them is empty
            // right now, which is a different thing from the rack being shorter.
            // Where the card itself is, is answered by the card.
            x: Math.round((root.width - width) / 2)
            y: root.barY(bar.index)
            width: bar.open ? root.dot : root.barWidth(bar.entry)
            height: root.barH

            // Floating, like everything else in this column, so all four corners
            // take the shell's radius and the budget clamps a bar this thin into
            // a full round.
            radius: root.radius

            // The same one sheet a cell is. A scratchpad is not more important
            // than the workspace it will lie on, so it cannot be brighter than
            // one: what separates a full bar from an empty one here is length and
            // a mark, exactly as it is up the column. Where the cursor is, and
            // which bar is open, are both said by the markers behind it, which is
            // the whole point of there being markers.
            color: Appearance.colour.fill

            Behavior on width {
                NumberAnimation {
                    duration: Appearance.anim.normal
                    easing.type: Easing.OutCubic
                }
            }

            // WHICH SLOT THE CARD IS OUT OF, said by the one piece of the rack
            // that is allowed to be saturated: the bar the open card belongs to
            // keeps a quiet accent while it is empty, so the way home is not
            // dressed as just another empty stub. This stub is also the summoner
            // that puts the card back (the reversed gesture, DESIGN.md 15).
            G2Rect {
                anchors.fill: parent
                radius: root.radius
                color: Appearance.colour.accentFill
                opacity: bar.open ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.anim.fast
                    }
                }
            }

            // What the bar is carrying, which is nothing at all while its card is
            // out: the marks are ON the card and they went with it.
            Item {
                anchors.fill: parent
                opacity: bar.open ? 0 : 1

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.anim.fast
                    }
                }

                // THE ONE MARK, centred, because a bar is one lane wide and a
                // scratchpad is one thing. Which mark it is, is the ladder up in
                // `barSpec`; an empty bar draws none at all, because a stub with
                // a glyph on it is a bar claiming to hold something.
                AppMark {
                    anchors.centerIn: parent
                    visible: bar.entry.windows.length > 0
                    size: root.barMark
                    spec: root.barSpec(bar.entry)
                    fallback: root.barGlyph(bar.entry)
                    color: Appearance.colour.textDim

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.anim.fast
                        }
                    }
                }
            }

            // The whole row, band-wide and half the gap either side, for the same
            // reason a cell's target is: a 20px lozenge is a mark, not a button,
            // and a stub has to be as easy to hit as a full bar. Nothing else in
            // the rack's rows is reachable, so there is nothing to hit by mistake.
            MouseArea {
                id: barMouse

                x: -bar.x
                y: -root.barGap
                width: root.width
                height: parent.height + root.barGap * 2
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.racked = bar.index
                onExited: if (root.racked === bar.index)
                    root.racked = -1
                onClicked: Hypr.toggleSpecial(bar.entry.name)

                // Whether the current press is the QUESTION rather than the
                // toggle, so the release below only takes down a tip this
                // press put up. Without the flag a plain click would release
                // `bar` too, and Tooltips releases BY ITEM: the hold and the
                // HoverTip share one, so a quick click under a resting cursor
                // would tear down the label hover was still entitled to.
                property bool naming: false

                // HOVER CANNOT SERVE A FINGER: there is no cursor to rest, so
                // the rack's names were unreachable on exactly the device
                // that most needs labels. A press that stays past Qt's
                // long-press beat asks the same question hover asks, through
                // the same request, for the duration of the hold. Qt
                // withholds `clicked` after `pressAndHold`, so holding a bar
                // to learn its name never also operates it, which is the
                // entire point of asking before acting.
                onPressAndHold: {
                    barMouse.naming = true;
                    Tooltips.request(bar, bar.name, true);
                }

                onReleased: if (barMouse.naming) {
                    barMouse.naming = false;
                    Tooltips.release(bar);
                }

                onCanceled: if (barMouse.naming) {
                    barMouse.naming = false;
                    Tooltips.release(bar);
                }

                // The one thing in the rack that says a name out loud. Position
                // is what you actually navigate by once you know it; this is how
                // you come to know it.
                HoverTip {
                    text: bar.name
                    host: bar
                    // WITHOUT THE WAIT. Every other tip in this shell is a second
                    // opinion about a glyph you can already read, and the beat
                    // before one is what keeps the shell quiet as the cursor goes
                    // past. A rack is the other case: the bars are identical
                    // lozenges, the name is the only thing telling one from the
                    // next, and making somebody hold still for the only answer
                    // there is is the shell being coy about it.
                    now: true
                }
            }
        }
    }

    Repeater {
        // Modelled by a COUNT, not by the slot array: a Repeater over a JS array
        // rebuilds every delegate whenever the array is reassigned, and that array
        // is reassigned on every window event. Keyed by an int, the slots persist
        // and only their bindings update.
        //
        // The count includes any GHOST the model is still collapsing, so a
        // workspace that has just stopped existing shrinks away with the column
        // instead of vanishing while the column glides.
        model: Math.max(layout.count, layout.live.length)

        delegate: Item {
            id: slotItem

            required property int index
            readonly property var info: layout.slots[index] ?? ({
                    id: layout.idAt(index),
                    windows: [],
                    marks: []
                })
            readonly property var geom: layout.at(index)
            // The MODEL'S active workspace, which is this screen's own and not
            // the focused one: the sidebar on the monitor you are not looking
            // at still marks the cell you left it standing on.
            readonly property bool isActive: layout.active === slotItem.info.id
            readonly property bool isOccupied: slotItem.info.windows.length > 0
            // A scratchpad is lying on this cell, so its windows are behind
            // one: you cannot see them, and neither should their marks, which
            // would otherwise show through the card and read as two icons in the
            // same place. Derived from the model's `eclipsed` rather than asked
            // of Hypr here, so every style reads the same fact from the object
            // they already share instead of rediscovering it apiece.
            readonly property bool covered: slotItem.isActive && layout.eclipsed

            y: slotItem.geom.y
            width: root.width
            height: slotItem.geom.h

            // The click target is the whole width, cell or no cell: a 12px mark
            // is a mark, not a button, and reaching for a workspace should not
            // mean hitting it.
            //
            // AND A DOORWAY INTO THE SCRUB: press here and drag down the
            // column, and the desktop steps workspace by workspace under the
            // hand. The tracking itself lives in the model, because the gap
            // backstop and the window rows feed the same gesture; this area
            // only maps its events out to the window's frame (the backstop
            // says why not the column's own) and hands them over. A press
            // that never travels past the threshold is still the tap it
            // always was.
            MouseArea {
                id: slotMouse

                // PAST THE SLOT, into the air either side of it: see root.bleedUp.
                // The drawn cell is untouched, this is only what answers.
                anchors.fill: parent
                anchors.topMargin: -root.bleedUp
                anchors.bottomMargin: -root.bleedDown
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                preventStealing: layout.scrubbing
                onEntered: root.hovered = slotItem.index
                onExited: if (root.hovered === slotItem.index)
                    root.hovered = -1

                onPressed: mouse => {
                    const p = slotMouse.mapToItem(null, mouse.x, mouse.y);
                    layout.scrubPress(p.x, p.y);
                }

                onPositionChanged: mouse => {
                    // Hover moves arrive here too (hoverEnabled), and a hover
                    // is not a gesture.
                    if (!slotMouse.pressed)
                        return;
                    const p = slotMouse.mapToItem(null, mouse.x, mouse.y);
                    layout.scrubMove(p.x, p.y);
                }

                // NOT onClicked, for Pull's reason exactly: `clicked` also
                // fires for a press that latched into the scrub and ended
                // back inside the slot, and for one that set off sideways and
                // wandered home, and both of those must do nothing here. The
                // release asks the model what the press turned out to be, and
                // only a press that stayed a press is the tap.
                onReleased: {
                    if (!layout.scrubRelease())
                        Hypr.switchTo(slotItem.info.id);
                }

                onCanceled: layout.scrubCancel()

                // The fingers' doorway, exactly as on the backstop. Each
                // surface takes its own because wheel events go to whichever
                // item is topmost under the pointer and stop at the first one
                // that accepts, so a scroll started over a cell never
                // reaches the backstop underneath it: a single handler down
                // there would answer only the gaps, which is the one part of
                // the column a hand almost never lands on.
                onWheel: wheel => layout.scrubWheel(wheel)

                // A DOORWAY CAN DIE MID-PRESS. The model refuses to pop a
                // trailing ghost while a press is down (see step()), which
                // covers the collapse this file can cause itself; this is the
                // net under any teardown that arrives anyway, because a grab
                // that dies undelivered leaves `scrubbing` latched and every
                // gate reading it (the hover marker, the marks' glow, both
                // preventStealings) frozen until the next press.
                // `onCanceled` cannot be trusted for this: Qt does not
                // promise the signal to an item mid-teardown, and the
                // destruction hook is the one that always runs while the
                // context can still reach the model.
                Component.onDestruction: {
                    if (slotMouse.pressed)
                        layout?.scrubCancel();
                }
            }

            G2Rect {
                id: cell

                // AN EMPTY WORKSPACE IS A DOT, and everything else is the full
                // cell. Going there makes it a cell like any other, which is why
                // the active one is solid whether or not it has anything on it:
                // the workspace you are standing on is not an empty slot even
                // when it is empty.
                //
                // Through the root's own test rather than off this delegate's
                // `isOccupied`, which says the same thing: the hover marker has
                // to land at exactly this size, it is not in this object, and one
                // of the two copies drifting is how a highlight ends up a pixel
                // bigger than the thing it is on.
                readonly property bool solid: root.slotSolid(slotItem.info)

                // THE STATE IS ANIMATED, NOT THE PIXELS. The height resolves
                // through the slot's live height, which is already being smoothed
                // frame by frame; a Behavior on the result would restart a 220ms
                // animation on every one of those frames and the cell would
                // rubber-band behind its own column. Animating the 0-to-1 instead
                // keeps the two motions independent: the reflow stays
                // exponential, the state change eases, neither fights the other.
                readonly property real fullTarget: cell.solid ? 1 : 0

                property real full: cell.fullTarget

                width: Math.round(root.dot + (root.slot - root.dot) * cell.full)
                height: Math.round(root.dot + (parent.height - root.dot) * cell.full)
                x: Math.round((parent.width - width) / 2)
                y: Math.round((parent.height - height) / 2)

                // All four corners, at the one radius. The budget clamps it to
                // half the short side, so a tall cell is a pill and a dot is a
                // circle without either of them asking for a number of its own.
                radius: root.radius

                // ONE COLOUR FOR EVERY CELL, and this is the half of the rethink
                // that is easy to miss. State is not painted on the thing any
                // more: where you are and what you are pointing at are the two
                // markers behind this, and a cell that also brightened would be
                // the same answer given twice, out of step, by a shape that
                // cannot travel.
                color: Appearance.colour.fill

                Behavior on full {
                    NumberAnimation {
                        duration: Appearance.anim.normal
                        easing.type: Easing.OutCubic
                    }
                }

                // ONE ROW PER MARK, CENTRED IN THE CELL, which is why they are
                // children of it: the icons ride the cell as it grows rather than
                // sitting at a fixed place it happens to cover.
                //
                // A MARK IS NOT ALWAYS A WINDOW. The model hands this column
                // applications rather than windows (WorkspaceModel.stack), so the
                // twelve kitty windows on a workspace arrive as one entry with a
                // twelve on it. Everything else is one entry per window with a
                // count of one, and the drawing below never has to know which of
                // the two it got.
                //
                // NOTHING IS DROPPED. There is no cap and no "and more": a
                // workspace with twenty applications on it draws twenty marks and
                // is twenty rows tall. The cap existed because twenty identical
                // terminal glyphs would run the column off the screen, and
                // stacking answers that without throwing anything away.
                Repeater {
                    // A ScriptModel, NOT the array: the array is rebuilt on every
                    // Hyprland event, and a plain-array Repeater would tear down
                    // and rebuild every icon each time. This diffs it, so a window
                    // opening touches only its own row.
                    model: ScriptModel {
                        values: slotItem.info.marks
                    }

                    delegate: Item {
                        id: row

                        required property var modelData
                        required property int index

                        readonly property string appClass: row.modelData.cls ?? ""
                        readonly property int count: row.modelData.count ?? 1

                        // A STACK IS LIT IF ANY OF IT IS. The mark stands for
                        // every window of that application on this workspace, so
                        // it is the focused one whenever the keyboard is in any
                        // of them; asking the representative client alone would
                        // dim the mark the moment you moved to the second
                        // terminal. One window is the same test, said cheaply.
                        readonly property bool lit: row.count > 1 ? slotItem.info.windows.some(w => Hypr.classOf(w) === row.appClass && Hypr.isFocused(w)) : Hypr.isFocused(row.modelData.client)

                        // WHERE IT SITS is the model's answer, not this
                        // delegate's index times a pitch: a mark carrying a count
                        // is taller than one that is not, so the rows below it
                        // are no longer a multiple of anything.
                        x: Math.round((cell.width - root.slot) / 2)
                        y: (root.slot - root.pitch) / 2 + (row.modelData.row ?? row.index) * root.pitch
                        width: root.slot
                        height: root.pitch
                        opacity: slotItem.covered ? 0 : 1

                        // NOTHING IN HERE ANSWERS THE CURSOR, and that is
                        // deliberate. A mark used to be a button: hovering one lit
                        // it and clicking it focused that window. It made the
                        // column answer at two different sizes, a row inside a
                        // pill, so running the cursor down the sidebar lit a
                        // sequence of small things inside the big thing the hover
                        // marker was already lighting. The cell is the control
                        // now, whole, and a mark is a picture on it. Focusing one
                        // window of a workspace was never what the sidebar was
                        // for; going to the workspace is.
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Appearance.anim.normal
                            }
                        }

                        // THE MARK, whatever kind of thing it turns out to be:
                        // what you picked for this application in settings, what
                        // the config named, what the current mode works out, or
                        // the category glyph. One component draws all of them, so
                        // the sidebar cannot disagree with the picker.
                        AppMark {
                            anchors.centerIn: parent
                            size: root.iconSize
                            spec: AppIcons.markFor(row.appClass, "")
                            fallback: Apps.iconFor(row.appClass)

                            // The focused window is the only thing in the column
                            // at full label weight. That is the whole hierarchy:
                            // the marker says which workspace you are on, this
                            // says which window you are in.
                            color: row.lit ? Appearance.colour.text : Appearance.colour.textDim

                            Behavior on color {
                                ColorAnimation {
                                    duration: Appearance.anim.fast
                                }
                            }
                        }

                    }
                }
            }
        }
    }

    // THE COUNT TAGS, DRAWN. One per stacked mark on the workspace under the
    // cursor, standing clear of the mark it belongs to and hanging off the band.
    //
    // Declared out here rather than inside the slot it belongs to, because it
    // does not belong to the slot's rectangle: it reaches past the sidebar
    // entirely, and a shape that leaves its parent should not be a child of it.
    // Where each one goes is `tagX`/`tagY`, which the blob above is built from
    // too, so the shell's bulge and the pill on it cannot drift apart.
    //
    // WEARING THE CELL'S OWN SHEETS, in the same order the cell wears them: the
    // quiet fill, the hover marker's over it, and the accent when this is the
    // workspace you are on. Built as those three shapes rather than as a colour
    // picked to match them, because a colour picked to match stops matching the
    // day one of them moves.
    Repeater {
        model: root.tags

        delegate: G2Rect {
            id: tag

            required property var modelData

            readonly property real fullW: root.tagWidth(tag.modelData.count)

            // Grown about its own centre, so it swells out of a point beside the
            // mark rather than unrolling from a corner.
            width: tag.fullW * growth.value
            height: root.tagHeight * growth.value
            x: root.tagX + (tag.fullW - width) / 2
            y: root.tagY(tag.modelData.row, height)
            visible: growth.value > 0.01

            radius: root.radius
            color: Appearance.colour.fill

            G2Rect {
                anchors.fill: parent
                radius: root.radius
                color: Appearance.colour.fillStrong
            }

            G2Rect {
                anchors.fill: parent
                radius: root.radius
                color: Appearance.colour.accentFill
                visible: layout.active === layout.idAt(root.heldSlot) && !layout.eclipsed
            }

            StyledText {
                anchors.centerIn: parent
                // Centred by INK, not by line box: a numeral sits high in its
                // own line, so a number centred by the box is not centred.
                anchors.horizontalCenterOffset: inkOffsetX
                anchors.verticalCenterOffset: inkOffsetY

                // In after the shape, rather than with it. The pill spends the
                // first part of its growth too small to hold the number, and a
                // numeral scaled up out of nothing is the one thing here that
                // would read as an animation rather than as an arrival.
                opacity: Math.max(0, (growth.value - 0.4) / 0.6)

                text: `${tag.modelData.count}`
                color: Appearance.colour.text
            }
        }
    }

    // THE OPEN SCRATCHPAD, over everything, because that is where it is.
    //
    // It takes the height ITS OWN windows need rather than the height of the
    // cell it covers: a scratchpad is not in the column and does not have to
    // fit the column's rhythm, and a terminal and a notes window in there should
    // look like two things. Slightly narrower than the cell underneath, so what
    // it is covering stays visible past its sides and the stack reads as a stack.
    //
    // IT IS THE BAR, MOVED. Every number here is one end of a line between where
    // this scratchpad lies in the rack and where it lies on the cell you are on,
    // and `shown` is how far along that line it is, so opening and closing is one
    // card travelling rather than one appearing where another vanished. Its marks
    // travel too, and they swing as they go: a row along a bar is a column down a
    // card, and the same interpolation carries them between the two.
    Repeater {
        model: root.deck.length

        delegate: Item {
            id: pad

            required property int index
            readonly property var entry: root.deck[pad.index] ?? ({
                    name: "",
                    label: "",
                    windows: []
                })
            // The model's shown special, same as the bar: the card starts its
            // travel on the event's frame, not after the monitor refresh.
            readonly property bool open: !!pad.entry.name && layout.special === pad.entry.name

            // EVERY WINDOW ON IT, uncapped and unstacked, which is the one
            // place in this file that draws windows rather than applications.
            // The bar answers "which one is this" with a single mark; the card
            // is what answers "what is on it", and a card that dropped the
            // fifth window would be answering neither.
            readonly property var windows: pad.entry.windows
            readonly property int rows: Math.max(1, pad.windows.length)

            // The two ends of the journey: the bar in the rack, and the card on
            // the cell.
            readonly property real full: root.slot + (pad.rows - 1) * root.pitch
            readonly property real cardW: root.slot - root.overhang * 2
            readonly property real cardY: root.activeGeom.y + (root.activeGeom.h - pad.full) / 2
            readonly property real barW: root.barWidth(pad.entry)

            property real shown: pad.open ? 1 : 0

            function reach(from: real, to: real): real {
                return from + (to - from) * pad.shown;
            }

            // Both ends of the travel are centred in the lane, so the card comes
            // straight up the column rather than sliding sideways out of a hinge
            // that no longer exists.
            x: Math.round((root.width - width) / 2)
            width: pad.reach(pad.barW, pad.cardW)
            height: pad.reach(root.barH, pad.full)
            y: pad.reach(root.barY(pad.index), pad.cardY)
            visible: pad.shown > 0

            Behavior on shown {
                NumberAnimation {
                    duration: Appearance.anim.normal
                    easing.type: Easing.OutCubic
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Hypr.toggleSpecial(pad.entry.name)

                // A SCROLL OVER THE CARD IS SWALLOWED, which is the whole of
                // what its press already does and therefore the whole of the
                // rule: the two inputs answer alike, including where the
                // answer is nothing. It has to be said out loud here and
                // nowhere else in the rack, because this is the one piece of
                // it that lies OVER the column. A wheel event this area did
                // not accept falls past it to the cell's own doorway
                // underneath, so the single surface that refuses the drag
                // would be the single surface a swipe went straight through
                // and scrubbed the workspace behind it.
                //
                // Blocked here rather than by declaring the card lower in the
                // file, which would have handed the press away with it: the
                // card genuinely is on top, its tap depends on that, and
                // input order is what says so.
                onWheel: wheel => wheel.accepted = true
            }

            // THE SHADOW, which is the only one in this shell and is here because
            // everything else in the sidebar is a sheet lying flat ON the bar. A
            // scratchpad is the one thing that is off it, and a card resting on a
            // cell with nothing under its edge reads as a hole cut in the cell
            // instead of a card on it.
            //
            // Cast from the card's own silhouette rather than drawn as a darker
            // shape behind it, because a shape behind a translucent card shows
            // straight through it. It is also why the card stopped being glass:
            // see below.
            MultiEffect {
                anchors.fill: card
                source: card
                // Opaque by the halfway point rather than over the whole trip:
                // the card is TRAVELLING, and a card you can see through most of
                // the way is a card that is not there yet.
                opacity: Math.min(1, pad.shown * 2)

                shadowEnabled: true
                shadowColor: "black"
                shadowOpacity: 0.35
                // Soft and barely offset: this is a card lifted off a cell by
                // its own thickness, not a dialog floating over a page. A tight
                // blur at this size comes out as a dark outline around the card,
                // which is a border, and a border is the one thing the chassis
                // spent so long learning not to draw.
                blurMax: Appearance.padding.normal
                shadowBlur: 1
                shadowVerticalOffset: Math.round(Appearance.padding.small / 3)
            }

            G2Rect {
                id: card

                anchors.fill: parent
                // Drawn by the effect above, which needs it as a texture, so the
                // scene must not also draw it directly. Multisampled, because a
                // curve that antialiases itself into the scene has to be given
                // the samples to do it with once it is drawing into a buffer.
                layer.enabled: true
                layer.samples: 4
                visible: false

                radius: root.radius

                // A SURFACE, not more glass. Two veils at 14 and 18 percent over
                // a cell is a card you can see the cell through, and the whole
                // claim being made here is that this is in front of it: the marks
                // underneath showed through their own cover, and a shadow cast on
                // a cell would have shown through it too. So the card is the
                // shell's panel material, which is what everything else that
                // floats is made of, and the cell genuinely disappears behind it.
                color: Appearance.colour.surface

                G2Rect {
                    anchors.fill: parent
                    radius: root.radius
                    color: Appearance.colour.fillStronger
                }

                // THE ACCENT, WHICH CAME WITH IT. The same sheet the marker wears
                // up the column, because this is now the thing it means: the
                // marker is the workspace you are on, this is the one you are
                // looking at.
                G2Rect {
                    anchors.fill: parent
                    radius: root.radius
                    color: Appearance.colour.accentFill
                    opacity: pad.shown
                }

                Repeater {
                    model: ScriptModel {
                        values: pad.windows
                    }

                    delegate: AppMark {
                        id: mark

                        required property var modelData
                        required property int index

                        readonly property real markSize: pad.reach(root.barMark, root.iconSize)

                        // CENTRED AT BOTH ENDS, so the travel is the one thing
                        // that moves: the bar's single mark is centred in the bar
                        // and a card's row is centred in the card, which means the
                        // whole rack unfolds out of one mark and folds back into
                        // it rather than sliding sideways out of a row that is not
                        // there any more.
                        x: Math.round((pad.width - mark.markSize) / 2)
                        y: pad.reach(Math.round((root.barH - mark.markSize) / 2), root.slot / 2 + mark.index * root.pitch - mark.markSize / 2)
                        size: Math.round(mark.markSize)
                        // BRAND, like the bar it came out of: the rack is a rack of
                        // applications, and which one this is stays the question
                        // whether it is folded into a lozenge or opened on a card.
                        spec: AppIcons.markFor(Hypr.classOf(mark.modelData), "brand")
                        fallback: Apps.iconFor(Hypr.classOf(mark.modelData))
                        color: Hypr.isFocused(mark.modelData) ? Appearance.colour.text : Appearance.colour.textDim
                    }
                }
            }
        }
    }
}
