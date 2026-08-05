pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services
import Quickshell.Services.Notifications

// One notification, on screen.
//
// A row INSIDE the tray, not a shape of its own in the chassis field. The tray
// makes the one join to the shell; see NotificationTray for why that beat both
// of the field-level arrangements this went through.
//
// So the background is a raised FILL rather than the shell's surface material.
// A veil over what is already there, not a second translucent sheet: stacking
// the surface on itself doubles its opacity and the card comes out heavier than
// the shell it belongs to.
Item {
    id: root

    required property var entry
    required property real fullWidth

    // ROOM TO READ, in the one place there is time to.
    //
    // A popup is a glance: it arrives over what you were doing, it leaves on its
    // own, and it is capped tight so a chatty app cannot take the screen. The
    // hub is the opposite gesture. You went to the corner and asked for it, and
    // nothing in it expires while you are looking, so the same caps there are
    // not restraint, they are an ellipsis on the thing you opened the tray to
    // read. Same card, told which of the two it is in.
    property bool roomy: false

    signal dismissed

    readonly property var notification: entry?.notification ?? null
    readonly property bool urgent: !!notification && notification.urgency === NotificationUrgency.Critical

    // Arrival: unfolds downwards out of the tray and fades up. EXPONENTIAL,
    // because another notification can land on top of it mid-flight and it has
    // to retarget rather than finish a scripted move to a stale place.
    property real reveal: 0

    // Departure, 0 to 1, driving the same collapse in reverse. FIXED duration,
    // unlike the arrival, because the service has to know when it is done: see
    // Notifs.exitMs. Both ends read the one number, so they agree by
    // construction rather than by a callback that a destroyed card never sends.
    property real leave: 0
    readonly property bool leaving: entry?.leaving ?? false

    // How much of the row is actually there. The stack's height is the sum of
    // these, so the tray grows and shrinks by itself and the rows below a
    // departing one slide up without any of them being told to.
    readonly property real open: Math.max(0, reveal - leave)

    // Where the card is, and how far you actually pulled. They differ while it
    // is resisting.
    property real dragX: 0
    property real pulled: 0

    // Which way it was THROWN, if it was: -1, 0 or +1.
    //
    // A card let go past the commit point should keep going. Without this it
    // stopped dead wherever the pointer stopped and then collapsed in place,
    // which reads as the throw being ignored and the card dying of something
    // else. The fling rides `leave`, so it is the same one motion as the
    // collapse rather than a second animation racing it.
    property int flung: 0

    readonly property real throwDistance: fullWidth * Appearance.sizes.dragDismissFraction

    // Committed by DISTANCE or by SPEED, either alone. Distance was the only
    // test, and it quietly demanded that every throw be a long one: a short
    // sharp flick, the most natural way a hand has of getting rid of
    // something, stopped well short of the commit line and the card walked
    // back home as if nothing had been said. A flick is an intention expressed
    // as speed, and asking it to also cover distance is asking it twice. The
    // distance test stays for the slow deliberate drag, which is the gesture
    // it was actually measuring all along.
    //
    // The speed arm only counts speed pointing AWAY from home. An unsigned
    // magnitude was tried first, and it read the cancel gesture as a throw:
    // drag a card out, think better of it, bring it briskly back and release
    // mid-return, and the return itself is fast enough to clear the
    // threshold, so the change of mind DELETED the card, off the wrong edge,
    // which is exactly the "dragging back cancels" promise of DESIGN.md 15
    // broken by the arm that was added to honour flicks. Speed only means
    // "throw" when it agrees with where the card is displaced, which is what
    // the product's sign tests; a genuine flick always passes, because the
    // flick's own travel is what put the card on that side of home in the
    // first place.
    readonly property bool committed: Math.abs(pulled) >= throwDistance || (pulled * drag.velocity > 0 && Math.abs(drag.velocity) >= Appearance.sizes.flickVelocity)

    // Where the card actually sits: the drag, plus however much of the fling has
    // played. At leave = 1 it is exactly one card-width clear of home.
    readonly property real throwX: dragX + flung * leave * Math.max(0, fullWidth - Math.abs(dragX))

    // The countdown itself belongs to the ENTRY and is not read here at all.
    // Nothing on the card draws it: see the removed progress rule below the
    // background. The card still PAUSES it, which is the part that matters.
    //
    // PAUSED while the cursor is on it. A notification that expires from under
    // the pointer while you are reaching for its button is the single most
    // annoying thing a shell can do. Pushed to the entry so it survives a rebuild.
    //
    // A HoverHandler, not the drag area's containsMouse. Qt gives hover to the
    // topmost item that takes it, so the moment the cursor reached an action
    // button the card decided it was no longer hovered and the countdown resumed
    // UNDER THE BUTTON someone was already aiming at: the exact bug this pause
    // exists to prevent, reintroduced by how it was measured. A HoverHandler is
    // passive and stays hovered while its own descendants are.
    readonly property bool held: hover.hovered || drag.pressed || root.kept
    onHeldChanged: if (entry)
        entry.held = held

    // KEPT: the touch answer to hover, and the pin a mouse never had.
    //
    // Everything above is an argument about a cursor. A HoverHandler receives no
    // touch events at all, so on a touchscreen `hovered` is false for the whole
    // life of every popup and the pause simply never happens: the notification
    // runs its five seconds out mid-sentence and there is nothing a finger can do
    // about it. The other disjunct, `drag.pressed`, DID pause it, and the price
    // of using it was the card itself: letting go of a press that never travelled
    // is a click, and a click dismisses (DESIGN.md 15), so the one touch gesture
    // that paused a notification was also the one that deleted it.
    //
    // A finger cannot rest on something to say it is looking at it, so it HOLDS
    // to say it. Past the press-and-hold interval the card latches this, the
    // countdown stops, and the release that follows is no longer a click (see
    // onReleased). The lift the card already does under a pointer is what says it
    // happened, because `held` is what colours the background and this is now one
    // of the three things that sets it.
    //
    // It is a LATCH and not a second kind of hover: nothing lets go of it, so a
    // kept popup stays on the screen until it is thrown away, acted on, or the
    // tray is cleared. That is the point of it. A mouse user gets the same pin,
    // which they did not have before either: hovering suspends a countdown only
    // while the pointer is parked on the card, so the moment you look away to
    // read the thing the notification was about, it resumes and goes.
    property bool kept: false

    width: fullWidth
    implicitHeight: body.implicitHeight + Appearance.padding.normal * 2
    height: implicitHeight * open

    // CLIPPED, so the contents keep their real size while the row collapses.
    // Scaling them with it squashes the text, which reads as the notification
    // being crushed rather than closed.
    clip: true

    // One expression owns x: the throw, and nothing else. The row arrives by
    // unfolding rather than by sliding, so an arrival and a drag can never
    // fight over the same axis.
    x: throwX
    opacity: open * Math.max(0.1, 1 - Math.max(0, Math.abs(throwX) - throwDistance * Appearance.sizes.dragResistance) / (fullWidth * 0.6))

    HoverHandler {
        id: hover
    }

    Component.onCompleted: grow.target = 1

    // Reversible, because an entry that merely timed out RESETS: it leaves the
    // popups and stays in the tray as the same object. A delegate that outlives
    // that (the tray was open) would otherwise sit at leave = 1 forever, present
    // in the list and zero pixels tall.
    onLeavingChanged: {
        if (leaving) {
            exit.start();
        } else {
            exit.stop();
            leave = 0;
            flung = 0;
        }
    }

    NumberAnimation {
        id: exit

        target: root
        property: "leave"
        to: 1
        duration: Notifs.exitMs
        // OUT, not in-out. A dismissal is an answer to something someone just
        // did, so it has to start at full speed; easing into it spends the first
        // third of the animation looking like nothing happened.
        easing.type: Easing.OutCubic
    }

    Follow {
        id: grow

        speed: Appearance.anim.revealSpeed
        epsilon: 0.005
        onValueChanged: root.reveal = value
    }

    Follow {
        id: settle

        speed: Appearance.anim.revealSpeed
        target: 0
        onValueChanged: if (!drag.throwing)
            root.dragX = value
    }

    // Resistance before the commit point, 1:1 after it. The card gives back only
    // half of the first fifth of the throw, so it feels like it is holding on;
    // past the commit point the slope changes and it tracks the pointer exactly.
    function resist(delta: real): real {
        const commit = root.throwDistance;
        const k = Appearance.sizes.dragResistance;
        const m = Math.abs(delta);
        const held = m < commit ? m * k : commit * k + (m - commit);
        return delta < 0 ? -held : held;
    }

    // Concentric with the tray by construction: an inner corner sits its own
    // inset in from the outer one, so a fixed radius here would read as pinched
    // at the top and loose at the bottom of the same shape.
    readonly property real radius: Math.max(Appearance.rounding.small, Appearance.rounding.large - Appearance.padding.normal)

    G2Rect {
        anchors.fill: parent
        radius: root.radius
        // It answers the cursor. A stack of cards that does nothing under the
        // pointer is the one place in this shell where nothing is alive, and the
        // lift also says which card a throw is about to take.
        color: root.held ? Appearance.colour.fillStrong : Appearance.colour.fill

        Behavior on color {
            ColorAnimation {
                duration: Appearance.anim.fast
            }
        }
    }

    // A critical notification is marked by a bar down its leading edge, not by a
    // differently coloured card. Colour alone is not a state cue, and a whole
    // card tinted red is a fire alarm for something that is merely important.
    //
    // It TAKES ROOM. Drawn at the same inset as the content it was sharing three
    // pixels with the app's badge plate, showing through it because a fill is a
    // veil rather than paint; a mark that has to be in front of something is not
    // a mark. `spine` below is what the content moves over by.
    G2Rect {
        id: spine

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: Appearance.padding.normal
        width: Math.max(2, Appearance.padding.small / 2)
        radius: width / 2
        color: Appearance.colour.accent
        visible: root.urgent
    }

    readonly property real spineRoom: root.urgent ? spine.width + Appearance.padding.small : 0

    // NO PROGRESS RULE. There used to be a hairline along the bottom edge
    // draining with the timeout, on the argument that a card vanishing mid-read
    // reads as a glitch unless something counted it down.
    //
    // It buys less than it costs. The bar is a clock on a thing you did not ask
    // for and cannot usefully act on: knowing a notification has two seconds
    // left does not help, it only starts a race, and the countdown already stops
    // dead the moment the cursor arrives, so the one case where the remaining
    // time would matter is the one case it is not running. What is left is a
    // moving part on every card in the tray, drawing the eye to the corner that
    // has nothing to say.
    //
    // ONE padding tier inside the card, and it is the same one the tray puts
    // outside it, so the content sits two tiers in from the tray's edge without
    // either of them spending a bigger number. `large` here was 24 a side: 48px
    // of the card's width gone to air, on a card whose text column was already
    // the thing running out of room.
    Item {
        id: body

        x: Appearance.padding.normal + root.spineRoom
        y: Appearance.padding.normal
        width: root.fullWidth - Appearance.padding.normal * 2 - root.spineRoom
        implicitHeight: Math.max(badge.height, text.implicitHeight)

        // The sender's own icon when it gave one, our bell when it did not. An
        // app that bothered to identify itself should be recognised by its mark
        // rather than by reading its name.
        //
        // AND A PICTURE IS NOT A MARK. The spec has two fields here and they
        // answer different questions: `app_icon` is who sent this, the image
        // hint is what it is about. They were being read as one expression with
        // the picture merely winning, so every album cover, avatar and
        // screenshot preview was drawn at an app icon's size and centre-cropped
        // square to fill it. A 40px crop out of the middle of a screenshot is
        // not a small version of that screenshot, it is a swatch of it.
        //
        // So a card with a picture gets a picture: twice the size, and FITTED
        // rather than filled, so nothing is cut off. There is nothing behind it
        // to letterbox against, which was the reason to crop in the first place;
        // the plate is hidden under any image, so what a wide picture leaves
        // above and below it is the card, not a band of a different colour.
        Item {
            id: badge

            // An icon NAME is not a URL. `appIcon` is a freedesktop name, so
            // handing it straight to an Image failed silently and every app that
            // sent one instead of a pixmap wore the generic bell. The theme has
            // to be asked; the nullable form returns "" rather than a
            // placeholder, which is what lets the glyph take over.
            readonly property string picture: root.notification?.image ?? ""
            readonly property string mark: root.notification?.appIcon ? Quickshell.iconPath(root.notification.appIcon, true) : ""

            readonly property string source: badge.picture || badge.mark
            readonly property bool hasImage: source !== "" && art.ready

            // Square either way, so the text column starts in the same place on
            // every card and a list of them reads as a column rather than as a
            // ragged edge. Which square depends on whether there is anything
            // worth looking at.
            //
            // TWICE THE BADGE, derived rather than configured. It is the same
            // slot doing a second job, so it has no business being a number
            // anyone can move independently: the day the badge changed, a
            // separate setting would quietly stop being twice it.
            width: Appearance.sizes.notificationBadge * (badge.picture ? 2 : 1)
            height: width

            // The plate is only there to hold the glyph. Under an image it would
            // be a frame around something already square, and a step of fill
            // showing at the corners reads as the image not fitting.
            G2Rect {
                anchors.fill: parent
                radius: Appearance.rounding.small
                color: Appearance.colour.fillStrong
                visible: !badge.hasImage
            }

            Icon {
                anchors.centerIn: parent
                visible: !badge.hasImage
                // HALF THE PLATE, not the shell's text-side icon size. That one
                // is sized to sit beside a line of body text; dropped into a
                // plate three times its area it read as a mark lost in a box.
                size: Math.round(badge.width / 2)
                name: root.urgent ? "priority_high" : "notifications"
                color: root.urgent ? Appearance.colour.accent : Appearance.colour.textDim
            }

            // A MARK is cropped to fill and a PICTURE is fitted whole.
            //
            // An app icon is square already, so filling its plate costs it
            // nothing and letterboxing it would leave a step of fill at the
            // corners, which reads as the icon not fitting. A picture is not
            // square and is the thing you are being shown, so the same crop that
            // is free for the one throws most of the other away.
            //
            // Either way it is masked to the plate's curve, because an image is
            // the one shape that cannot go through G2Rect: it is a texture, not
            // a path, so it would keep its own square corners over the plate's.
            // See G2Image.
            G2Image {
                id: art

                anchors.fill: parent
                source: badge.source
                fillMode: badge.picture ? Image.PreserveAspectFit : Image.PreserveAspectCrop
                radius: Appearance.rounding.small
            }
        }

        Column {
            id: text

            anchors.left: badge.right
            anchors.leftMargin: Appearance.padding.normal
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 0

            StyledText {
                width: parent.width
                visible: !!root.notification?.appName
                text: root.notification?.appName ?? ""
                font.pixelSize: Appearance.font.size.small
                color: Appearance.colour.textFaint
                elide: Text.ElideRight
            }

            // THE ONE THING THE CARD IS ABOUT, and it says so with COLOUR, not
            // with a size. The size above `small` is 27, because the pixel grid
            // has no step between them, and a 27px headline on a card this size
            // is not emphasis, it is a banner: the card grew half again as tall
            // and the tray started shouting over the desktop it belongs to.
            // Brightest label tier against a dim body carries the same hierarchy
            // for nothing (see ~/.claude/rules/type-scale.md).
            //
            // It WRAPS rather than eliding. A summary is a whole short sentence
            // often enough ("Connection Established") that a one-line cap turned
            // most notifications into an ellipsis, and a truncated headline reads
            // as broken where a wrapped one reads as written.
            StyledText {
                width: parent.width
                text: root.notification?.summary ?? ""
                wrapMode: Text.Wrap
                maximumLineCount: root.roomy ? 4 : 2
                elide: Text.ElideRight
            }

            StyledText {
                width: parent.width
                visible: !!root.notification?.body
                text: root.notification?.body ?? ""
                font.pixelSize: Appearance.font.size.small
                color: Appearance.colour.textDim
                wrapMode: Text.Wrap
                // A notification is not a document, but three lines is where the
                // cap has to be. Two was tried, to keep the cards short, and it
                // elided the 2FA code out of "Your verification code for The
                // Movie Database (TMDB) is: 4098" - which is the whole reason
                // that notification exists. A card is allowed to be one line box
                // taller than its neighbour; it is not allowed to hide the thing
                // it came to say.
                //
                // In the hub it is barely a cap at all. The tray is a Flickable
                // that scrolls once it outgrows the screen, so a long message
                // costs a scroll rather than the screen, and the cap is only
                // still here to stop one deranged sender from making the list
                // unnavigable.
                maximumLineCount: root.roomy ? 12 : 3
                elide: Text.ElideRight
                topPadding: Appearance.padding.small
            }

            // A FLOW, not a Row. The count is the sender's to choose and the
            // labels are the sender's to write, so nothing here can know whether
            // they fit: a Row let "Do not show this message again" run straight
            // out through the side of the card. This wraps whatever does not fit
            // onto the next line, and caps each pill at the column so a single
            // long one loses characters instead of the card losing its edge.
            Flow {
                id: actions

                width: parent.width
                visible: (root.notification?.actions?.length ?? 0) > 0
                topPadding: Appearance.padding.normal
                spacing: Appearance.padding.small

                Repeater {
                    model: root.notification?.actions ?? []

                    delegate: Pill {
                        required property var modelData

                        text: modelData.text
                        width: Math.min(implicitWidth, actions.width)

                        onClicked: {
                            modelData.invoke();
                            root.dismissed();
                        }
                    }
                }
            }
        }
    }

    // Behind the contents, so it cannot eat the action buttons' clicks, but
    // still covering the whole card so the throw can start anywhere on it.
    MouseArea {
        id: drag

        // The anchor is kept in the PARENT's coordinates, on BOTH axes. `mouse.x`
        // is relative to this item and this item is what moves, so as the card
        // slides right by d, mouse.x falls by d for the same physical pointer;
        // the invariant is `root.x + mouse.x`, and `root.y + mouse.y` is the same
        // expression on the axis the card never travels along itself. It is
        // recorded all the same, because the arbitration below cannot judge which
        // way a gesture went without both numbers, and the vertical one is the
        // one that used to be missing entirely.
        property real anchorX: 0
        property real anchorY: 0
        property real startedAt: 0
        property bool throwing: false

        // How fast the hand is moving along the throw axis, in pixels per
        // MILLISECOND, smoothed with the same 0.4 as everything else: the
        // last single event before a finger lifts is noise as often as it is
        // direction, and the smoothing is what turns a stream of jittery
        // steps into one number that means "how fast was the hand actually
        // going". The step is measured between successive values of the
        // parent-frame dx rather than raw mouse.x, for the same reason the
        // anchor is kept in parent coordinates: the card is the thing that
        // moves, so its own frame is the one ruler that lies.
        //
        // Per millisecond and NOT per event, because `committed` compares
        // this number against a threshold. Per-event was tried, on the
        // argument that LaunchEdge already smooths per event; LaunchEdge gets
        // away with that because it only ever reads the SIGN, which no unit
        // can change, while a MAGNITUDE in px per event is really px times
        // the device's event rate, and that rate spans nearly an order of
        // magnitude across ordinary pointing hardware. The same physical
        // flick that committed from a touchpad would have failed from a
        // 1000Hz mouse, whose steps are small precisely because they are
        // frequent. Dividing each step by its own elapsed time is what
        // GlideList and the settings pager's scroll axis already do, for the
        // same reason: only time divides the event rate back out.
        property real velocity: 0
        property real lastDx: 0
        // When the last step landed, so its dt can be measured: a velocity in
        // real time needs real time.
        property real lastEvent: 0

        // Whether THIS press turned into a hold. `root.kept` is the lasting
        // answer and outlives the gesture on purpose; this one is per press,
        // because the release has to know what it is the end of and not what some
        // earlier press decided.
        property bool holding: false

        // Whether the press went UP OR DOWN the screen far enough to have meant
        // it, which is not the same question as whether anything scrolled.
        //
        // The list only takes the gesture off this card when it can actually
        // move: `view.interactive` is false while the tray fits, which is most of
        // the time, and a Flickable that is not interactive steals nothing. So a
        // swipe up a stack of two popups is never taken away, arrives at the
        // release with `throwing` still false, and would be read as a click and
        // DELETE the card: the same bug the arbitration below fixes, in the one
        // case where handing the gesture over is not what fixes it.
        //
        // A click is a press that stayed where it was put. Once the finger has
        // travelled a threshold's worth up or down, whatever it was, it was not a
        // click, and the release owes it nothing.
        property bool wandered: false

        anchors.fill: parent
        z: -1
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

        // ONLY ONCE THE CARD HAS COMMITTED TO A THROW, which is the other half of
        // the arbitration below.
        //
        // It was a constant `true`, and with that this MouseArea won the press
        // and never gave it back: the Flickable the cards live in could not take
        // the grab for a scroll, so a finger that pressed a card and swiped up
        // moved nothing at all, and the release then found `throwing` false and
        // read the whole thing as a click, which DISMISSED the notification you
        // had merely touched on the way past. The list could only be scrolled
        // from the twelve pixels of gap between two cards.
        //
        // False for the whole of the undecided part leaves the Flickable free to
        // steal the gesture the moment it decides the finger is scrolling; true
        // from the instant the card latches locks it out for the rest of the
        // throw, which is what the flag was there for in the first place.
        preventStealing: drag.throwing
        // The gesture ADVERTISES itself. Drag is the primary way to get rid of a
        // notification (DESIGN.md 15) and nothing on the card says so; a hand
        // that closes when you press is the cheapest way to say it.
        cursorShape: drag.pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

        onPressed: mouse => {
            anchorX = root.x + mouse.x;
            anchorY = root.y + mouse.y;
            startedAt = root.dragX;
            throwing = false;
            holding = false;
            wandered = false;
            velocity = 0;
            lastDx = 0;
            lastEvent = Date.now();
        }

        onPositionChanged: mouse => {
            if (!pressed)
                return;

            const dx = root.x + mouse.x - anchorX;
            const dy = root.y + mouse.y - anchorY;

            // Smoothed on EVERY move, before the arbitration below has decided
            // whose gesture this is, exactly the way LaunchEdge does it. The
            // flick this number exists to catch is over almost as soon as it
            // has latched, so a velocity that only started counting once
            // `throwing` was true would have a couple of events of history at
            // the release where the smoothing needs a handful; the pre-latch
            // motion is real motion and it belongs in the average. Counting it
            // costs nothing when the gesture turns out to be the list's,
            // because an unlatched release never reads it.
            //
            // The dt clamp is GlideList's, both ends of it: a floor of one so
            // a burst of events landing inside the same millisecond cannot
            // divide toward infinity, a ceiling of a hundred so the first
            // step after the press, or after a mid-drag pause, reads as slow
            // rather than being spread over a stale timestamp.
            const now = Date.now();
            const dt = Math.max(1, Math.min(100, now - lastEvent));
            lastEvent = now;
            const step = dx - lastDx;
            lastDx = dx;
            velocity += (step / dt - velocity) * 0.4;

            // WHOSE GESTURE IS THIS: the card's, or the list's.
            //
            // Both of them begin as a press on a card and there is nothing in the
            // press itself to tell them apart, so the card takes no position at
            // all until one axis has won. Vertical wins and this returns without
            // latching, which leaves `preventStealing` false and the enclosing
            // Flickable free to take the grab and scroll with the finger; the card
            // then hears `canceled` instead of `released` and stays exactly where
            // it was.
            //
            // Horizontal has to do TWO things to win. It has to travel past the
            // threshold, so the wobble inside a click is not a throw, and it has
            // to dominate the vertical, so a flick that is mostly up the screen is
            // a scroll rather than a dismissal that happened to drift sideways. A
            // threshold on its own is not arbitration: the first few pixels of a
            // scroll cross it too, on whichever axis is being measured.
            //
            // Which is exactly what the old code did, and it is worth saying
            // plainly. There was not merely no arbitration here, there was no
            // vertical MEASUREMENT: the delta was the horizontal one and nothing
            // ever looked at dy, so a straight swipe up produced a delta of about
            // zero, never reached the threshold, never latched, and arrived at the
            // release indistinguishable from a click. Between that and a
            // `preventStealing` nobody could take back, swiping the list scrolled
            // nothing and deleted the notification you started on.
            //
            // Decided ONCE, like every other gesture in the shell: past this the
            // card owns the pointer and a throw that curves upward is still a
            // throw. Re-testing on every move would let the list snatch a card
            // that was already half way off the screen.
            if (!throwing) {
                if (Math.abs(dy) >= Appearance.sizes.dragThreshold)
                    wandered = true;
                if (Math.abs(dy) > Math.abs(dx))
                    return;
                if (Math.abs(dx) < Appearance.sizes.dragThreshold)
                    return;
                throwing = true;
            }

            root.pulled = dx;
            root.dragX = root.resist(startedAt + dx);
        }

        // Long enough to be a decision rather than a press. See `kept`: this is
        // the finger's way of saying what a cursor says by resting on the card,
        // and it is the only one it has.
        //
        // NOT DURING A THROW. Qt runs this timer off the press alone and never
        // cancels it for movement, so a card dragged out slowly and thought
        // better of would cross the interval on the way and come back silently
        // pinned. A hand on its way somewhere is not a hand reading something.
        onPressAndHold: {
            if (throwing)
                return;
            holding = true;
            root.kept = true;
        }

        onReleased: {
            // A click, which dismisses too: a mouse user who expects that should
            // not be told they are holding it wrong. It has no direction, so it
            // collapses in place rather than flinging.
            //
            // UNLESS the press became a hold. The two gestures differ only in how
            // long the finger stayed down, so a hold that dismissed on release
            // would hand the card back the instant you finished pinning it, and
            // "keep this one" and "throw this one away" would be the same motion
            // told apart by a stopwatch nobody can see. The keep survives; the
            // click that would have followed it does not happen.
            //
            // `holding` and not `root.kept`, and the difference matters. The keep
            // is permanent by design, so guarding on it would mean a kept card
            // could never be clicked away again, which takes back the one thing
            // DESIGN.md 15 promises a mouse user. This flag is about this press
            // only: hold once to pin, and a plain click afterwards still dismisses.
            //
            // ...and unless the finger wandered up or down the screen. See
            // `wandered`: a list too short to scroll never takes the gesture off
            // the card at all, so without this the arbitration above would only
            // save the tray that HAS somewhere to scroll to, and the two popups
            // you swipe at most often would go on deleting themselves.
            if (!throwing) {
                if (!holding && !wandered)
                    root.dismissed();
                return;
            }

            if (root.committed) {
                // Which way it flies: the drag offset's own sign, in both
                // arms. A speed commit used to take the VELOCITY's sign
                // instead, guarding against a press that drifted one way
                // before flicking the other and left a wrong-signed offset
                // behind; the sign agreement inside `committed` now refuses
                // any speed commit whose velocity opposes the offset (that
                // shape is the cancel gesture, not a throw), so a speed
                // commit that reaches this line agrees with the offset by
                // construction and the branch would pick the same sign twice.
                // A distance commit never wanted the velocity anyway: the
                // card is out past the commit line on the offset's side, and
                // flying it any other way would cross back over home.
                root.flung = root.pulled < 0 ? -1 : 1;
                return root.dismissed();
            }

            // Abandoned short of the commit point: hand the offset to the spring
            // and let it walk home rather than snapping.
            settle.value = root.dragX;
            settle.target = 0;
            root.pulled = 0;
            throwing = false;
        }

        // THE FLICKABLE TOOK IT, which is the arbitration above succeeding rather
        // than anything going wrong. A stolen grab arrives here instead of at
        // `onReleased`, and that difference is the whole reason this handler has
        // to exist: `onReleased` dismisses, and a gesture that turned out to
        // belong to the list must leave the card precisely as it found it.
        //
        // Usually nothing has moved, because a gesture can only be stolen while
        // the card has not latched and an unlatched card has not written a pixel.
        // The offset is walked home by the same spring the release uses anyway,
        // rather than assumed to be zero: a cancel also arrives when the window
        // loses the grab under a throw already in flight, and that one has a real
        // offset to give back.
        onCanceled: {
            settle.value = root.dragX;
            settle.target = 0;
            root.pulled = 0;
            throwing = false;
            holding = false;
            wandered = false;
        }
    }
}
