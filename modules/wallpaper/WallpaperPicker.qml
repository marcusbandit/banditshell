pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// THE WALLPAPER PICKER, and the second thing the bottom edge does.
//
// Swipe up and the launcher comes out of the bottom of the screen. Swipe up
// AGAIN, from the same edge, and the launcher goes and this takes its place:
// one gesture, repeated, walking through the two things that live down there.
// It is also `banditshell wallpapers open [screen]`, which reaches this same
// surface from a terminal.
//
// NO BACKGROUND. There is no panel here and there is deliberately nothing
// standing in for one: no surface, no plate, no fade at the edges. The picker
// is only the wallpapers themselves, floating on the desktop they are about to
// join, and what shows behind them is the real desktop wearing the live
// preview. A rectangle behind a picture of a rectangle would be the one thing
// on screen arguing with the thing being chosen.
//
// THE HERO IS THE CHOICE. The centred card is drawn at HALF THE MONITOR'S
// HEIGHT and at the screen's own aspect, centred on the screen this picker
// opened on. Big enough that what you are looking at is the crop you will get:
// PreserveAspectCrop into this rectangle and PreserveAspectCrop into the
// screen are the same operation at two sizes, so nothing has to be said about
// rotation anywhere. See Wallpaper.fits.
//
// EVERYTHING ELSE IS A STACK. The remaining wallpapers fan out to the right of
// the hero, one pitch apiece, each card showing only the sliver of itself that
// clears the one in front of it, the stack running off the right edge of the
// screen and carrying on off it for as many wallpapers as there are. The ones
// already passed mirror the same stack out the left, because the strip is a
// ring and a ring has two directions. Scrubbing walks cards out of the stack,
// through the middle, and into the stack on the other side.
//
// BUILT FOR A FINGER, and that is what makes it a different shape from
// everything else in this shell: no search field, because you do not know
// what your wallpaper is called; a row of big pictures you throw sideways,
// not a grid of small targets.
//
// THE CENTRE CARD IS ON THE ACTUAL DESKTOP. Scrubbing through the list puts
// each one up as it passes, full size, behind everything. Nothing is written
// until the picker closes, so a scrub that ends in a dismissal leaves the
// setting exactly where it was.
Item {
    id: root

    // WHICH MONITOR THIS PICKER IS FOR, by output name.
    //
    // There is one of these per screen and the picker writes a wallpaper for
    // THIS screen: the preview it puts on the desktop, the ring on the card
    // that screen is wearing, and the point the reveal opens from all follow
    // from here.
    required property string screen

    readonly property bool open: shown
    property bool shown: false

    // THE WALLPAPERS THAT SUIT THIS SCREEN, which is not the same list on the
    // monitor next to it.
    //
    // A collection big enough to be worth browsing holds pictures for every
    // screen its owner has ever had, and on any one screen most of them are
    // wrong. Measured per file and compared against this screen's own shape.
    // See Wallpaper.fits.
    readonly property var fitted: Wallpaper.fittedFor(root.screenAspect)

    // AND THE WAY OUT, in one press: `all` is the second half of the same
    // control rather than a setting, and like the scope pill beside it, it
    // resets when the picker closes.
    property bool showAll: false

    // NOTHING FITS is not the same state as "you asked for everything", so an
    // empty prediction shows the whole folder, and `predicted` is what the
    // caption uses to say which of the two happened.
    readonly property bool predicted: !root.showAll && root.fitted.length > 0

    readonly property var entries: root.predicted ? root.fitted : Wallpaper.available

    // THE SHAPE OF THIS SCREEN, and that is the whole of what a card's aspect
    // should ever have been. A monitor stood on its end reports the other pair
    // of numbers and every one of these expressions follows without a branch.
    readonly property real screenAspect: root.height > 0 ? root.width / root.height : 16 / 9

    // THE HERO CARD: HALF THE MONITOR'S HEIGHT, at the screen's own aspect.
    //
    // Sized from the screen it stands on and nothing else, so it is the same
    // share of whatever it is opened on: half of a phone's height in a hand,
    // half of a 32:9 panorama across a desk. The width follows from the
    // aspect, which makes the hero exactly half the screen wide on every
    // output - a number nobody chose, it simply falls out of "the card is the
    // screen's shape, at half the height".
    readonly property real heroHeight: Math.round(root.height * 0.5)
    readonly property real heroWidth: Math.round(root.heroHeight * root.screenAspect)

    // ONE CARD OF TRAVEL. The distance between two neighbouring places in the
    // stack, and the unit every moving thing in here is measured in: the scrub,
    // the wheel, the flick. A single number, so they cannot disagree.
    //
    // A FRACTION OF THE HERO, not of the screen: the stack is a deck of cards
    // behind the hero, and how far one card's edge peeks past the one before
    // it is a fact about the cards.
    readonly property real pitch: Math.round(root.heroWidth * 0.16)

    // HOW BIG THE HERO IS AGAINST ITS NEIGHBOURS. The centre is one - the card
    // in the middle is exactly the half-monitor rectangle the numbers above
    // describe - and the stack falls away from it: one pitch out it is already
    // visibly behind, and by the ends of the path it is a shadow of the hero
    // disappearing off the edge of the screen.
    readonly property real nearScale: 0.92
    readonly property real farScale: 0.62

    // HOW FAR THE PATH HAS TO RUN: across the screen, plus enough past each
    // edge that a card sitting at either end of the path is ENTIRELY
    // off-screen - half a far card, plus one pitch of slack. A card that wraps
    // round the ring must not be seen doing it: it slides out of sight and
    // only then becomes the other end of the stack.
    readonly property real span: root.width + root.heroWidth * root.farScale + root.pitch

    // HOW MANY CARDS THE PATH HOLDS: the span at one card per pitch, floored
    // at three (there has to be a centre to be either side of) and capped at
    // the folder minus one, which is the condition `place()` below is derived
    // under: PathView has TWO position formulas and picks between them on the
    // strict comparison `pathItemCount < modelCount`. Let `slots` reach the
    // model count and the strip goes wrong in the one way that is hardest to
    // disbelieve: the caption names the wallpaper you chose, the desktop shows
    // the wallpaper you chose, and the hero wearing the ring is somebody
    // else's.
    readonly property int slots: Math.max(1, Math.min(root.entries.length - 1, Math.max(3, Math.round(root.span / root.pitch))))

    // HOW MUCH OF THE BOTTOM EDGE THE PICKER OCCUPIES, which is all the launch
    // edge (modules/ShellWindow.qml) wants of it: the picker is borderless and
    // spans the screen, so the edge it rises from spans the screen too.
    readonly property real panelWidth: root.width

    // HOW FAR THE BODY TRAVELS TO GET OUT OF THE SCREEN: far enough that its
    // lowest point - the caption under the hero - is below the bottom edge
    // when the picker is closed, so the rise brings the whole thing up out of
    // the edge the way the launcher comes out of it.
    readonly property real riseDistance: root.height / 2 + root.heroHeight / 2 + Appearance.padding.large + caption.implicitHeight

    // The whole screen while it is open, so a tap anywhere outside lands on the
    // shell and can dismiss it.
    readonly property Item maskItem: catcher

    // NO SURFACE, NO SILHOUETTE. Blobs are the shapes the shell rounds the
    // desktop's blur behind; with no panel there is nothing to round.
    readonly property var blobs: []

    function show(): void {
        if (root.shown)
            return;
        root.shown = true;

        // ASK THE FOLDER WHAT IS IN IT, rather than answering from the listing
        // taken when the shell started. A human drops a picture in and is
        // usually about to open this picker to go and look at it; one `find`
        // per opening is by definition never stale at the moment it matters.
        Wallpaper.refresh();

        root.settle();
        // DEFERRED, the launcher's reason: focus is only worth taking once the
        // window has actually asked the compositor for the keyboard, and that
        // follows from `shown` in the same pass this is running in.
        Qt.callLater(root.forceActiveFocus);
    }

    // START WHERE YOU ALREADY ARE, and the filter is not allowed to break
    // that promise: the wallpaper you are wearing is a member of the list by
    // definition, and if the prediction disagrees, the prediction gives way
    // for this opening.
    //
    // ITS OWN FUNCTION, BECAUSE THE LIST ARRIVES AFTER THE PICKER DOES. The
    // refresh above is a process, so `available` changes a beat later while
    // the strip is already centred, and every index moves when a picture that
    // sorts earlier joins the list. The same settling runs again whenever the
    // list changes under an open picker, which is also what makes a wallpaper
    // added while the picker is open simply show up in it.
    function settle(): void {
        const worn = Wallpaper.currentOn(root.screen);
        root.showAll = worn !== "" && root.fitted.indexOf(worn) < 0;

        strip.jumpTo(Math.max(0, root.entries.indexOf(worn)));
        root.settled = strip.goal;
    }

    // WHERE settle() LEFT THE STRIP, so the difference between "nobody has
    // touched this yet" and "a hand is using it" is a fact rather than a guess.
    property real settled: -1

    // RE-CENTRE ONLY ON A STRIP NOBODY HAS MOVED. The list can change under an
    // open picker (the listing landing, the shapes behind the fit filter
    // landing) and renumber `entries`; but by then the hand may be scrubbing,
    // and yanking the strip home mid-drag would be the shell overruling the
    // gesture in progress. Untouched, it re-centres; touched, it is none of
    // its business.
    function resettle(): void {
        if (root.shown && strip.goal === root.settled)
            root.settle();
    }

    Connections {
        target: Wallpaper

        // The folder was re-listed, so a picture may have joined or left.
        function onAvailableChanged(): void {
            root.resettle();
        }

        // The shapes landed, so the fit filter may have changed its mind about
        // which of them belong on this screen. Measured by an ffprobe per file
        // and therefore always later than the listing that asked for it.
        function onShapesChanged(): void {
            root.resettle();
        }
    }

    // WHAT YOU ARE LOOKING AT IS WHAT YOU GET. Closing the picker KEEPS the
    // wallpaper the strip is centred on, rather than putting the old one back:
    // the picture has already been on your desktop, full size, behind this
    // picker, since the moment the card reached the middle. There is no
    // separate act of choosing and no way to be shown one wallpaper while
    // owning another. A tap still exists and still means something - it is
    // faster, and it gives the reveal a point to open from - but it is a
    // shortcut for leaving rather than the only way to decide.
    //
    // AND NO CANCEL, deliberately, including Escape. Scrubbing back is the
    // undo, and it is the same gesture that got you here.
    function hide(): void {
        if (!root.shown)
            return;
        root.commit();
        root.shown = false;
        root.chosenAt = null;
        // THE SCOPE GOES BACK TO "HERE": a property of one choice, not a mode
        // the picker is left in. The filter comes back for the same reason;
        // show() turns it off again by itself when the wallpaper you are
        // wearing needs it off.
        root.everywhere = false;
        root.showAll = false;
    }

    // KEEP WHAT IS CENTRED, wherever the picker is being closed from.
    //
    // Nothing to keep when the folder is empty, and nothing to write when the
    // screen already wears it. A strip still sitting on the number settle()
    // left it at has not been scrubbed, and this close is a dismissal rather
    // than a choice: dismissals put the wallpaper back and write nothing.
    function commit(): void {
        if (strip.goal === root.settled) {
            Wallpaper.clearPreview(root.screen);
            return;
        }

        const path = strip.currentPath;
        const all = root.everywhere && root.manyScreens;
        if (!path || (!all && path === Wallpaper.currentOn(root.screen))) {
            Wallpaper.clearPreview(root.screen);
            return;
        }

        // The point the reveal opens from, if the choice had one. A dismissal
        // does not, and it makes no visible difference either way, since the
        // wallpaper being kept is already the one on the screen.
        const at = root.chosenAt;
        const x = at ? at.x / Math.max(1, root.width) : 0.5;
        const y = at ? at.y / Math.max(1, root.height) : 0.5;

        if (all)
            Wallpaper.setFromAll(path, x, y);
        else
            Wallpaper.setFrom(root.screen, path, x, y);
    }

    function toggle(): void {
        if (root.shown)
            root.hide();
        else
            root.show();
    }

    // DONE, and WHERE IT WAS DONE FROM, because a new wallpaper opens out of a
    // point rather than fading in (components/reveal.frag). Missing, and it
    // opens from the middle: Enter has no place on the screen.
    function accept(from: var): void {
        root.acceptAt(from);
    }

    // WHICH SCREENS A TAP IS ABOUT, and the default is the one you are tapping
    // on. NOT REMEMBERED between openings: a scope is a property of the choice
    // you are making now, not a mode the picker is left in.
    property bool everywhere: false

    // Only worth showing when there is more than one screen to distinguish.
    readonly property bool manyScreens: Quickshell.screens.length > 1

    // WHERE THE CHOICE WAS MADE, in this item's coordinates. Null for a
    // dismissal, which has no place on the screen to have come from.
    property var chosenAt: null

    // `at` is a point in this item's coordinates. A tap is a shortcut for
    // leaving rather than the only way to decide, so all it adds over closing
    // the picker is the point the reveal opens out of.
    function acceptAt(at: var): void {
        root.chosenAt = at;
        root.hide();
    }

    // WHAT A CARD SAYS ABOUT ITSELF, as a MARK, or "" for the ordinary case.
    //
    // A still picture is what a wallpaper is expected to be and gets no badge.
    // The three that move get one, and so does the fourth thing: an SVG that
    // declares an animation and is drawn as a still anyway, because Qt
    // rasterises an SVG once. `motion_photos_off` is the SAME family as the
    // mark for a thing that moves, negated, which is exactly what that file
    // is. See Wallpaper.frozen.
    function badgeFor(path: string): string {
        const k = Wallpaper.kindOf(path);
        if (k === "motion")
            return "gif";
        if (k === "video")
            return "movie";
        if (k === "audio")
            return "music_note";
        return Wallpaper.isFrozen(path) ? "motion_photos_off" : "";
    }

    // THE KEYBOARD, on a surface built for a finger, and it is not a
    // contradiction: this picker takes the compositor's keyboard while it is
    // up, so the arrow keys are already being delivered here. A row of things
    // with one of them centred is a list, whatever it is drawn as.
    //
    // Escape is deliberately NOT here. ShellWindow owns that key for every
    // panel at once, in one ordered list. Wrapping like everything else that
    // moves the strip: the arrows walk off one end and back in the other,
    // because the strip does.
    Keys.onLeftPressed: strip.step(-1)
    Keys.onRightPressed: strip.step(1)
    // No `from`: Enter has no place on the screen, so the reveal opens from
    // the middle. See accept().
    Keys.onReturnPressed: root.accept(null)
    Keys.onEnterPressed: root.accept(null)

    // Pulled by hand, exactly the launcher's pair of calls and for exactly its
    // reasons: while `dragging` is true the reveal is the HAND'S rather than
    // the animation's, so the bottom edge is where the finger is.
    property bool dragging: false
    property real dragProgress: 0

    readonly property real revealed: root.dragging ? root.dragProgress : rise.value

    function dragTo(fraction: real): void {
        root.dragging = true;
        root.dragProgress = Math.max(0, Math.min(fraction, 1));
    }

    function dragEnd(open: bool): void {
        root.dragging = false;
        rise.value = root.dragProgress;
        if (open)
            root.show();
        else
            root.hide();
        root.dragProgress = 0;
    }

    Follow {
        id: rise

        target: root.shown ? 1 : 0
        speed: Appearance.anim.revealSpeed
        epsilon: 0.005
    }

    // DECLARED FIRST so it sits UNDER the body: a catch-all that comes last
    // swallows every tap meant for the thing it is supposed to be behind. The
    // swipe area above it answers taps on the wallpapers and on the empty
    // glass alike; this one is for the frames in between, and for the input
    // mask ShellWindow installs while the picker is up.
    MouseArea {
        id: catcher

        anchors.fill: parent
        enabled: root.open
        visible: root.open
        onClicked: root.hide()
    }

    // THE BODY: the hero, the stack and the caption, rising out of the bottom
    // edge as one thing. The offset is the reveal, nothing else - there is no
    // surface here to clip or to round, only where the wallpapers are.
    Item {
        id: body

        width: root.width
        height: root.height
        y: (1 - root.revealed) * root.riseDistance
        visible: root.revealed > 0.001

        // THE STRIP.
        //
        // A PathView, and every one of the three things that make this carousel
        // feel like one comes out of that choice rather than out of anything
        // written here.
        //
        //   IT NEVER ENDS. A PathView's items run round the path, so the last
        //   wallpaper is followed by the first and you can keep throwing the
        //   strip in one direction forever. A list has two ends, and an end is
        //   a wall you hit while your hand is still moving.
        //
        //   THE MIDDLE IS THE HERO, continuously. The scale comes off
        //   PathAttributes interpolated ALONG the path, so a card grows as it
        //   approaches the centre and sinks back into the stack as it leaves,
        //   every frame of the way.
        //
        //   IT HAS MOMENTUM. A flick coasts across as many cards as it was
        //   thrown hard enough to reach and then snaps to whichever one it
        //   arrives at.
        //
        // SIZED TO THE SCREEN, not to a panel, because there is no panel: the
        // path's coordinates are the screen's, the hero centres on the screen,
        // and the stack runs to the screen's edges and past them. Cards
        // positioning themselves outside this item are NOT clipped - there is
        // no clip anywhere in here - they are simply off the monitor, which is
        // where the stack lives.
        PathView {
            id: strip

            readonly property string currentPath: root.entries[strip.centre] ?? ""

            // How much of the running stream has already been paid out in
            // cards, in pixels of finger travel. It is what makes the scrub
            // below RELATIVE to wherever the strip has got to rather than
            // absolute from the card the fingers began on. Counted in whole
            // pitches, the two motions ADD UP to the travel and nothing is
            // lost to rounding.
            property real scrubSpent: 0

            // WHERE THE STRIP IS, in cards, as a real number that is allowed to
            // run past either end: the wrap happens where it is applied, not
            // where it is stored.
            //
            // ONE OWNER. PathView has its own physics and they are turned off
            // (`interactive: false`): a view that both moves itself and is
            // moved is a view with two answers about where it is. Every input
            // in this file sets `goal`; the finger writes `glide` directly
            // while it is down; nothing else touches either.
            property real goal: 0

            // EXPONENTIAL SMOOTHING, which is what this shell uses for anything
            // that chases a target: fast while it is far from the card it is
            // going to, gentle as it lands, and no fixed duration to be wrong
            // at either end of the distance.
            Follow {
                id: glide

                target: strip.goal
                speed: Appearance.anim.scrollSpeed
                // In CARDS, so the default quarter-pixel epsilon would be a
                // quarter of a card and stop it visibly short.
                epsilon: 0.002
            }

            // The wrap, for an int and for a real. The double modulo is
            // JavaScript's: -1 % 18 is -1, not 17.
            function wrapped(i: int): int {
                const n = root.entries.length;
                return n ? ((i % n) + n) % n : 0;
            }

            function wrapReal(x: real): real {
                const n = root.entries.length;
                return n ? ((x % n) + n) % n : 0;
            }

            // How many cards from the middle to `i`, by whichever way round is
            // shorter. On a ring the two answers differ by the whole count and
            // only one of them is what a tap meant.
            function shortest(i: int): int {
                const n = root.entries.length;
                if (!n)
                    return 0;
                let d = strip.wrapped(i - strip.centre);
                return d > n / 2 ? d - n : d;
            }

            function step(delta: int): void {
                // From the GOAL and not from where the strip currently is, so
                // steps asked for faster than the glide can land them add up
                // instead of fighting.
                strip.goal = Math.round(strip.goal) + delta;
            }

            // Put a card in the middle WITHOUT travelling to it. Opening the
            // picker on the wallpaper you are wearing must not look like the
            // strip scrolling there from wherever it was left.
            function jumpTo(i: int): void {
                strip.goal = strip.wrapped(i);
                glide.value = strip.goal;
            }

            // WHERE THE CARDS ACTUALLY SIT, and the one line that has to agree
            // with Qt rather than with this file.
            //
            // PathView spaces items by the PATH's capacity and not by the
            // model's. Its own arithmetic, with no highlight range so no
            // hidden term:
            //
            //     pos = fmod((i + offset) / count, 1) * count / pathItemCount
            //
            // and an item is on the path while `pos` is under one. Setting
            // that to a half and solving for the offset that centres card `p`:
            //
            //     (p + offset) mod count = pathItemCount / 2
            //     offset = pathItemCount / 2 - p
            //
            // ASSIGNED, NOT BOUND, and that is not a style choice: PathView
            // writes `offset` itself in several places, and a C++ write to a
            // property BREAKS the QML binding on it permanently. An assignment
            // cannot be broken, because the next tick of the smoother makes it
            // again.
            function place(): void {
                strip.offset = strip.wrapReal(root.slots / 2 - glide.value);
            }

            Connections {
                target: glide

                function onValueChanged(): void {
                    strip.place();
                }
            }

            // The path's capacity is a term in `place()`, so a screen or a
            // folder that changes it has to re-place.
            Connections {
                target: root

                function onSlotsChanged(): void {
                    strip.place();
                }
            }

            Component.onCompleted: strip.place()

            // WHICH CARD IS IN THE MIDDLE, and deliberately NOT `currentIndex`:
            // setting a PathView's currentIndex asks it to move the offset on
            // its own clock, and the offset is this file's. `centre` is the
            // same question asked of the position we already own.
            readonly property int centre: strip.wrapped(Math.round(glide.value))

            anchors.fill: parent

            model: root.entries
            pathItemCount: root.slots

            // NO HIGHLIGHT RANGE, NO SNAP, NOT INTERACTIVE: three lines that
            // between them turn every one of PathView's own physics off.
            // Together they mean it computes a card's place from `offset` and
            // nothing else, adds no term of its own, and never moves itself.
            highlightRangeMode: PathView.NoHighlightRange
            snapMode: PathView.NoSnap
            interactive: false

            // TWO FINGERS ARE A SWIPE (components/ScrollGesture.qml): how far
            // the fingers have travelled, divided by what one card occupies.
            // Reversible for the whole gesture, because that division is
            // against the stream's TOTAL rather than against a count of the
            // events it happened to arrive in. A vertical stream therefore
            // moves nothing, which is the right answer twice over: a
            // horizontal strip has no second axis to spend one on, and it is
            // what a finger dragging up the strip already gets.
            function scrub(dx: real): void {
                // Fingers to the LEFT push the strip left, which brings the
                // next card in from the right, so the index rises as `dx`
                // falls. Rounded, so the card turns over at the halfway mark
                // exactly as the view's own snap does.
                const steps = Math.round((-dx - strip.scrubSpent) / root.pitch);
                if (steps === 0)
                    return;

                // NOTHING IS CLAMPED, and there are no ends: every step the
                // fingers pay for is a step the strip takes, so the spend is
                // simply the travel and the two can never drift.
                strip.scrubSpent += steps * root.pitch;
                strip.step(steps);
            }

            // WHAT THE FINGERS WERE STILL DOING WHEN THEY LEFT: the speed the
            // gesture ended at, spent over the time a flick is allowed to keep
            // going, divided by what one card occupies.
            function coast(vx: real): void {
                const cards = Math.round(-vx * Appearance.sizes.coastMs / root.pitch);
                if (cards)
                    strip.step(cards);
            }

            // A WHEEL HAS MOMENTUM, and it is the only device here that has to
            // be given it rather than having it. A wheel says one word,
            // "forward", however hard it is spun, so the STEP grows with the
            // rate: notches arriving faster than a deliberate one-at-a-time
            // click are read as a spin and each is worth more, up to a cap,
            // and the count decays back to one as soon as the hand stops.
            property real lastNotch: 0
            property int notchStep: 1

            function spin(): int {
                const now = Date.now();
                const gap = now - strip.lastNotch;
                strip.lastNotch = now;
                // Under a tenth of a second apart is a spin rather than a
                // click. Every notch inside that window is worth one more card
                // than the last, to a cap: past about five the strip is moving
                // faster than the pictures can be looked at.
                strip.notchStep = gap < 120 ? Math.min(5, strip.notchStep + 1) : 1;
                return strip.notchStep;
            }

            // EVERY CARD, BUILT ON THE WAY UP. `cacheItemCount` is the number
            // kept alive off the path, so a folder that fits under the cap is
            // instantiated whole and every picture is decoding from the moment
            // the picker opens rather than from the moment a card scrolls into
            // view. CAPPED, because this is memory: each card holds a decoded
            // thumbnail for as long as it lives.
            cacheItemCount: Math.max(0, Math.min(root.entries.length, 40) - root.slots)

            // THE PATH: a straight line through the middle of the screen, as
            // long as the span needs to be to carry every card fully off
            // screen before it wraps. The attributes along it are what every
            // card reads as it passes, and the interpolation between them is
            // the whole animation: the hero stands at one, its neighbours are
            // already visibly behind it one pitch out, and the ends of the
            // path - which are past the edges of the screen - are where cards
            // leave and arrive unseen.
            path: Path {
                id: line

                readonly property real span: root.slots * root.pitch
                readonly property real cy: strip.height / 2
                readonly property real cx: strip.width / 2

                startX: line.cx - line.span / 2
                startY: line.cy

                PathAttribute {
                    name: "cardScale"
                    value: root.farScale
                }
                PathAttribute {
                    name: "cardZ"
                    value: 0
                }

                PathLine {
                    x: line.cx - root.pitch
                    y: line.cy
                }
                PathAttribute {
                    name: "cardScale"
                    value: root.nearScale
                }
                PathAttribute {
                    name: "cardZ"
                    value: 1
                }

                PathLine {
                    x: line.cx
                    y: line.cy
                }
                PathAttribute {
                    name: "cardScale"
                    value: 1
                }
                PathAttribute {
                    name: "cardZ"
                    value: 2
                }

                PathLine {
                    x: line.cx + root.pitch
                    y: line.cy
                }
                PathAttribute {
                    name: "cardScale"
                    value: root.nearScale
                }
                PathAttribute {
                    name: "cardZ"
                    value: 1
                }

                PathLine {
                    x: line.cx + line.span / 2
                    y: line.cy
                }
                PathAttribute {
                    name: "cardScale"
                    value: root.farScale
                }
                PathAttribute {
                    name: "cardZ"
                    value: 0
                }
            }

            // LIVE, and this is the point of the whole picker: the card in the
            // middle is on the desktop behind you at full size while you decide
            // about it.
            //
            // BUT NOT ON EVERY CARD THAT PAST. The middle is somewhere cards
            // travel THROUGH, so the preview waits for the strip to STOP: long
            // enough that cards flying past the middle cost nothing at all,
            // short enough that arriving at one does not feel like a request
            // that has to be waited on.
            onCurrentPathChanged: settle.restart()

            Timer {
                id: settle

                interval: 90

                onTriggered: {
                    if (root.open && strip.currentPath)
                        Wallpaper.setPreview(root.screen, strip.currentPath);
                }
            }

            delegate: Item {
                id: card

                required property string modelData
                required property int index

                readonly property bool centred: card.index === strip.centre

                width: root.heroWidth
                height: root.heroHeight

                // OFF THE PATH, NOT OUT OF A CONDITION.
                //
                // These come from the PathAttributes the path is strung with,
                // interpolated at wherever this card currently sits on it,
                // which means they are continuous: a card grows every frame of
                // its approach and sinks every frame of its departure.
                // Defaulted with `?? `, because a delegate exists for a moment
                // before the view has placed it on the path.
                scale: card.PathView.cardScale ?? root.farScale
                z: card.PathView.cardZ ?? 0

                // WHAT A CARD IS BEFORE ITS PICTURE ARRIVES, and what it stays
                // for a file that has no picture at all. A plate and nothing
                // on it: a strip mid-decode is a strip of cards rather than a
                // row of holes.
                G2Rect {
                    anchors.fill: parent
                    radius: Appearance.rounding.normal
                    color: Appearance.colour.fill
                }

                G2Image {
                    anchors.fill: parent
                    radius: Appearance.rounding.normal
                    source: Wallpaper.faceOf(card.modelData)
                    fillMode: Image.PreserveAspectCrop
                }

                // THAT THIS ONE MOVES, on the card rather than only in the
                // caption: every card is a still, including the cards that
                // are not.
                Button {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: Appearance.padding.small

                    visible: !!root.badgeFor(card.modelData)
                    interactive: false
                    paint: Wallpaper.isFrozen(card.modelData) ? Appearance.colour.fillStrong : Appearance.colour.accentFill
                    icon: root.badgeFor(card.modelData)
                    iconFill: Wallpaper.isFrozen(card.modelData) ? 0 : 1
                }

                // THE MARK ON THE ONE YOU ARE ALREADY WEARING. Not a selection
                // highlight: the hero is what the middle of the strip already
                // says. This is the different fact that one of these is the
                // wallpaper you have.
                G2Rect {
                    anchors.fill: parent
                    radius: Appearance.rounding.normal
                    color: "transparent"
                    stroke: Appearance.colour.accent
                    strokeWidth: Appearance.font.stem * 2
                    visible: card.modelData === Wallpaper.currentOn(root.screen)
                }

            }
        }

        // THE HAND, and the whole of what drives the strip.
        //
        // It fills the SCREEN rather than the hero, because the picker has no
        // panel to catch what falls off the cards: the glass IS the surface
        // now, and everywhere the finger lands is either a card or the glass.
        // A tap on a card centres it (or accepts it, if it is the hero); a tap
        // on the glass puts the picker away, which is what the old panel's
        // dismiss catcher did and what the catcher underneath still does for
        // any event this does not take.
        //
        // A MouseArea AND NOT A DragHandler, and it is a correctness question
        // rather than a taste one: Qt delivers a touch as a touch and
        // synthesises a mouse press from it for items that only speak mouse,
        // and synthesis is the path that is actually exercised by every other
        // gesture in this shell. This joins them.
        MouseArea {
            id: swipe

            anchors.fill: parent
            enabled: root.open
            cursorShape: Qt.PointingHandCursor

            // Where the strip was and where the finger was when it landed,
            // so the drag is measured from its origin rather than accumulated
            // frame by frame: accumulation loses a little every time a pointer
            // event is coalesced.
            property real from: 0
            property real fromX: 0
            property bool dragging: false

            // Smoothed pixels per millisecond, for the throw. The last event
            // before a lift is noise as often as it is direction, which is why
            // this is an average and not the final step.
            property real velocity: 0
            property real lastX: 0
            property real lastAt: 0

            onPressed: mouse => {
                swipe.from = glide.value;
                swipe.fromX = mouse.x;
                swipe.lastX = mouse.x;
                swipe.lastAt = Date.now();
                swipe.velocity = 0;
                swipe.dragging = false;
            }

            onPositionChanged: mouse => {
                if (!swipe.pressed)
                    return;

                const now = Date.now();
                const dt = Math.max(1, now - swipe.lastAt);
                swipe.velocity += ((mouse.x - swipe.lastX) / dt - swipe.velocity) * 0.4;
                swipe.lastX = mouse.x;
                swipe.lastAt = now;

                if (!swipe.dragging && Math.abs(mouse.x - swipe.fromX) < Appearance.sizes.dragThreshold)
                    return;
                swipe.dragging = true;

                // THE STRIP UNDER THE HAND, one to one and not smoothed: while
                // a finger is down the position IS the finger. `glide.value`
                // is written directly rather than through `goal`, so the
                // smoother picks up from exactly where the drag left it.
                glide.value = swipe.from - (mouse.x - swipe.fromX) / root.pitch;
                strip.goal = glide.value;
            }

            onReleased: mouse => {
                if (!swipe.dragging) {
                    // A PRESS THAT NEVER TRAVELLED is a tap, and which card it
                    // was is the view's question rather than this one's. The
                    // middle one is a choice; any other centres itself first,
                    // by the short way round, because the strip is a ring; the
                    // glass between the cards is a dismissal.
                    const i = strip.indexAt(mouse.x, mouse.y);
                    if (i < 0) {
                        root.hide();
                        return;
                    }
                    if (i === strip.centre)
                        // FROM WHERE THE FINGER WAS, not from the card's
                        // centre: the picture grows out of your fingertip.
                        root.acceptAt(swipe.mapToItem(root, mouse.x, mouse.y));
                    else
                        strip.step(strip.shortest(i));
                    return;
                }

                // LET GO. The strip takes whatever the hand was still doing as
                // a throw, and then ROUNDS, so wherever the throw lands it
                // lands on a card rather than between two. `velocity` is
                // pixels per millisecond and `coastMs` is the shell's token
                // for how many milliseconds of it a flick is worth. Negated
                // because a hand going left brings later cards in from the
                // right.
                const thrown = -swipe.velocity * Appearance.sizes.coastMs / root.pitch;
                strip.goal = Math.round(glide.value + thrown);
                swipe.dragging = false;
            }

            onCanceled: {
                if (swipe.dragging)
                    strip.goal = Math.round(glide.value);
                swipe.dragging = false;
            }

            // A NOTCH IS A REQUEST, not a distance: it moves one card rather
            // than a number of pixels. A touchpad reports deltas alongside its
            // notches and would otherwise be read as a hundred notches a
            // second, so a stream scrubs instead - how far the fingers have
            // travelled, divided by what one card occupies - and a wheel,
            // which has one axis and one word, steps.
            WheelHandler {
                onWheel: event => {
                    // feed() takes a touchpad and refuses a wheel, and it is
                    // asked FIRST because a touchpad reports both deltas.
                    if (scroll.feed(event))
                        return;

                    event.accepted = true;

                    const back = event.angleDelta.y > 0 || event.angleDelta.x < 0;
                    strip.step(back ? -strip.spin() : strip.spin());
                }
            }
        }

        // THE TWO FINGERS OF A TOUCHPAD, as one gesture: a stream is a press,
        // a total is a delta, and the lapse that ends it needs nothing done,
        // because the strip is already resting on the card the last step named.
        ScrollGesture {
            id: scroll

            onBegan: strip.scrubSpent = 0
            onMoved: dx => strip.scrub(dx)
            onEnded: strip.coast(scroll.vx)
        }

        // WHAT YOU ARE LOOKING AT, said in words because a picture cannot say
        // its own name. UNDER THE HERO, because this is not a heading, it is a
        // CAPTION: the label under the photograph saying which photograph it
        // is, and the difference is which way the eye travels.
        //
        // FLOATING, now that there is no panel to put it on. The buttons carry
        // their own paint and read on any wallpaper; that is what a pill is
        // for.
        Row {
            id: caption

            anchors.horizontalCenter: parent.horizontalCenter
            y: strip.height / 2 + root.heroHeight / 2 + Appearance.padding.large
            spacing: Appearance.padding.normal

            // WHAT SHAPE THIS ONE IS, AGAINST WHAT SHAPE THE SCREEN IS, drawn
            // rather than described. See components/AspectMark.qml.
            AspectMark {
                anchors.verticalCenter: parent.verticalCenter
                visible: !!strip.currentPath
                aspect: Wallpaper.aspectOf(strip.currentPath)
                reference: root.screenAspect
                fits: Wallpaper.fits(strip.currentPath, root.screenAspect)
                // TWICE THE BODY SIZE, which is the height the pills beside it
                // come out at and therefore the height this row is. Off the
                // type ladder rather than measured off a Pill, because a
                // binding onto a sibling's height inside the row that sizes
                // itself from its children is a loop.
                size: Appearance.font.size.small * 2
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: strip.currentPath ? strip.currentPath.split("/").pop() : `nothing in ${Wallpaper.dir}`
                color: Appearance.colour.text
            }

            // WHICH SCREENS THE NEXT TAP IS FOR. A PILL, NOT A TOGGLE, because
            // it is not a setting: it is the scope of the press you are about
            // to make, and it resets when the picker closes. GONE on one
            // screen, rather than disabled: on a laptop on its own, "this
            // screen" and "all screens" are the same deed.
            Button {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.manyScreens
                icon: root.everywhere ? "devices" : "monitor"
                iconFill: root.everywhere ? 1 : 0
                paint: root.everywhere ? Appearance.colour.accentFill : Appearance.colour.fillStrong
                onClicked: root.everywhere = !root.everywhere
            }

            // WHICH OF THE FOLDER YOU ARE BEING SHOWN, and the way to see the
            // rest of it. GONE WHEN IT WOULD DO NOTHING: every wallpaper fits,
            // or none of them does.
            Button {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.fitted.length > 0 && root.fitted.length < Wallpaper.available.length
                icon: root.predicted ? "fit_screen" : "photo_library"
                iconFill: root.predicted ? 1 : 0
                paint: root.predicted ? Appearance.colour.accentFill : Appearance.colour.fillStrong
                onClicked: root.showAll = !root.showAll
            }

            // ONLY WHEN THERE IS SOMETHING TO SAY. A still is what a wallpaper
            // is expected to be, so it gets no badge; the three that are not
            // get one, in the accent, because "this one moves" is state worth
            // a colour.
            Button {
                anchors.verticalCenter: parent.verticalCenter
                visible: !!root.badgeFor(strip.currentPath)
                interactive: false
                paint: Wallpaper.isFrozen(strip.currentPath) ? Appearance.colour.fillStrong : Appearance.colour.accentFill
                icon: root.badgeFor(strip.currentPath)
                iconFill: Wallpaper.isFrozen(strip.currentPath) ? 0 : 1
            }
        }
    }

}
