pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

// THE KEYBOARD, for when the machine is folded over and the real one is facing
// the table.
//
// IT IS THE ONE PANEL IN THIS SHELL THAT MUST NOT TAKE THE KEYBOARD.
//
// Every other summoned surface here grabs exclusive focus so it can hear its own
// Escape: the launcher, the power panel, the calculator, the sheet. This one
// sends keystrokes OUTWARD, through the virtual-keyboard protocol, to whatever
// the compositor considers focused. If it held the focus itself, it would be
// that thing, and every key would be typed into the shell. So it is deliberately
// absent from ShellWindow's `keyboardFocus` expression, and that absence is
// load-bearing rather than an oversight: adding it there would not break the
// layout or the drawing, it would silently make the board type into nothing.
//
// WHICH IS ALSO WHY IT HAS NO CATCHER. The panels summoned by name each lay a
// screen-filling MouseArea underneath themselves, because nothing else would
// dismiss something you did not reach for. This one is the opposite case: it is
// open precisely so you can work in the window underneath, so a click off the
// board must reach that window. Its mask is the board and nothing else, and the
// way out is a key ON the board (see Layouts, the `hide` key).
//
// IT OVERLAYS RATHER THAN RESERVING SPACE. An exclusive zone would reflow every
// window on the screen each time the board came up, and a tablet keyboard
// arrives and leaves constantly. Sitting over the bottom of the screen is what
// every touch keyboard does and what the windows underneath already expect.
Item {
    id: root

    // Where the chassis ends. The board starts here, so the two never overlap.
    required property real originX

    // The chassis band's thickness, so the caps stop clear of it rather than
    // running underneath.
    required property int inset

    readonly property bool open: root.shown
    property bool shown: false

    // Only the board. See the header: everything off it belongs to the window.
    readonly property Item maskItem: panel

    // Which of Layouts' pages is showing. Not a modifier state: a tablet has no
    // modifier to hold, so the second page is a place you go rather than a key
    // you press.
    //
    // CALLED `page` AND NOT `layer`, which is the word a keyboard would use,
    // because `Item.layer` is QML's own render-layer group and it is FINAL:
    // declaring one here does not shadow it, it refuses to load the file.
    property string page: plan.base

    // MODIFIERS ARE LATCHED, AND ONE-SHOT. Tapping shift arms it, the next key
    // spends it. That is the phone convention and it is the right one here for
    // the same reason: there is no way to HOLD a key on a sheet of glass while
    // pressing another, so a modifier has to be a state rather than a gesture.
    // Tapping an armed modifier disarms it, so a mis-tap costs a tap.
    property var latched: []

    Layouts {
        id: plan
    }

    // THE BOARD'S GEOMETRY, ALL OF IT DERIVED. Two numbers come in, the panel's
    // width and the configured share of the screen height, and every cap size
    // and position falls out of them. Nothing here is a pixel someone chose.
    readonly property real panelWidth: root.width - root.originX
    readonly property real panelHeight: Math.round(root.height * Config.values.tablet.height)

    readonly property var rows: root.placed
    readonly property int rowCount: root.rows.length

    // The caps' own area, inside the panel's padding and clear of the chassis
    // band along the bottom edge.
    readonly property real boardWidth: root.panelWidth - Appearance.padding.large * 2
    readonly property real boardHeight: root.panelHeight - Appearance.padding.large * 2 - root.inset

    // ONE PITCH ACROSS, ONE DOWN, and they are not the same number. A board wide
    // enough to reach on a 16:10 panel is not five rows tall; see TabletKey.
    readonly property real pitch: root.boardWidth / plan.units
    readonly property real rowPitch: root.rowCount > 0 ? root.boardHeight / root.rowCount : 0
    readonly property real seam: Math.round(root.pitch * Config.values.tablet.seam)

    // EVERY KEY'S PLACE, as a running total of the units to its left. This is
    // the entire layout engine: a key carries a width and never a position, so
    // the board can be rebuilt at any size, and changing a cap's width in
    // Layouts moves everything after it without anything else being touched
    // (~/.claude/rules/math-over-hardcoding.md).
    readonly property var placed: {
        const rows = plan.layers[root.page] ?? [];
        return rows.map((row, r) => {
            let at = 0;
            const cells = row.map(key => {
                const units = key.units ?? 1;
                const cell = {
                    key: key,
                    at: at,
                    units: units
                };
                at += units;
                return cell;
            });
            // CHECKED RATHER THAN TRUSTED. A row that summed to 14.75 would draw
            // one short line and look like a rendering bug rather than a typo in
            // a data file, and the caps would all sit a fraction left of where
            // the hand above them expects. Cheap to verify, miserable to find.
            if (Math.abs(at - plan.units) > 0.001)
                console.warn(`OnScreenKeyboard: page "${root.page}" row ${r} is ${at} units, expected ${plan.units}.`);
            return cells;
        });
    }

    // Parked a full melt-distance below the screen when closed, so a board that
    // is away does not go on pulling the chassis's bottom band toward it. The
    // calculator panel's note, on the other axis.
    readonly property real slide: (root.panelHeight + Appearance.sizes.melt) * (1 - reveal.value)

    // EMPTY WHILE AWAY, rather than parked off-screen like the calculator's.
    // The distance field has twelve slots (BlobField.capacity) and more sources
    // than that could in principle want one, so a panel that is not on screen
    // should not be holding one. It costs nothing here: the board has no
    // hover-summon to be halfway through, so `closed` and `not drawn` are the
    // same instant.
    readonly property var blobs: reveal.value <= 0.001 ? [] : [
        {
            x: root.originX,
            y: root.height - root.panelHeight + root.slide,
            w: root.panelWidth,
            h: root.panelHeight,
            radius: Appearance.rounding.large
        }
    ]

    // NO FOCUS BOOKKEEPING, WHICH IS THE POINT. Every other panel here saves the
    // focused window on the way in and hands it back on the way out, because
    // taking the keyboard unfocuses whatever had it. This takes nothing, so
    // there is nothing to give back and the window you were typing in is still
    // the window you are typing in.
    function show(): void {
        root.shown = true;
    }

    function hide(): void {
        root.shown = false;
        // Dropped on the way out rather than kept. A shift left armed from last
        // time would capitalise the first letter of the next thing typed, days
        // later, for no reason the user could see.
        root.latched = [];
    }

    function toggle(): void {
        if (root.shown)
            root.hide();
        else
            root.show();
    }

    // THE HINGE BRINGS IT UP, if that is what the config asks for. Folding the
    // machine is the clearest statement of intent there is that the physical
    // keyboard is no longer available, so the board answering that by itself is
    // the shell doing what section 2.2 asks: the interaction IS the request.
    //
    // Unfolding puts it away unconditionally, even if it was summoned by hand,
    // because the real keyboard is back under the fingers and two keyboards
    // competing for the same line is nobody's intent.
    function follow(): void {
        if (Tablet.folded) {
            if (Config.values.tablet.autoKeyboard)
                root.show();
        } else {
            root.hide();
        }
    }

    Connections {
        target: Tablet

        function onFoldedChanged(): void {
            root.follow();
        }
    }

    // AND ONCE ON THE WAY UP, because a signal only fires on a CHANGE and the
    // shell booting on an already-folded machine is not one.
    //
    // The usual order is that this panel is built first and the hinge is read a
    // moment later, so the Connections above catches it and this call finds
    // nothing to do. The order is not guaranteed, though: services/Tablet.qml
    // probes on its own Component.onCompleted, a singleton is created the first
    // instant anything reads it, and if that happened to be something built
    // before this panel then the one transition there was is already spent by
    // the time the panel exists. Asking outright costs one call and does not
    // depend on which of the two won.
    //
    // It is also what makes a RELOAD behave: Quickshell rebuilds this tree
    // whenever a file changes, and a board that only listened for transitions
    // would come back closed on a machine that is still folded.
    Component.onCompleted: root.follow()

    // WHAT A CAP SAYS, which depends on the modifier state and so cannot live in
    // the data. An `icon` key says nothing in words; a `cap` says the same thing
    // whatever is armed (esc, ctrl, F5); everything else is the character it is
    // about to type, which is the honest label because it is literally what will
    // arrive.
    function capOf(key: var): string {
        if (key.icon)
            return "";
        if (key.cap)
            return key.cap;
        if (root.latched.includes("shift"))
            return key.up ?? key.lo ?? "";
        return key.lo ?? "";
    }

    // HOW MUCH ROOM THE BOARD ASKS FOR when it is docked. Read from outside the
    // window tree by modules/FrameExclusions.qml, which is the surface that can
    // actually reserve it; see the note there and on Tablet.docked.
    readonly property int reserveHeight: Math.round(root.panelHeight)

    // WHICH KEYS SHOW AS "ON". Modifiers, while they are armed, and the dock key
    // for as long as the board is taking up room: they are the same question
    // asked of a state that persists past the tap, which is exactly what the
    // accent fill is for.
    function armed(key: var): bool {
        if (key.mod)
            return root.latched.includes(key.mod);
        if (key.act === "dock")
            return Tablet.docked;
        return false;
    }

    // THE THREE WEIGHTS A CAP CAN HAVE, derived from what the key IS rather than
    // listed per key, so adding a letter cannot forget to say it is one.
    //
    //   letter    the ones you are actually typing. The lighter fill and the
    //             larger of the two type tiers: on a real board these are the
    //             keys your eye goes to, and a board where the letters and the
    //             function keys weigh the same is a wall of identical tiles.
    //   function  everything that is not a character. Subtler fill, smaller
    //             type, so the alphabet reads first and tab/ctrl/esc recede.
    //   accent    Return, and only Return. It is the one key on a touch keyboard
    //             that means "done", and every phone keyboard colours it for
    //             that reason: it is the one you aim at without looking.
    //
    // Space is a `function` despite being printable, because it is a bar rather
    // than a letter and lighting it up would put the board's brightest object in
    // the middle of the bottom row.
    function toneOf(key: var): string {
        if (key.tone)
            return key.tone;
        if (key.lo !== undefined && key.lo !== " ")
            return "letter";
        return "function";
    }

    function toggleMod(mod: string): void {
        if (root.latched.includes(mod))
            root.latched = root.latched.filter(m => m !== mod);
        else
            root.latched = [...root.latched, mod];
    }

    // ONE DOOR FOR EVERY KEY, so a modifier, a layer switch and a letter cannot
    // drift into three different ideas of what a press means.
    function fire(key: var): void {
        if (key.mod) {
            root.toggleMod(key.mod);
            return;
        }

        if (key.act === "hide") {
            root.hide();
            return;
        }

        // DOES THE BOARD TAKE UP ROOM. Toggled on the service rather than here,
        // because the surface that reserves the space is FrameExclusions and it
        // cannot see this panel; see Tablet.docked.
        if (key.act === "dock") {
            Tablet.setDocked(!Tablet.docked);
            return;
        }

        if (key.act === "page") {
            root.page = key.to;
            return;
        }

        const mods = root.latched;

        if (key.sym) {
            Keystrokes.press(key.sym, mods);
        } else {
            const chord = mods.filter(m => m !== "shift");
            if (chord.length) {
                // A CHORD SENDS THE BASE CHARACTER, not the shifted one. Ctrl+C
                // is ctrl held over the `c` key; sending "C" would ask for
                // Ctrl+Shift+C, which in a terminal is a different command
                // entirely and in an editor is usually nothing.
                Keystrokes.type(key.lo, mods);
            } else {
                // No modifier to apply, so the character the cap is showing goes
                // as itself. This is the layout-independent path the whole board
                // is built on: see services/Keystrokes.type.
                Keystrokes.type(root.latched.includes("shift") ? (key.up ?? key.lo) : key.lo, []);
            }
        }

        // SPENT. One-shot, per the header. Cleared after the key rather than
        // before it, because the key needed to know what was armed.
        if (root.latched.length)
            root.latched = [];
    }

    Follow {
        id: reveal

        speed: Appearance.anim.revealSpeed
        target: root.shown ? 1 : 0
        epsilon: 0.005
    }

    Item {
        id: panel

        x: root.originX
        y: root.height - root.panelHeight + root.slide
        width: root.panelWidth
        height: root.panelHeight
        visible: reveal.value > 0.001
        enabled: root.open

        Item {
            id: board

            x: Appearance.padding.large
            y: Appearance.padding.large
            width: root.boardWidth
            height: root.boardHeight

            Repeater {
                model: root.rows

                Item {
                    id: line

                    required property int index
                    required property var modelData

                    y: line.index * root.rowPitch
                    width: board.width
                    height: root.rowPitch

                    Repeater {
                        model: line.modelData

                        TabletKey {
                            required property var modelData

                            // The running total, times the pitch. The only
                            // arithmetic a key's position ever needs.
                            x: modelData.at * root.pitch

                            units: modelData.units
                            pitch: root.pitch
                            rowPitch: root.rowPitch
                            seam: root.seam

                            label: root.capOf(modelData.key)
                            icon: modelData.key.icon ?? ""
                            tone: root.toneOf(modelData.key)
                            latched: root.armed(modelData.key)
                            repeats: modelData.key.repeats ?? false

                            onFired: root.fire(modelData.key)
                        }
                    }
                }
            }
        }
    }
}
