pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

// The settings page itself: everything you can see of it, and nothing about
// where it is being drawn.
//
// A PLAIN Item, the way LockFace is, and for the same reason. The page is drawn
// twice in this shell - once by the shell's own surface and once by a real
// window - and the only way two surfaces can be trusted to be showing the same
// thing is for it to literally be the same component. Anything that leaked into
// here about which surface it was on would be the first thing to drift.
//
// It also means the page can be dropped into an ordinary window and
// screenshotted, which is how anything in here gets checked.
//
// A DISCRETE CARD, not a blob in the chassis field. The page is a peer of the
// windows it sits among rather than something emerging from the band, and melt
// belongs where one thing comes out of another (DESIGN.md section 14). The
// field's eight slots are also spoken for.
//
// WHAT IS ON IT is pages, and the face is only the frame: a rail that names
// them, a pager that shows one, and the furniture (title, handover button,
// corner grip) that belongs to the card rather than to any page. WHICH page is
// showing lives on the Settings singleton, not here, because the face is drawn
// twice and the two copies must agree; see Settings.page.
Item {
    id: root

    // WHICH SIDE OF THE HANDOVER THIS COPY IS ON.
    //
    // What the button offers differs, because the button is the handover. So does
    // the boundary of the page, and only the boundary: everything inside it is the
    // same drawing at the same size in both places.
    //
    // A card floating on the shell's blurred band owns its own edge, so it draws
    // its own corners and lets the band show through. A WINDOW does not own its
    // edge - the compositor draws a border, a corner and a shadow around every
    // other window on the desktop, and a page that brought its own would be
    // wearing two. So in a window the page stops at the frame it was given, and
    // fills it: opaque, square, right out to the corners the compositor is about
    // to cut. It is a window, and it should look like the others.
    property bool windowed: false

    signal handover

    // THE GRIP, HANDED OUT AS A RECTANGLE. The tap that closes the page lives
    // on SettingsPanel's Pull, not here (see the grip below for why the grip
    // cannot own a press), so the panel needs to know where the grip IS to tell
    // a tap on it from a tap on the rest of the page's quiet surface. Handing
    // out the Item rather than numbers is what keeps the geometry in one place:
    // the panel maps into it and asks `contains`, and the grip's own size
    // arithmetic is never restated anywhere.
    readonly property Item gripItem: grip

    // Lit while the panel's Pull is holding a press that began on the grip.
    // WRITTEN BY THE PANEL, not sensed here, because the face deliberately
    // cannot see that press: the Pull behind the card owns it (again, see the
    // grip), and a hover area's `containsMouse` freezes for the duration of
    // somebody else's grab, so the face has no honest way to know. The float
    // copy never sets it and never should: its grip is not drawn.
    property bool gripHeld: false

    readonly property real pad: Appearance.padding.large

    G2Rect {
        anchors.fill: parent

        radius: root.windowed ? 0 : Appearance.rounding.large
        color: root.windowed ? Appearance.colour.surfaceSolid : Appearance.colour.surface

        // The title sits in the card's own top-left rather than being centred,
        // because a page is read from its corner and a dialog is read from its
        // middle, and this is a page.
        StyledText {
            id: title

            x: root.pad
            y: root.pad

            text: "Settings"
            font.pixelSize: Appearance.font.size.large
            color: Appearance.colour.text
        }

        StyledText {
            id: subtitle

            anchors.left: title.left
            anchors.top: title.bottom
            anchors.topMargin: Appearance.padding.small

            text: root.windowed ? "a window, for now" : "drawn by the shell"
            color: Appearance.colour.textFaint
        }

        // THE PAGE RAIL, down the card's left: the sidebar idiom in miniature.
        // One icon per entry in Settings.pages, a fill behind the one you are
        // on, a lift for the one under the cursor, and a tap to go there.
        //
        // NAVIGATION, not decoration, and quieter than the content on purpose:
        // its resting icons sit at the faint tier, below anything a page draws,
        // because a rail that competed with the rows beside it would read as a
        // second column of settings. It brightens exactly as far as it is being
        // used.
        //
        // A rail rather than tabs across the top for the reason the shell's own
        // bar is vertical: the pages are peers you glance between, and a
        // vertical strip of marks reads as places where a row of words reads as
        // modes. It also leaves the title's line alone.
        Column {
            id: rail

            // SIZED FROM THE MARK, floored at the minimum target, the same
            // arithmetic as everything else that holds one icon: the slot
            // exists to make the glyph hittable, so it is the glyph plus its
            // air, never a number of its own.
            readonly property real slot: Math.max(Appearance.sizes.minTarget, Appearance.font.iconSize + Appearance.padding.normal * 2)

            x: root.pad
            anchors.top: subtitle.bottom
            anchors.topMargin: Appearance.padding.large
            spacing: Appearance.padding.small

            Repeater {
                model: Settings.pages

                delegate: Item {
                    id: stop

                    required property var modelData

                    readonly property bool current: stop.modelData.key === Settings.page
                    readonly property bool hovered: tap.containsMouse

                    width: rail.slot
                    height: rail.slot

                    G2Rect {
                        anchors.fill: parent
                        radius: Appearance.rounding.normal
                        // `fill` is a hover and `fillStrong` is a selection;
                        // that is Appearance's own ladder, used at face value
                        // rather than restated in new numbers.
                        color: stop.current ? Appearance.colour.fillStrong : Appearance.colour.fill
                        opacity: stop.current || stop.hovered ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Appearance.anim.fast
                            }
                        }
                    }

                    Icon {
                        anchors.centerIn: parent
                        name: stop.modelData.icon
                        // Filled when it is the page you are on: Material
                        // treats FILL as the state axis, so the same mark
                        // saying "this one is on" is the font's own idiom
                        // rather than a colour doing double duty.
                        fill: stop.current ? 1 : 0
                        color: stop.current ? Appearance.colour.text : stop.hovered ? Appearance.colour.textDim : Appearance.colour.textFaint

                        Behavior on fill {
                            NumberAnimation {
                                duration: Appearance.anim.fast
                            }
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.anim.fast
                            }
                        }
                    }

                    MouseArea {
                        id: tap

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Settings.setPage(stop.modelData.key)
                    }

                    // The rail is icons alone, so this is the case a tooltip
                    // exists for: a mark whose name is written nowhere. The
                    // gauges in the sidebar refuse one because hovering them
                    // opens a menu that says its own name; hovering this opens
                    // nothing.
                    HoverTip {
                        text: stop.modelData.title
                        asked: tap.containsMouse
                    }
                }
            }
        }

        // THE PAGER: the one page being read, and the gesture between pages.
        //
        // Every page is a Loader in a strip, all of them alive at once rather
        // than one Loader whose source switches. Two reasons, and the second is
        // the important one: the swipe below shows the neighbouring page WHILE
        // the finger is still down, which a single reloading Loader cannot do;
        // and a page keeps its state (the icons page's picker, a scroll
        // position) across a visit to another page, which is the same argument
        // that keeps SettingsFloat alive between uses. The cost is two pages'
        // worth of rows existing at once, which is nothing.
        Item {
            id: pager

            anchors.left: rail.right
            anchors.leftMargin: Appearance.padding.large
            anchors.right: parent.right
            anchors.rightMargin: root.pad
            anchors.top: rail.top
            anchors.bottom: button.top
            anchors.bottomMargin: Appearance.padding.large

            // The strip slides and pages can be taller than the viewport, so
            // everything past this rectangle is nobody's business.
            clip: true

            readonly property int pageIndex: Math.max(0, Settings.pages.findIndex(p => p.key === Settings.page))
            // Floored, for Pull's reason: fractions divide by it, and a pager
            // measured before layout would hand them a zero.
            readonly property real extent: Math.max(1, pager.width)

            // The view for the page currently showing. A function rather than
            // a bound property, deliberately: Repeater.itemAt is not
            // notifiable, so a binding on it would evaluate once against an
            // empty Repeater, capture null, and never look again. Asked at
            // event time it is always fresh.
            function currentView(): var {
                return pageViews.itemAt(pager.pageIndex);
            }

            // Where the strip stands: pageIndex pages in, chased by the same
            // exponential smoothing everything in this shell tracks with. The
            // drag below bypasses it while a finger is down and hands it the
            // depth it let go at, which is the Follow handover every gesture
            // here makes.
            Follow {
                id: slide

                target: pager.pageIndex * pager.extent
                speed: Appearance.anim.trackSpeed
                epsilon: 0.5
            }

            // Placed, never travelled to: the first layout has no "from", and
            // a face created while Settings.page rests on a later page would
            // otherwise open mid-glide toward it.
            Component.onCompleted: slide.snap()

            // A resize is a reflow, not a journey. The window copy of this
            // face can be resized by hand, which moves every page boundary at
            // once; gliding to the same page at its new offset would show the
            // neighbour sliding past mid-resize, so the strip snaps to where
            // it already logically is.
            onExtentChanged: slide.snap()

            // THE SWIPE, and the current page's scroll: one hand-rolled
            // MouseArea BEHIND the page content, which is the same discipline
            // as every drag in this shell (DESIGN.md 15). Declaration order is
            // input order, so the rows and buttons a page draws keep their own
            // presses and only the page's quiet parts begin a gesture here.
            //
            // BOTH AXES live in this one area, arbitrated the way the
            // notification card arbitrates against its list: the press takes
            // no position at all until one axis has won, and it is decided
            // ONCE. Sideways is the pager's, and moves between pages in
            // Settings.pages order with the content following the finger.
            // Up and down belongs to the page under the cursor, because a page
            // taller than the viewport has to scroll and a scrolling page must
            // still swipe: one area judging both is what keeps the two
            // gestures from fighting over the same press.
            //
            // AND TWO FINGERS ON A TOUCHPAD ARRIVE HERE TOO, through
            // components/ScrollGesture.qml, which is why this area holds both
            // axes rather than leaving the vertical one to the wheel handler
            // below. The primitive cannot re-dispatch an event it has taken and
            // neither can QML, so the site with two live axes has to be the
            // site that judges them: a stream is fed in whole, the axis is
            // latched ONCE in the same advance() the press runs, and the two
            // behaviours are driven from the one pair of totals. That is the
            // drag path's own structure, so the two inputs stay identical by
            // construction rather than by agreement.
            MouseArea {
                id: swipe

                // Parent-frame anchors, Pull's invariant. This area happens to
                // hold still inside the pager, so `mouse.x` alone would work
                // today; the sum is written anyway so the day this area is
                // given geometry the gesture does not quietly start measuring
                // its own motion (DESIGN.md 15).
                //
                // They are also the ONE thing the two inputs do not share: a
                // press has a place and has to remember it, a stream has motion
                // and nothing to remember. Nothing past onPositionChanged
                // mentions them again.
                property real anchorX: 0
                property real anchorY: 0

                // Where the strip and the page's scroll stood when the gesture
                // began, so each axis drags relative to a fixed origin rather
                // than integrating deltas that a clamp would corrupt.
                property real fromOffset: 0
                property real fromScroll: 0

                // Which axis won. Two flags rather than one tri-state, so each
                // branch below reads as the gesture it is; both false is the
                // undecided wobble inside a click.
                property bool paging: false
                property bool scrolling: false

                // The strip's offset while a page drag runs, and the smoothed
                // velocity of whichever axis is live: the release reads the
                // velocity, not the distance, because only speed is a question
                // about intent (Pull's own release rule).
                //
                // THE VELOCITY'S UNIT DEPENDS ON THE AXIS, because the two
                // releases spend it against tokens defined in different units.
                // Paging smooths raw per-event steps, which is the unit
                // flickVelocity is written in (Pull and the notification card
                // read it the same way). Scrolling divides each step by its dt
                // first, GlideList's own arithmetic, because coastMs is
                // milliseconds OF A VELOCITY and only a per-millisecond figure
                // multiplies against it into pixels. The first cut fed the
                // per-event number to the coast anyway, and since Qt
                // compresses mouse moves to about one event per frame, a
                // per-event value is eight to sixteen times the per-ms one:
                // every lifted drag flew a whole viewport or more and slammed
                // into the clamp end. Only one axis is ever live in a gesture,
                // so one property can wear both units without them meeting.
                // A touchpad stream reports the same two shapes for the same
                // reason, so nothing about the units changes on that path: the
                // scroll axis is still divided by a real dt off the same clock,
                // and only the paging axis's per-event figure shifts with the
                // event rate (see the paging branch below).
                property real dragX: 0
                property real velocity: 0
                // When the last scroll step landed, so the step's dt can be
                // measured: a velocity in real time needs real time.
                property real lastEvent: 0

                anchors.fill: parent

                // THE GESTURE ITSELF, in three functions both inputs call. The
                // split falls exactly where the inputs differ, which is only
                // the origin; everything after the subtraction is common, so a
                // touchpad stream cannot drift into being a second opinion
                // about what a page swipe is. Pull's own arrangement.

                // A new gesture: everything the press used to zero, and nothing
                // about where it started.
                function begin(): void {
                    // A GESTURE ARRESTS WHATEVER IS MOVING, before anything is
                    // measured. Flickable stops a flick the instant a finger
                    // lands, and GlideList halts its glide the moment a drag
                    // takes over; the first cut of this handler recorded its
                    // bookkeeping and left both Follows ticking, which meant a
                    // coasting page kept sliding under a held finger, a tap
                    // could not stop a runaway scroll (a release with no axis
                    // latched settled into nothing), and a catch-drag snapped
                    // the rows back to wherever they stood at press time the
                    // moment the drag threshold latched. Halting FIRST also
                    // makes the origins captured below the truth of what the
                    // hand is holding rather than a photograph of a moving
                    // thing. The page's glide can be stopped directly, value
                    // and target pinched together through drag(); the strip's
                    // cannot (see the strip's x binding), so its arrest is the
                    // dragX capture below plus the strip wearing dragX for the
                    // whole gesture. A touchpad stream catches a glide exactly
                    // the same way, which is why this is a function both inputs
                    // call rather than the body of a press handler.
                    const page = pager.currentView();
                    if (page)
                        page.drag(page.position);

                    swipe.fromOffset = slide.value;
                    swipe.fromScroll = page ? page.position : 0;
                    swipe.dragX = swipe.fromOffset;
                    swipe.paging = false;
                    swipe.scrolling = false;
                    swipe.velocity = 0;
                    swipe.lastEvent = Date.now();
                }

                // One step, given how far the gesture has travelled IN TOTAL
                // since it began, in this area's own pixels. Totals rather than
                // steps because both the threshold test and the two offsets are
                // questions about the whole journey, and because a path
                // reporting steps would have to keep its own running sum, which
                // is this subtraction written a second time somewhere it can go
                // stale.
                function advance(dx: real, dy: real): void {
                    if (!swipe.paging && !swipe.scrolling) {
                        // Still inside the wobble of a click.
                        if (Math.abs(dx) < Appearance.sizes.dragThreshold && Math.abs(dy) < Appearance.sizes.dragThreshold)
                            return;
                        // Whichever axis dominates at the moment the gesture
                        // becomes a gesture owns it for the rest of it: a swipe
                        // that curves is still the gesture it set out
                        // as, and re-judging every move would let a page being
                        // dragged out be snatched back by its own scroll.
                        //
                        // ON THE SCROLL PATH THIS IS THE WHOLE ARBITRATION, and
                        // it has to be, because a touchpad stream is fed in
                        // whole and there is nowhere to hand the other axis on
                        // to: the wheel handler below is an ancestor's, so
                        // declining would only send a vertical scroll to the
                        // very glide this page's drag replaces. One judgement,
                        // both behaviours, one pair of totals.
                        if (Math.abs(dy) > Math.abs(dx))
                            swipe.scrolling = true;
                        else
                            swipe.paging = true;
                    }

                    if (swipe.scrolling) {
                        const page = pager.currentView();
                        if (!page)
                            return;
                        // The finger owns the position: value and target move
                        // together through drag(), so there is no smoothing
                        // between the hand and the rows. Clamped hard at the
                        // ends rather than rubber-banded; the band is what
                        // makes a THROWN list feel physical, and this is a
                        // held one.
                        // Sampled in pixels per MILLISECOND, dt clamped the
                        // way GlideList clamps it: a floor of one so a burst
                        // of events inside the same tick cannot divide toward
                        // infinity, a ceiling of a hundred so a step that
                        // follows a pause (or the wobble before the threshold
                        // latched) is not crushed toward zero by a dt that
                        // measured waiting rather than movement. Smoothed for
                        // GlideList's reason too: one event's dt is noisy
                        // enough to throw a flick the wrong way if the last
                        // sample happened to be a straggler.
                        const now = Date.now();
                        const dt = Math.max(1, Math.min(100, now - swipe.lastEvent));
                        swipe.lastEvent = now;
                        const before = page.position;
                        page.drag(swipe.fromScroll - dy);
                        swipe.velocity += ((page.position - before) / dt - swipe.velocity) * 0.4;
                        return;
                    }

                    // Clamped to the strip's real ends: there is no page past
                    // the last one to show a sliver of, and half-motion
                    // overshoot with nothing under it reads as the card
                    // tearing rather than resisting.
                    //
                    // The paging velocity stays in pixels PER EVENT, the unit
                    // `flickVelocity` is written in and the one the scrolling
                    // branch above deliberately does not use. A touchpad
                    // reports faster than a pointer does (one event per input
                    // frame against one per rendered frame), so a scroll flick
                    // has to be quicker than a drag flick to clear the same
                    // threshold; the majority rule in settle() carries the
                    // ordinary case either way, and converting the unit here
                    // would silently move the threshold for the mouse too.
                    const next = Math.max(0, Math.min(swipe.fromOffset - dx, (Settings.pages.length - 1) * pager.extent));
                    swipe.velocity += (next - swipe.dragX - swipe.velocity) * 0.4;
                    swipe.dragX = next;
                }

                // The end, however the input announced it: a lifted button, a
                // cancelled grab, or a touchpad stream that stopped sending.
                function settle(meant: bool): void {
                    // Hand the smoother the offset the gesture ends at, the same
                    // single assignment every drag in this shell ends with,
                    // and done for EVERY exit rather than only for a latched
                    // page drag: the strip wears dragX for the whole gesture
                    // (see its x binding), so a tap or a scroll that caught
                    // the strip mid-glide has been holding it still while the
                    // Follow ticked on ignored underneath, and skipping the
                    // handoff on those exits would cut the picture to wherever
                    // the Follow had quietly got to. When the strip was
                    // already at rest this is dragX writing slide.value's own
                    // number back, a no-op.
                    slide.value = swipe.dragX;

                    if (swipe.paging) {
                        // MOMENTUM before position: a flick is an intention
                        // expressed as speed, so it turns the page it was
                        // thrown toward however little ground it covered,
                        // and only a slow release asks which page is nearer.
                        const spot = swipe.dragX / pager.extent;
                        const thrown = Math.abs(swipe.velocity) >= Appearance.sizes.flickVelocity;
                        const landing = !meant ? pager.pageIndex : thrown ? (swipe.velocity > 0 ? Math.ceil(spot) : Math.floor(spot)) : Math.round(spot);
                        const entry = Settings.pages[Math.max(0, Math.min(landing, Settings.pages.length - 1))];
                        Settings.setPage(entry.key);
                    } else if (swipe.scrolling && meant) {
                        // The lift hands the glide its velocity, which is the
                        // coast: the rows keep going and ease down instead of
                        // stopping dead the instant contact breaks.
                        const page = pager.currentView();
                        if (page)
                            page.coast(swipe.velocity);
                    }
                    swipe.paging = false;
                    swipe.scrolling = false;
                }

                // THE DRAG PATH: a press, its origin, and the release.

                onPressed: mouse => {
                    // A PRESS TAKES THE GESTURE OVER, and takes it over
                    // cleanly. Both paths write one set of state, so a stream
                    // still running when a hand lands is concluded by its own
                    // rule first: a page two fingers had half-turned is
                    // ANSWERED rather than abandoned mid-strip, and the stale
                    // total it was measuring from cannot be handed to state the
                    // press has since zeroed. Before begin(), because begin()
                    // is what the ending would otherwise land on top of.
                    scroll.finish();

                    swipe.anchorX = swipe.x + mouse.x;
                    swipe.anchorY = swipe.y + mouse.y;
                    swipe.begin();
                }

                onPositionChanged: mouse => {
                    if (swipe.pressed)
                        swipe.advance(swipe.x + mouse.x - swipe.anchorX, swipe.y + mouse.y - swipe.anchorY);
                }

                onReleased: swipe.settle(true)
                // A cancel is not a choice: the strip walks back to the page
                // it was on, and a scroll simply stops where it is.
                onCanceled: swipe.settle(false)

                // THE SCROLL PATH: two fingers, answered as the same swipe.
                //
                // Fed from this area's OWN wheel signal, which is what puts it
                // in front of the pager's WheelHandler below: wheel events walk
                // the items under the pointer from the top down, and this area
                // is a CHILD of the pager, so it is asked first and a handler
                // parked on the parent is asked only for what this declines.
                // That is the priority written down rather than arranged, which
                // is the whole reason ScrollGesture is a function call and not a
                // handler of its own.
                //
                // What this declines is exactly a MOUSE WHEEL, because the
                // primitive refuses one: a notch has one axis and no motion in
                // it to track, and it already means something here. So a wheel
                // falls through to the handler below and keeps scrolling the
                // page through its glide, unchanged, while a touchpad becomes
                // the swipe. A scroll arriving while a press is down is
                // declined too (see `armed`), and lands on the same handler,
                // which is the one honest thing to do with an input the press
                // has already taken.
                onWheel: wheel => scroll.feed(wheel)

                ScrollGesture {
                    id: scroll

                    // A press owns the gesture while it lasts, so no stream may
                    // START under one. A running stream is not refused, for the
                    // primitive's reason, and cannot be: the press above has
                    // already finished it.
                    armed: !swipe.pressed

                    // The whole adoption, three lines: a stream is a press, a
                    // total is a delta, and a lapse is a release. The lapse is
                    // `meant`, because fingers that stop sending have let go on
                    // purpose; only a grab taken away is not a choice.
                    onBegan: swipe.begin()
                    onMoved: (dx, dy) => swipe.advance(dx, dy)
                    onEnded: swipe.settle(true)
                }
            }

            // THE STRIP: every page side by side, one viewport apart, slid as
            // one object. While a GESTURE is running the offset is the HAND'S,
            // not the smoother's, for the reason SettingsPanel pins `emerge`
            // during a pull: a strip that lagged the hand by an easing's worth
            // would be a switch wearing a picture of a drag.
            //
            // The WHOLE gesture, not just a latched page drag, because a
            // gesture must also arrest a strip caught mid-glide and the slide
            // cannot be halted the way the page's scroll can: its target is a
            // bound expression, and assigning a bound property destroys the
            // binding for good (the trap GlideList's reset() documents). So
            // from the press or the stream's first event the strip wears dragX,
            // frozen where it was caught and then following the hand if paging
            // latches, while the Follow ticks on ignored in the background;
            // settle() hands the Follow the held offset at the end so the
            // picture never cuts.
            //
            // Both inputs are named because both have one, and `paging` covers
            // the sliver at the end of each where neither is: Qt drops
            // `pressed` BEFORE delivering the release, and ScrollGesture clears
            // `active` before firing its lapse, so the flag is what keeps the
            // hand's number authoritative until settle() has done the handoff.
            Row {
                id: strip

                x: -(swipe.pressed || scroll.active || swipe.paging ? swipe.dragX : slide.value)
                height: pager.height

                Repeater {
                    id: pageViews

                    model: Settings.pages

                    delegate: Item {
                        id: view

                        required property var modelData

                        width: pager.extent
                        height: pager.height

                        // The page's own vertical scroll: a target chased by a
                        // Follow, which is the glide idiom GlideList uses,
                        // carried here because a page is arbitrary content
                        // rather than a uniform ListView. Wheel notches and
                        // the drag above both move the target; the content
                        // follows.
                        property real target: 0
                        readonly property real position: flow.value
                        readonly property real limit: Math.max(0, content.implicitHeight - view.height)

                        function scrollTo(y: real): void {
                            view.target = Math.max(0, Math.min(y, view.limit));
                        }

                        // The finger owns the position while it is down: value
                        // and target move together, so nothing smooths between
                        // hand and content.
                        function drag(y: real): void {
                            view.scrollTo(y);
                            flow.value = view.target;
                        }

                        // The lift's velocity spent as distance. `v` is in
                        // pixels per MILLISECOND, never the per-event number
                        // the paging axis smooths: coastMs is milliseconds of
                        // the velocity the drag ended at, so only a per-ms
                        // figure multiplies against it into pixels. This once
                        // took the per-event value straight and coasted eight
                        // to sixteen times too far, turning every lift into a
                        // slam against the clamp end.
                        function coast(v: real): void {
                            view.scrollTo(flow.value + v * Appearance.sizes.coastMs);
                        }

                        // Content that SHRANK under the view - the icons page
                        // swapping its long list for the short picker does it
                        // on every pick - would otherwise leave the page
                        // parked past its own end, which looks like the rows
                        // scrolled off the top. GlideList's settle() learned
                        // this the same way.
                        onLimitChanged: view.scrollTo(view.target)

                        Follow {
                            id: flow

                            target: view.target
                            speed: Appearance.anim.scrollSpeed
                            epsilon: 0.5
                        }

                        Loader {
                            id: content

                            width: view.width
                            y: -view.position

                            // THE DISPATCH TABLE IS A SPELLING RULE, not a
                            // switch: key "icons" loads pages/IconsPage.qml,
                            // and every page named in Settings.pages resolves
                            // the same way, so adding one never adds a case
                            // here (~/.claude/rules/math-over-hardcoding.md,
                            // applied to dispatch).
                            source: `pages/${view.modelData.key.charAt(0).toUpperCase() + view.modelData.key.slice(1)}Page.qml`
                        }
                    }
                }
            }

            // THE MOUSE WHEEL, and only it, now that the swipe above takes a
            // touchpad as a gesture: this is an ancestor of that area, so it is
            // asked second and sees exactly what the area declines. A notch
            // scrolls the page it is over, by GlideList's own step, through the
            // same target the drag uses, which is what a notch has always meant
            // here and what it must go on meaning: it has one axis and no
            // motion in it to track, so there is no swipe in it to find.
            //
            // The pixel branch is not dead. It answers a touchpad scroll the
            // swipe declined because a press was already down, which is the one
            // case where the gesture is spoken for and the scroll still has to
            // do something honest.
            //
            // Still deliberately NOT GlideList's split treatment for the notch
            // itself: that second pipeline earns its keep on a thousand-row
            // launcher list, and a settings page is a few hundred pixels of
            // rows.
            WheelHandler {
                onWheel: event => {
                    const page = pager.currentView();
                    if (!page)
                        return;
                    event.accepted = true;
                    const step = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y / 120 * Appearance.sizes.rowHeight * Appearance.sizes.wheelRows;
                    page.scrollTo(page.target - step);
                }
            }
        }

        // THE BUTTON, at the bottom of the card rather than beside the title.
        //
        // It is not a title-bar control. What it does is change what kind of
        // thing the page is, which is a decision about the page, so it sits at
        // the end of it where the decisions go.
        G2Rect {
            id: button

            readonly property bool hovered: press.containsMouse

            x: root.pad
            y: parent.height - height - root.pad
            width: label.x + label.width + Appearance.padding.normal
            height: Math.round(Appearance.font.size.small * 4 / 3) + Appearance.padding.normal * 2
            radius: Appearance.rounding.normal

            color: button.hovered ? Appearance.colour.fillStrong : Appearance.colour.fill

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }

            Icon {
                id: mark

                x: Appearance.padding.normal
                anchors.verticalCenter: parent.verticalCenter

                // Out of the shell and into the desktop, or back in again. Two
                // directions of one gesture, so two arrows of one drawing.
                name: root.windowed ? "close_fullscreen" : "open_in_new"
                size: Appearance.font.iconSize
                color: button.hovered ? Appearance.colour.text : Appearance.colour.textDim
            }

            StyledText {
                id: label

                x: mark.x + mark.width + Appearance.padding.small
                anchors.verticalCenter: parent.verticalCenter

                text: root.windowed ? "Put it back" : "Pull it out"
                color: button.hovered ? Appearance.colour.text : Appearance.colour.textDim
            }

            MouseArea {
                id: press

                anchors.fill: parent
                hoverEnabled: true

                onClicked: root.handover()
            }
        }

        // WHICH CORNER THE PAGE GOES BACK INTO, said as a mark rather than as a
        // control.
        //
        // The page is closed by pushing it down and right into the corner it
        // grew out of (SettingsPanel's Pull), and a gesture nobody can discover
        // is no better than the keyboard shortcut nobody can press. So something
        // on the page has to point at it. NOT a close button: that is the small
        // permanent control this shell is built without, and it would also be a
        // lie about the mechanism, since what closes the page is a direction
        // rather than a target. NOT a titlebar either, for the reason the
        // handover button is at the bottom of the card and not beside the title.
        //
        // A CORNER GRIP is the one mark that says a diagonal. Ribs laid across
        // the push's own direction, thickening as the corner opens out, which is
        // the oldest "this corner is draggable" drawing there is and the only
        // one that carries an axis rather than just a spot. A horizontal handle
        // would say "drag me down"; a dot would say nothing.
        //
        // ONLY WHILE THE SHELL DRAWS IT. In a window the page cannot be pushed
        // anywhere, and a grip in the bottom-right of a floating window is a
        // resize handle that does not resize. This is the second thing the
        // boundary flag decides, and like the first it is about the page's edge
        // rather than about anything inside it.
        //
        // IT TAKES NO PRESSES OF ITS OWN, AND YET IT IS THE PAGE'S ONE TAP
        // TARGET, and those two sentences are not in tension: they are the same
        // decision seen from input and from meaning.
        //
        // From meaning: a mark that points at the close gesture but cannot be
        // pressed is a lie about half of itself, and the gesture's whole
        // discoverability problem (see above) reappears for anyone who tries
        // the obvious thing and clicks the mark. So tapping the grip closes
        // the page.
        //
        // From input: a press that lands here is AMBIGUOUS until it moves. It
        // may be the tap that closes, or the first inch of the shove that
        // closes by dragging, and only the Pull behind the card can tell those
        // apart, because telling them apart is the whole of what a Pull is. A
        // MouseArea here that accepted the press would win it by stacking
        // order, the Pull would never see it, and the one place on the page
        // that most invites the shove (the mark that draws the shove's own
        // diagonal) would be the one place the shove could not start. So the
        // press falls through to SettingsPanel's Pull exactly as it always
        // did, and the panel answers the Pull's `tapped` gated to this
        // rectangle: the grip contributes WHERE, the Pull decides WHAT.
        //
        // The minTarget floor on `span` below was there for legibility; it is
        // load-bearing now, because it is what makes the grip a target you can
        // aim at in both hittable dimensions rather than three thin lines.
        Item {
            id: grip

            // SIZED FROM THE RIBS, never the ribs from the size. The mark exists
            // to be a legible stack of lines, so the spacing between them is the
            // shell's smallest tier and the box is however big that many of them
            // at that pitch turn out to be, floored at the minimum target so the
            // whole thing is never smaller than something you could aim at.
            // Change `ribs` and the grip grows; nothing else needs touching.
            readonly property int ribs: 3
            readonly property real pitch: Appearance.padding.small
            readonly property real span: Math.max(Appearance.sizes.minTarget, grip.pitch * Math.SQRT2 * (grip.ribs + 1))

            x: parent.width - grip.span - root.pad
            y: parent.height - grip.span - root.pad
            width: grip.span
            height: grip.span

            visible: !root.windowed

            // The affordance's other half: the cursor says "clickable" before
            // the ribs do. Qt.NoButton is the entire trick; with no buttons
            // accepted the press is never taken, so it falls through to the
            // Pull (see the header above), while hover and the cursor shape
            // still work, because those ride on hover events rather than on
            // the press. This area is a sign, not a control.
            MouseArea {
                id: feel

                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
            }

            Repeater {
                model: grip.ribs

                G2Rect {
                    id: rib

                    required property int index

                    // HOW FAR THIS RIB IS FROM THE CORNER, measured along the
                    // push's own diagonal, and everything else about it follows
                    // from that one number (~/.claude/rules/math-over-hardcoding.md).
                    // The ribs divide the box's diagonal evenly, so the first and
                    // the last get the same air as the gaps between them rather
                    // than one of them landing on the corner itself.
                    readonly property real reach: (rib.index + 1) / (grip.ribs + 1) * grip.span / Math.SQRT2

                    // A chord across a square corner at perpendicular distance d
                    // is exactly 2d long, so the ribs widen as the corner opens
                    // out and the outermost one is the box's own diagonal. That
                    // is the whole shape of the mark, and it is arithmetic rather
                    // than three lengths chosen by eye.
                    width: rib.reach * 2
                    height: Appearance.font.stem
                    radius: rib.height / 2

                    // Centred on the foot of that perpendicular, then turned
                    // ACROSS the push rather than along it: a rib parallel to the
                    // gesture would read as a track to slide in, and this is a
                    // grip to shove. Negative because Qt's rotation is clockwise
                    // and the ribs run up and to the right.
                    x: grip.span - rib.reach / Math.SQRT2 - rib.width / 2
                    y: grip.span - rib.reach / Math.SQRT2 - rib.height / 2
                    rotation: -45

                    // The subtitle's weight at rest, not the title's, and not
                    // the watermark tier below it: this is live and worth
                    // finding, and it is not what the page is for. It climbs
                    // the label ladder as the hand closes in, the same rungs
                    // the rail's icons use: dim under the cursor, full while
                    // the press the Pull is holding began here (`gripHeld`,
                    // written by the panel; the face cannot sense that press
                    // itself, see the property). Weight rather than a fill
                    // behind the ribs, because a fill would box the mark and
                    // the mark's whole shape is that it is the corner itself.
                    color: root.gripHeld ? Appearance.colour.text : feel.containsMouse ? Appearance.colour.textDim : Appearance.colour.textFaint

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
