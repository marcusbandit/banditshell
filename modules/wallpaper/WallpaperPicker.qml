pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.config
import qs.components
import qs.services

// THE WALLPAPER PICKER, and the second thing the bottom edge does.
//
// Swipe up and the launcher comes out of the bottom of the screen. Swipe up
// AGAIN, from the same edge, and the launcher goes and this takes its place:
// one gesture, repeated, walking through the two things that live down there.
// It is not a mode you enter and it is not a tab you press, it is the same
// motion asked twice, which is the only kind of second gesture worth having on
// a touchscreen.
//
// BUILT FOR A FINGER, and that is what makes it a different shape from
// everything else in this shell. The other panels are lists of rows because a
// row is a good target for a cursor and a good line of text; a wallpaper is not
// a line of text, it is a picture you recognise instantly and cannot name at
// all, so this is a row of big pictures you throw sideways with a flick. There
// is no search field, because you do not know what your wallpaper is called;
// there is no dense grid, because a grid of small pictures is a grid of small
// targets.
//
// THE CENTRE CARD IS ON THE ACTUAL DESKTOP. Scrubbing through the list puts
// each one up as it passes, full size, behind everything: a thumbnail cannot
// tell you whether a picture works with your windows on it, and this panel is
// deliberately narrow enough to leave most of the screen showing. Nothing is
// written until a card is tapped, so a scrub that ends in a dismissal leaves
// the setting exactly where it was.
Item {
    id: root

    // Where the shell's body ends and the screen begins: the bar's width. The
    // strip starts there rather than at the screen edge, because a card sliding
    // under the workspace column would be a card you cannot see the left third
    // of, and the column is the one thing on this screen that is always up.
    required property real originX
    required property real inset

    // HOW WIDE THE LAUNCHER IS, and therefore how wide this is.
    //
    // The two panels come out of the same edge by the same gesture and one
    // replaces the other, so they are the same object as far as the hand is
    // concerned, and an object does not change size when you look at it twice.
    // A little wider rather than the same, because a strip of pictures needs
    // more room than a column of rows and because the difference says which of
    // the two you are looking at before you have read anything.
    //
    // Taken from the LIVE launcher rather than from the config, so it tracks
    // whichever concept is running: the list one and the niagara one are
    // different widths and both are correct.
    required property real launcherSpan

    readonly property bool open: shown
    property bool shown: false

    readonly property var entries: Wallpaper.available

    // WHAT A CARD IS, and every other measurement in here comes off it.
    //
    // SIZED FROM THE SCREEN, not picked and not derived from the minimum
    // target. The floor for a touch target is 24px and a card that size would
    // clear it and be useless anyway: this is a picture you have to RECOGNISE,
    // and recognition needs area rather than reach. So the height is a fixed
    // share of the screen, which keeps the trade explicit in one number: how
    // much of the desktop the picker is allowed to cover while you are looking
    // at the desktop through it.
    //
    // A fifth. The panel comes out at a little over a quarter of the screen
    // with its caption and its air, which leaves three quarters of the live
    // preview showing, and the card is around 340x190 on a 1080p panel: big
    // enough to tell two forest photographs apart, which is the actual test.
    readonly property real cardHeight: Math.round(root.height * 0.18)
    // 16:9, because screens are, and a card that is not the shape of the thing
    // it depicts crops the picture twice.
    readonly property real cardWidth: Math.round(root.cardHeight / 9 * 16)
    readonly property real cardGap: Appearance.padding.normal

    // ONE CARD OF TRAVEL. Everything that moves the strip is measured in these:
    // the path's own spacing, the scrub, the wheel. A single number, so the
    // three cannot disagree about how far a card is.
    readonly property real pitch: root.cardWidth + root.cardGap

    // HOW MANY CARDS THE PATH HOLDS, computed from the room rather than picked.
    // Two more than fit, so a card is fully drawn before it reaches the edge of
    // the panel and fully gone after it leaves, instead of popping into
    // existence at the boundary. Never fewer than three, or there is no centre
    // to be either side of.
    readonly property int slots: Math.max(3, Math.round(root.panelWidth / root.pitch) + 2)

    // HOW BIG THE CENTRE IS, and it is over one on purpose: the card in the
    // middle is not merely the largest of a row, it is lifted out of the row.
    // Its neighbours are what a card looks like at rest and it is bigger than
    // that, which is what makes the strip read as having a focus rather than a
    // gradient.
    readonly property real centreScale: 1.08
    readonly property real nearScale: 0.82
    readonly property real farScale: 0.72

    // A PANEL, NOT A BAR ACROSS THE SCREEN.
    //
    // It used to be everything left of the frame once the sidebar had taken its
    // share, on the argument that a carousel narrower than its room has two
    // dead strips beside it. That argument was about the carousel and forgot
    // what the panel is FOR: you are looking at a wallpaper, on the desktop,
    // behind it, and a control that takes the full width of the screen to help
    // you look at the screen is in its own way.
    //
    // A quarter wider than the launcher. Floored at two and a half cards,
    // because the centre one has to sit BETWEEN its neighbours or there is no
    // strip to read, only a picture with edges; and capped at the room there
    // actually is, for a small screen where those two disagree.
    readonly property real panelWidth: Math.min(root.width - root.originX - root.inset, Math.max(root.launcherSpan * 1.25, root.pitch * 2.5))

    // The strip's own height rather than a card's, because the centre card is
    // lifted past one and the panel clips: measured from the card, the biggest
    // it ever gets would have its top and bottom shaved off at exactly the
    // moment it is the thing being looked at.
    readonly property real panelHeight: Appearance.padding.large * 2 + caption.implicitHeight + Appearance.padding.normal + root.cardHeight * root.centreScale + Appearance.padding.large

    // The whole screen while it is open, so a tap anywhere outside lands on the
    // shell and can dismiss it.
    readonly property Item maskItem: catcher

    readonly property var blobs: panel.height <= 0 ? [] : [
        {
            x: panel.x,
            y: panel.y,
            w: panel.width,
            h: panel.height,
            radius: Appearance.rounding.large
        }
    ]

    function show(): void {
        if (root.shown)
            return;
        root.shown = true;
        // Start where you already are. Opening a picker on the first file in
        // the folder rather than on the wallpaper you are looking at makes the
        // first thing it does an unasked-for change.
        strip.jumpTo(Math.max(0, root.entries.indexOf(Wallpaper.current)));
        // DEFERRED, the launcher's reason: focus is only worth taking once the
        // window has actually asked the compositor for the keyboard, and that
        // follows from `shown` in the same pass this is running in.
        Qt.callLater(root.forceActiveFocus);
    }

    function hide(): void {
        if (!root.shown)
            return;
        root.shown = false;
        // NOTHING WAS DECIDED. The desktop goes back to the setting, which is
        // where it would have been all along if this had never opened.
        Wallpaper.preview = "";
    }

    function toggle(): void {
        if (root.shown)
            root.hide();
        else
            root.show();
    }

    // Chosen, which is the one gesture here that writes anything.
    //
    // AND WHERE IT WAS CHOSEN FROM, because the new wallpaper opens out of that
    // point rather than fading in (components/reveal.frag). `from` is an item
    // whose centre is the place the choice happened: the card you pressed. It
    // is mapped into this item, which is the whole screen, and normalised,
    // which is what the shader wants and what makes the same fraction mean the
    // same relative place on a second monitor.
    //
    // Missing, and it opens from the middle. That is the honest answer for a
    // choice that came from the keyboard: Enter has no place on the screen.
    function accept(path: string, from: var): void {
        root.acceptAt(path, from);
    }

    // `at` is a point in this item's coordinates, which is the whole screen, or
    // null for a choice with no place on it.
    function acceptAt(path: string, at: var): void {
        if (at)
            Wallpaper.setFrom(path, at.x / Math.max(1, root.width), at.y / Math.max(1, root.height));
        else
            Wallpaper.setFrom(path, 0.5, 0.5);
        root.hide();
    }

    // WHAT A CARD SAYS ABOUT ITSELF, or "" for the ordinary case.
    //
    // A still picture is what a wallpaper is expected to be and gets no badge.
    // The three that move get one, and so does the fourth thing, which is the
    // one worth the most: an SVG that declares an animation and is drawn as a
    // still anyway, because Qt animates neither SMIL nor CSS and rasterises an
    // SVG once. Unbadged, that file is a wallpaper that mysteriously sits
    // there; badged, it is a shell that knows its own limit. See
    // Wallpaper.frozen.
    function badgeFor(path: string): string {
        const k = Wallpaper.kindOf(path);
        if (k === "motion")
            return "GIF";
        if (k === "video")
            return "VIDEO";
        if (k === "audio")
            return "AUDIO";
        return Wallpaper.isFrozen(path) ? "SVG · STILL" : "";
    }

    // THE KEYBOARD, on a surface built for a finger, and it is not a
    // contradiction: this panel takes the compositor's keyboard while it is up
    // (it has to, or Escape could not reach it), so the arrow keys are already
    // being delivered here and doing nothing. A row of things with one of them
    // centred is a list, whatever it is drawn as, and a list that ignores the
    // arrow keys is a list that feels broken to the half of the world that
    // reaches for them first.
    //
    // Escape is deliberately NOT here. ShellWindow owns that key for every
    // panel at once, in one ordered list, because which surface a dismissal is
    // for depends on what else is up; a local handler would take it out of that
    // order. See its Keys.onPressed.
    // Wrapping like everything else that moves the strip: the arrows walk off
    // one end and back in the other, because the strip does.
    Keys.onLeftPressed: strip.step(-1)
    Keys.onRightPressed: strip.step(1)
    // No `from`: Enter has no place on the screen, so the reveal opens from the
    // middle. See accept().
    Keys.onReturnPressed: if (strip.currentPath)
        root.accept(strip.currentPath, null)
    Keys.onEnterPressed: if (strip.currentPath)
        root.accept(strip.currentPath, null)

    // Pulled by hand, exactly the launcher's pair of calls and for exactly its
    // reasons: while `dragging` is true the panel's reveal is the HAND'S rather
    // than the animation's, so the top edge is where the finger is.
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

    // DECLARED FIRST so it sits UNDER the panel: a catch-all that comes last
    // swallows every tap meant for the thing it is supposed to be behind.
    MouseArea {
        id: catcher

        anchors.fill: parent
        enabled: root.open
        visible: root.open
        onClicked: root.hide()
    }

    // THE WAY BACK IN: push the panel down and it goes into the edge it rose
    // out of. The shell's one rule for getting rid of anything.
    //
    // A SIBLING of the panel wearing the panel's geometry rather than a child
    // filling it, for the reason ListLauncher's copy of this spells out: Pull
    // measures in its PARENT's coordinates, and a child of the panel has a
    // parent that is itself being dragged.
    Pull {
        id: putAway

        x: panel.x
        y: panel.y
        width: panel.width
        height: panel.height

        armed: root.open

        dirX: 0
        dirY: 1
        angle: Appearance.sizes.pullAngleEdge
        travel: root.panelHeight

        onPulled: fraction => root.dragTo(1 - fraction)
        onFinished: gone => root.dragEnd(!gone)
    }

    Item {
        id: panel

        readonly property real bandY: root.height - root.inset
        readonly property real restY: bandY - root.panelHeight

        // CENTRED, the way the launcher it replaces is centred, and clamped off
        // the bar for the case where the two cannot both be had. It used to be
        // pinned against the bar, which was right while it was as wide as the
        // room and is wrong now that it is a panel: two panels that swap places
        // under one gesture have to arrive in the same place.
        x: Math.max(root.originX, (root.width - width) / 2)
        y: panel.bandY + (panel.restY - panel.bandY) * root.revealed

        width: root.panelWidth
        height: root.panelHeight * root.revealed
        visible: height > 0
        clip: true

        G2Rect {
            anchors.fill: parent
            radius: Appearance.rounding.large
            color: Appearance.colour.surface
        }

        // THE SHAPE OF THAT SOFTNESS: opaque across the middle, nothing at the
        // two ends. Only the alpha is read, so the colour is arbitrary and
        // white is the conventional way to say "keep this".
        //
        // An eighth either side. Enough that a card is visibly on its way out
        // rather than being cut off, short enough that the two cards beside the
        // middle one are still pictures you can judge.
        Item {
            id: fade

            anchors.fill: strip
            visible: false
            layer.enabled: true

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal

                    GradientStop {
                        position: 0
                        color: "transparent"
                    }
                    GradientStop {
                        position: 0.13
                        color: "white"
                    }
                    GradientStop {
                        position: 0.87
                        color: "white"
                    }
                    GradientStop {
                        position: 1
                        color: "transparent"
                    }
                }
            }
        }

        // WHAT YOU ARE LOOKING AT, said in words because a picture cannot say
        // its own name and because the kind matters: a file that turns out to
        // be a video behaves differently once it is on the desktop, and this is
        // where you find that out rather than after choosing it.
        //
        // UNDER THE CARDS. It was above them, and above is where a title goes:
        // a heading announcing a section. This is not a heading, it is a
        // CAPTION, the label under the photograph saying which photograph it
        // is, and the difference is which way the eye travels. The panel is the
        // same height either way; the words simply changed ends with the air
        // that was already spent on them.
        Row {
            id: caption

            anchors.bottom: parent.bottom
            anchors.bottomMargin: Appearance.padding.large
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Appearance.padding.normal

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: strip.currentPath ? strip.currentPath.split("/").pop() : `nothing in ${Wallpaper.dir}`
                color: Appearance.colour.text
            }

            // ONLY WHEN THERE IS SOMETHING TO SAY. A still is what a wallpaper
            // is expected to be, so it gets no badge; the three that are not
            // get one, in the accent, because "this one moves" is state worth a
            // colour.
            Pill {
                anchors.verticalCenter: parent.verticalCenter
                visible: !!root.badgeFor(strip.currentPath)
                interactive: false
                // IN A FILL AND NOT THE ACCENT for an SVG that wanted to move,
                // because that badge is saying the opposite thing: the other
                // three announce a capability and this one admits a limit, and
                // the shell's colour for state is not the colour for "no".
                colour: Wallpaper.isFrozen(strip.currentPath) ? Appearance.colour.fillStrong : Appearance.colour.accentFill
                text: root.badgeFor(strip.currentPath)
            }
        }

        // THE STRIP.
        //
        // A PathView, and every one of the three things that make this carousel
        // feel like one comes out of that choice rather than out of anything
        // written here.
        //
        //   IT NEVER ENDS. A PathView's items run round the path, so the last
        //   wallpaper is followed by the first and you can keep throwing the
        //   strip in one direction forever. A list has two ends, and an end is a
        //   wall you hit while your hand is still moving.
        //
        //   THE MIDDLE IS BIGGER, continuously. The scale comes off
        //   PathAttributes interpolated ALONG the path, so a card grows as it
        //   approaches the centre and shrinks as it leaves, every frame of the
        //   way. A list can only ask "is this the current one", which is a step
        //   function: cards popped between two sizes as the index flipped, and
        //   a pop is the opposite of the thing this is for.
        //
        //   IT HAS MOMENTUM. A flick coasts across as many cards as it was
        //   thrown hard enough to reach and then snaps to whichever one it
        //   arrives at, because SnapToItem snaps where the motion stops.
        //   SnapOneItem, which the ListView had, moves exactly one card however
        //   hard you throw it, and that is the whole of why the old strip felt
        //   dead: the hand did something and the interface did the same small
        //   thing regardless.
        PathView {
            id: strip

            readonly property string currentPath: root.entries[strip.centre] ?? ""
            readonly property string currentKind: Wallpaper.kindOf(strip.currentPath)

            // How much of the running stream has already been paid out in
            // cards, in pixels of finger travel. It is what makes the scrub
            // below RELATIVE to wherever the strip has got to rather than
            // absolute from the card the fingers began on, and that is not a
            // stylistic choice: this handler is not the only thing that moves
            // the strip while two fingers are down, since whatever the wheel
            // handler is not given the view underneath it flicks by itself. An
            // index computed from the fingers' total alone would then be an
            // answer about a fraction of the journey applied to the whole of
            // it, and would drag the carousel back to where this handler on its
            // own thought it should be. Counted in whole pitches, the two
            // motions ADD UP to the travel and nothing is lost to rounding.
            property real scrubSpent: 0

            // WHERE THE STRIP IS, in cards, as a real number that is allowed to
            // run past either end: the wrap happens where it is applied, not
            // where it is stored, so a strip thrown round the folder eleven
            // times does not have to think about it.
            //
            // ONE OWNER. PathView has its own physics and they are turned off
            // (`interactive: false`, and see the note there): a view that both
            // moves itself and is moved is a view with two answers about where
            // it is, and the seam between them is where a gesture goes wrong.
            // Every input in this file sets `goal`; the finger writes `glide`
            // directly while it is down; nothing else touches either.
            property real goal: 0

            // EXPONENTIAL SMOOTHING, which is what this shell uses for anything
            // that chases a target (~/.claude/rules/animation-smoothing.md) and
            // what a strip letting go of your finger should do: fast while it
            // is far from the card it is going to, gentle as it lands, and no
            // fixed duration to be wrong at either end of the distance.
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
                // instead of fighting: three notches in a third of a second is
                // three cards, not one and a bit.
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
            // model's, which is the thing to get right and easy to get wrong.
            // Its own arithmetic, with no highlight range so no hidden term:
            //
            //     pos = fmod((i + offset) / count, 1) * count / pathItemCount
            //
            // and an item is on the path while `pos` is under one. Setting that
            // to a half and solving for the offset that centres card `p`:
            //
            //     (p + offset) mod count = pathItemCount / 2
            //     offset = pathItemCount / 2 - p
            //
            // It reads like it should be `count / 2`, which is what it was, and
            // the difference is invisible in the arithmetic and obvious on the
            // screen: the caption named one wallpaper and a different card sat
            // in the middle wearing the ring.
            // ASSIGNED, NOT BOUND, and that is not a style choice: PathView
            // writes `offset` itself in several places (a model change, a
            // regenerate, its own snapping), and a C++ write to a property
            // BREAKS the QML binding on it permanently. The strip did exactly
            // that: the caption named one wallpaper, a different card sat in
            // the middle wearing the ring, and the offset in the log was a
            // number this file had never computed. An assignment cannot be
            // broken, because the next tick of the smoother makes it again.
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
            // folder that changes it has to re-place: the offset is assigned
            // and would otherwise keep the old capacity's answer until the
            // next tick of the smoother, which for a strip standing still is
            // never.
            Connections {
                target: root

                function onSlotsChanged(): void {
                    strip.place();
                }
            }

            Component.onCompleted: strip.place()

            // WHICH CARD IS IN THE MIDDLE, and deliberately NOT `currentIndex`.
            //
            // Setting a PathView's currentIndex is a request for it to bring
            // that item into its highlight range, which is a thing it does by
            // moving the offset on its own clock. There is no highlight range
            // here and the offset is this file's, so the whole mechanism is one
            // more way for the view to disagree with itself. `centre` is the
            // same question asked of the position we already own.
            readonly property int centre: strip.wrapped(Math.round(glide.value))

            // WHERE THE STRIP WAS WHEN THE FINGER LANDED, so the drag is
            // measured from its origin rather than accumulated frame by frame.
            // Accumulating loses a little every time the pointer is coalesced
            // and the card ends up somewhere the hand did not put it.
            property real dragFrom: 0

            // THE FINGER, and the whole of what PathView used to do for itself.
            //
            // A MouseArea AND NOT A DragHandler, and it is a correctness
            // question rather than a taste one: A FINGER COULD NOT DRIVE THIS.
            //
            // Qt delivers a touch as a touch, and synthesises a mouse press
            // from it for items that only speak mouse. Pointer handlers see the
            // real touch and negotiate a grab for it, which is the better
            // mechanism and is also the one that quietly did nothing here: the
            // strip could be thrown with a pointing device and not with a hand,
            // on a panel whose entire reason for existing is that it is the one
            // surface in this shell built for a hand. Every other gesture in
            // the shell (Pull, LaunchEdge) is a MouseArea and every one of them
            // works with touch, because synthesis is the path that is actually
            // exercised. This joins them.
            //
            // ONE INPUT FOR THE WHOLE STRIP, which is the other half of the
            // change. The cards used to carry a TapHandler each, and a
            // MouseArea over them would have taken the grab and killed those
            // taps. So the tap lives here too, and which card was tapped is
            // asked of the view (`indexAt`) rather than of whichever item the
            // press happened to land on. Fewer moving parts, one place where
            // "what did the hand do" is decided.
            MouseArea {
                id: swipe

                anchors.fill: parent
                enabled: root.open
                cursorShape: Qt.PointingHandCursor
                // The press must not fall through to the push-away Pull behind
                // the panel: a sideways drag over the cards is not a dismissal.
                preventStealing: true

                // Where the strip was and where the finger was when it landed,
                // so the drag is measured from its origin rather than
                // accumulated frame by frame: accumulation loses a little every
                // time a pointer event is coalesced.
                property real from: 0
                property real fromX: 0
                property bool dragging: false

                // Smoothed pixels per millisecond, for the throw. The last
                // event before a lift is noise as often as it is direction,
                // which is why this is an average and not the final step.
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

                    // THE STRIP UNDER THE HAND, one to one and not smoothed:
                    // while a finger is down the position IS the finger, and
                    // anything between them is lag. `glide.value` is written
                    // directly rather than through `goal`, so the smoother
                    // picks up from exactly where the drag left it instead of
                    // starting its journey from wherever it had got to.
                    glide.value = swipe.from - (mouse.x - swipe.fromX) / root.pitch;
                    strip.goal = glide.value;
                }

                onReleased: mouse => {
                    if (!swipe.dragging) {
                        // A PRESS THAT NEVER TRAVELLED is a tap, and which card
                        // it was is the view's question rather than this one's.
                        const i = strip.indexAt(mouse.x, mouse.y);
                        if (i < 0)
                            return;
                        // The middle one is a choice; any other centres itself
                        // first, which is what a finger landing off to the side
                        // of a carousel means everywhere else. By the short way
                        // round, because the strip is a ring.
                        if (i === strip.centre)
                            // FROM WHERE THE FINGER WAS, not from the card's
                            // centre. `currentItem` would be the wrong item
                            // anyway (PathView's currentIndex is unused here,
                            // see `centre`), and the point you touched is a
                            // better origin than the middle of what you touched:
                            // the picture grows out of your fingertip.
                            root.acceptAt(root.entries[i], swipe.mapToItem(root, mouse.x, mouse.y));
                        else
                            strip.step(strip.shortest(i));
                        return;
                    }

                    // LET GO. Two things happen and they are the two the strip
                    // was asked for: it takes whatever the hand was still doing
                    // as a throw, and then it ROUNDS, so wherever the throw
                    // lands it lands on a card rather than between two. The
                    // glide above carries it there by exponential smoothing.
                    //
                    // `velocity` is pixels per millisecond and `coastMs` is the
                    // shell's token for how many milliseconds of it a flick is
                    // worth, so the two multiply to pixels with nothing
                    // reinterpreted. Negated because a hand going left brings
                    // later cards in from the right.
                    const thrown = -swipe.velocity * Appearance.sizes.coastMs / root.pitch;
                    strip.goal = Math.round(glide.value + thrown);
                    swipe.dragging = false;
                }

                onCanceled: {
                    if (swipe.dragging)
                        strip.goal = Math.round(glide.value);
                    swipe.dragging = false;
                }
            }

            // Where two fingers have got to, in cards. Given the TOTAL travel
            // of the stream, not a step, which is the shape ScrollGesture hands
            // out; the subtraction below is what turns one back into the other.
            function scrub(dx: real): void {
                // Fingers to the LEFT push the strip left, which brings the
                // next card in from the right, so the index rises as `dx`
                // falls. The same sentence the notch path spells as
                // `angleDelta.x < 0`, phrased for a device that reports where
                // the hand went rather than which way it was clicked. Rounded,
                // so the card turns over at the halfway mark exactly as the
                // view's own snap does.
                const steps = Math.round((-dx - strip.scrubSpent) / root.pitch);
                if (steps === 0)
                    return;

                // NOTHING IS CLAMPED any more, and the note about not banking
                // travel at the ends went with it: there are no ends. Every
                // step the fingers pay for is a step the strip takes, so the
                // spend is simply the travel and the two can never drift.
                strip.scrubSpent += steps * root.pitch;
                strip.step(steps);
            }

            // WHAT THE FINGERS WERE STILL DOING WHEN THEY LEFT.
            //
            // A stream has no release event and no rubber band, so a touchpad
            // swipe stopped dead at whatever card the last delta landed on
            // however hard it was thrown: the one input a laptop actually
            // scrolls with was the one with no weight behind it. This is the
            // coast, and it is the same arithmetic the drag's flick does in
            // C++: the speed the gesture ended at, spent over the time a flick
            // is allowed to keep going, divided by what a card occupies.
            //
            // `coastMs` is the shell's own token for exactly this, documented
            // in the milliseconds of the ending velocity a flick is worth, and
            // `vx` is in pixels per millisecond, so the two multiply to pixels
            // with nothing reinterpreted between them.
            function coast(vx: real): void {
                const cards = Math.round(-vx * Appearance.sizes.coastMs / root.pitch);
                if (cards)
                    strip.step(cards);
            }

            anchors.top: parent.top
            anchors.topMargin: Appearance.padding.large
            anchors.left: parent.left
            anchors.right: parent.right
            // Taller than the cards by however much the centre one is lifted, so
            // the biggest it gets still fits inside the view rather than being
            // clipped along its top and bottom edges at the one moment it is
            // the thing you are looking at.
            height: root.cardHeight * root.centreScale

            // THE ENDS OF THE STRIP GO SOFT.
            //
            // A carousel clipped by a panel edge has a hard vertical line down
            // each side with half a card behind it, and what that reads as is a
            // window cut into something rather than a strip that carries on. It
            // also makes the panel feel FULL, edge to edge, which is the last
            // thing a control you are looking past should feel like.
            //
            // A mask rather than a pair of gradient overlays painted on top,
            // because an overlay has to be the colour of what is behind it and
            // there is a live wallpaper behind it: any colour picked here would
            // be right on one wallpaper and a smear on the next. Eating the
            // alpha is the only version that is honest about the background it
            // does not know.
            //
            // Only while the panel is up. A layer is an offscreen pass and this
            // one has no reason to run for a strip nobody can see.
            layer.enabled: root.open
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: fade
            }

            model: root.entries
            pathItemCount: root.slots

            // NO HIGHLIGHT RANGE, NO SNAP, NOT INTERACTIVE: three lines that
            // between them turn every one of PathView's own physics off.
            //
            // Together they mean it computes a card's place from `offset` and
            // nothing else, adds no term of its own, and never moves itself.
            // Everything those features do (hold a card in the middle, settle
            // on one when you let go, carry a throw) is done above and below
            // instead, by hand, and that is not reinvention for its own sake.
            //
            // IT WAS INTERACTIVE, and the tuning is what went wrong.
            // `maximumFlickVelocity` and `flickDeceleration` are in PIXELS per
            // second, inherited from the flickable family, and were read as the
            // ITEMS a PathView's offset counts in: the cap was set to eight,
            // meaning eight pixels a second, so every throw was clamped to a
            // card crossing the panel in about a minute. What that looks like
            // is a strip that appears to stop where you left it and then very
            // slowly keeps going, which is exactly the report.
            //
            // Writing 6000 instead of 8 fixes that number. It does not fix the
            // shape of the problem, which is TWO OWNERS of one position: a view
            // that both moves itself and is moved has two answers about where
            // it is, and the seam between them is where a gesture goes wrong.
            // The settle is also the whole feel of a carousel and PathView's is
            // a fixed-duration animation, where every other moving thing in
            // this shell arrives by exponential smoothing.
            highlightRangeMode: PathView.NoHighlightRange
            snapMode: PathView.NoSnap
            interactive: false

            // EVERY CARD, BUILT ON THE WAY UP. `cacheItemCount` is the number
            // kept alive off the path, so setting it to the rest of the folder
            // means the whole folder is instantiated and every picture is
            // decoding from the moment the shell starts rather than from the
            // moment a card scrolls into view. That is what makes the strip
            // whole the instant it opens instead of filling in behind you.
            //
            // CAPPED, because this is memory: each card holds a decoded
            // thumbnail for as long as it lives. Forty is a big wallpaper
            // folder and a few tens of megabytes; past that the tail loads the
            // ordinary way, as it is scrolled to.
            cacheItemCount: Math.max(0, Math.min(root.entries.length, 40) - root.slots)

            // THE PATH: a straight line through the middle of the strip, as
            // long as the cards it has to hold. Nothing about it is a position;
            // the attributes along it are what every card reads as it passes,
            // and the interpolation between them is the whole animation.
            path: Path {
                id: line

                readonly property real span: root.slots * root.pitch
                readonly property real cy: strip.height / 2
                readonly property real cx: strip.width / 2

                startX: cx - span / 2
                startY: cy

                PathAttribute {
                    name: "cardScale"
                    value: root.farScale
                }
                PathAttribute {
                    name: "cardOpacity"
                    value: 0.4
                }
                PathAttribute {
                    name: "cardZ"
                    value: 0
                }

                // The two waypoints either side of the middle are what give the
                // centre a POP rather than a gradient. Without them the scale
                // ramps linearly from one end of the path to the other and the
                // middle card is only marginally bigger than its neighbours;
                // with them, most of the growth is spent in the last card's
                // width of travel, so a card visibly rises as it arrives.
                PathLine {
                    x: line.cx - root.pitch
                    y: line.cy
                }
                PathAttribute {
                    name: "cardScale"
                    value: root.nearScale
                }
                PathAttribute {
                    name: "cardOpacity"
                    value: 0.75
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
                    value: root.centreScale
                }
                PathAttribute {
                    name: "cardOpacity"
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
                    name: "cardOpacity"
                    value: 0.75
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
                    name: "cardOpacity"
                    value: 0.4
                }
                PathAttribute {
                    name: "cardZ"
                    value: 0
                }
            }

            // Touch handles itself. THE OTHER TWO DEVICES DO NOT, and they want
            // opposite treatment, which is why one handler answers both here
            // rather than one rule being applied to whatever arrives.
            //
            // A NOTCH IS A REQUEST, not a distance: it moves one card rather
            // than a number of pixels, because with snapping on, pixels would
            // be dragged back to the nearest card anyway and the wheel would
            // feel like it was fighting the view.
            //
            // TWO FINGERS ARE A SWIPE (components/ScrollGesture.qml, and the
            // rule the whole shell now runs on), and this carousel was the one
            // scroll site the rule had not reached. A touchpad reports an angle
            // alongside its pixels, so a stream fell into the notch path above
            // and was answered as a hundred notches a second: one flick walked
            // the entire folder past the middle, and because every card that
            // passes goes up on the ACTUAL DESKTOP, the desktop repainted with
            // every wallpaper you own in about a second. The one input that
            // most wants to scrub this strip was the one it could not survive.
            //
            // So a stream scrubs, the way a finger dragging the strip does: how
            // far the fingers have travelled, divided by what one card
            // occupies. Reversible for the whole gesture, because that division
            // is against the stream's TOTAL rather than against a count of the
            // events it happened to arrive in, so fingers brought back bring
            // the cards back with them.
            //
            // A vertical stream therefore moves nothing, which is the right
            // answer twice over: a horizontal carousel has no second axis to
            // spend one on, and it is what a finger dragging up the strip
            // already gets, since the view takes that press and has nowhere to
            // put it. A NOTCH still steps, because a wheel has one axis and
            // "which way did you turn it" is the only question it can answer;
            // fingers say where they went, and where they went was nowhere the
            // strip runs.
            //
            // Nothing gets past the strip either way: what this takes it blocks
            // (a handler's default), and the horizontal flicking of the view
            // itself is underneath it for anything it does not, so no scroll
            // made over the cards falls through to the push-back Pull behind the
            // panel and puts the picker away from the one part of it that is a
            // control, exactly as a finger's drag over the cards cannot.
            WheelHandler {
                onWheel: event => {
                    // feed() takes a touchpad and refuses a wheel, and it is
                    // asked FIRST because a touchpad reports both deltas and
                    // would otherwise be read as the notches it is not.
                    if (scroll.feed(event))
                        return;

                    // A wheel, then, and feed() has already set `accepted`
                    // false on its way out: that is its rule for handing one
                    // back to whatever else might want it, and here the answer
                    // below IS what wanted it, so the claim is made again
                    // rather than left to `blocking` to imply.
                    event.accepted = true;

                    const back = event.angleDelta.y > 0 || event.angleDelta.x < 0;
                    strip.step(back ? -strip.spin() : strip.spin());
                }
            }

            // A WHEEL HAS MOMENTUM TOO, and it is the only device here that has
            // to be given it rather than having it.
            //
            // A finger throws the strip and the view coasts; a touchpad hands
            // over a distance and the strip travels it. A wheel says one word,
            // "forward", however hard it is spun, so a notch that always moves
            // one card makes a fast spin take as long as a slow one and the
            // wheel feel geared down to nothing on a folder of fifty.
            //
            // So the STEP grows with the rate. Notches arriving faster than a
            // deliberate one-at-a-time click are read as a spin and each is
            // worth more, up to a cap, and the count decays back to one as soon
            // as the hand stops. Which is what a wheel with inertia in it does
            // mechanically, and what every other wheel on this desktop does not.
            property real lastNotch: 0
            property int notchStep: 1

            function spin(): int {
                const now = Date.now();
                const gap = now - strip.lastNotch;
                strip.lastNotch = now;
                // Under a tenth of a second apart is a spin rather than a
                // click. Every notch inside that window is worth one more card
                // than the last, to a cap: past about five the strip is moving
                // faster than the pictures can be looked at and the extra speed
                // buys nothing but a blur.
                strip.notchStep = gap < 120 ? Math.min(5, strip.notchStep + 1) : 1;
                return strip.notchStep;
            }

            // LIVE, and this is the point of the whole panel: the card in the
            // middle is on the desktop behind you at full size while you decide
            // about it.
            //
            // BUT NOT ON EVERY CARD THAT PASSES. Once the strip could be thrown
            // rather than stepped, the middle became somewhere cards travel
            // THROUGH: one flick puts a dozen of them there for a frame each,
            // and every one of those was a full-screen wallpaper being decoded
            // and put up on the desktop. The desktop strobed and the flick
            // stuttered, and both were the same fact, which is that the preview
            // was bound to a value that had become a stream.
            //
            // So the preview waits for the strip to STOP. Long enough that
            // cards flying past the middle cost nothing at all, short enough
            // that arriving at one and looking at it does not feel like a
            // request that has to be waited on.
            onCurrentPathChanged: settle.restart()

            Timer {
                id: settle

                interval: 90

                onTriggered: {
                    if (root.open && strip.currentPath)
                        Wallpaper.preview = strip.currentPath;
                }
            }

            delegate: Item {
                id: card

                required property string modelData
                required property int index

                readonly property bool centred: card.index === strip.centre

                width: root.cardWidth
                height: root.cardHeight

                // OFF THE PATH, NOT OUT OF A CONDITION.
                //
                // These three come from the PathAttributes the path is strung
                // with, interpolated at wherever this card currently sits on
                // it, which means they are continuous: a card grows every frame
                // of its approach and shrinks every frame of its departure.
                // They used to be `centred ? a : b` with a Behavior smoothing
                // the step, and the difference is the whole feel of the thing.
                // A Behavior animates AFTER the fact, on its own clock, so the
                // strip and the sizes were two motions that happened to be
                // running at once; this is one motion, and the size is a
                // property of where the card is rather than a reaction to it.
                //
                // Defaulted with `?? `, because a delegate exists for a moment
                // before the view has placed it on the path and the attached
                // values are undefined until it has.
                scale: card.PathView.cardScale ?? root.farScale
                opacity: card.PathView.cardOpacity ?? 0
                z: card.PathView.cardZ ?? 0

                // WHAT A CARD IS BEFORE ITS PICTURE ARRIVES, and what it
                // stays for a file that has no picture at all. A plate and
                // nothing on it: a strip mid-decode is a strip of cards rather
                // than a row of holes.
                //
                // IT USED TO CARRY THE MARK FOR ITS KIND, a faint image or film
                // or note glyph in the middle, and that was one idea too many.
                // The kind is already said twice, by the badge on the card and
                // by the caption, and a ghost icon under every picture is a
                // watermark on all twenty-two of them to answer a question
                // about one. Gone.
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
                // caption above. The caption says it about the centred card,
                // which is the one you can already see; this is so the strip
                // can be SCANNED for the ones that are not simply a picture,
                // which is the one thing a thumbnail genuinely cannot show:
                // every card is a still, including the cards that are not.
                Pill {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: Appearance.padding.small

                    visible: !!root.badgeFor(card.modelData)
                    interactive: false
                    colour: Wallpaper.isFrozen(card.modelData) ? Appearance.colour.fillStrong : Appearance.colour.accentFill
                    text: root.badgeFor(card.modelData)
                }

                // THE MARK ON THE ONE YOU ARE ALREADY WEARING. Not a selection
                // highlight: the centred card is what the middle of the strip
                // already says. This is the different fact that one of these
                // is the wallpaper you have.
                G2Rect {
                    anchors.fill: parent
                    radius: Appearance.rounding.normal
                    color: "transparent"
                    stroke: Appearance.colour.accent
                    strokeWidth: Appearance.font.stem * 2
                    visible: card.modelData === Wallpaper.current
                }

            }
        }

        // The strip's two fingers, kept OUTSIDE the strip. It has no input of
        // its own, so where it sits changes nothing about who gets what; it
        // sits here because a Flickable's default property posts its children
        // into the content it scrolls, and a helper that quietly travelled
        // sideways with the cards would be a thing to explain later for no
        // reason at all.
        //
        // Three lines, the shell's adoption everywhere: a stream is a press, a
        // total is a delta, and the lapse that ends it needs nothing done,
        // because the strip is already resting on the card the last step named
        // and the view's own snap holds it there.
        ScrollGesture {
            id: scroll

            onBegan: strip.scrubSpent = 0
            onMoved: dx => strip.scrub(dx)
            // The fourth line, and it is what a swipe on a touchpad was
            // missing: fingers that leave while still moving leave the strip
            // moving. See strip.coast().
            onEnded: strip.coast(scroll.vx)
        }
    }
}
