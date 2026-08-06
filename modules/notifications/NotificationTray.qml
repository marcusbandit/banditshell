pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// Notifications, in ONE tray hanging off the top-right corner.
//
// The tray is a single blob melted into the band, and the rows live INSIDE it.
// That is the third arrangement this has had, and the reasoning is worth
// keeping:
//
//   - Panels chained through the melt fused into each OTHER as well as into the
//     shell: three peers within melt distance became one lumpy mass with pinches
//     where the boundaries should have been.
//   - Melting each card into the band separately fixed that, and produced N
//     tongues off the edge, which is not one body either.
//   - A metaball chain cannot give both. Rows fuse into a column only when they
//     are closer together than half the melt, and that is exactly the spacing at
//     which they stop being legible.
//
// So the connection is made by a CONTAINER rather than by the field. One tray,
// one join to the shell, and the rows inside separated the ordinary way.
//
// It has two states and they are the same object, not two panels that hand over.
// Collapsed it shows what just arrived; put the cursor in the corner and it
// EXPANDS to everything unread, growing in place. Anything that merely timed out
// is still in there. Anything thrown away is not: see Notifs.beginLeave.
//
// There is a second way in, for a hand rather than a cursor: press at the corner
// itself and pull out of it, roughly along its diagonal, and the tray comes with
// you. The gesture is components/Pull.qml; this file only says which way it
// runs and what to do when it fires.
//
// A tray opened that way is PINNED, and it deliberately does not behave like one
// the pointer merely wandered into. A hovered tray closes when the pointer
// leaves because the pointer leaving is the only thing that could ever have
// meant "done with it": nothing was asked for, so there is nothing to take back,
// and the tray is just following the cursor around. A tray you swiped open WAS
// asked for, and closing it by the same rule would take it away the instant you
// reached past the corner for something inside it, which is the only reason
// anybody opens it. On a touchscreen that rule is not merely wrong but
// unrunnable: there is no pointer to leave, so "closes when hover ends" means
// closes immediately or never, depending on which way the toolkit guesses. So a
// pulled tray stays put until it is put away.
//
// AND PUTTING IT AWAY IS THE SAME GESTURE, REVERSED. Everything in this shell
// goes back into the edge or corner it came out of, by the gesture that brought
// it out, run backwards (DESIGN.md 15), so the tray is pushed up and to the
// right, back into the corner it was pulled from, from anywhere on the tray that
// is not something else's. There is a tap on the corner as well, and it is still
// there, but it cannot be the only way: the corner square is twenty-four pixels
// in the extreme corner of the screen, which is a fine target for a cursor that
// two edges stop for you and a poor one for the hand that opened the tray by
// swiping, since that hand is now somewhere in the middle of the list it opened.
Item {
    id: root

    // How far in from the content area's top edge the tray sits.
    required property real inset

    // The band's thickness. The tray reaches past it, to the screen edge.
    required property real edgeInset

    readonly property real panelWidth: Appearance.sizes.notificationWidth

    // PINNED: opened by a pull or a tap, and therefore not something a wandering
    // pointer gets to close. See the header for why a tray that was explicitly
    // asked for cannot be taken away by the rule that closes one nobody asked
    // for. Only a deliberate gesture clears it, because only a deliberate gesture
    // ever set it: a tap on the corner, a pull reversed back into the corner, or
    // a push on the tray itself, which is the same reversal made from where the
    // hand already is.
    property bool pinned: false

    // A pull in progress. The tray opens the instant the gesture is recognised
    // rather than on release, so the pull can be abandoned by reversing it: what
    // you are deciding about is a tray you can already see.
    property bool pulling: false

    // HOW FAR THE TRAY HAS BEEN SHOVED BACK INTO ITS CORNER, 0 to 1.
    //
    // The push's feedback, and the thing that makes it a drag rather than a
    // switch with a swipe drawn on it. The tray slides toward the corner and
    // fades as the gesture proceeds, so what you are deciding about is a tray you
    // can see leaving, and a push you reverse before letting go brings it back
    // from wherever you got to. Written by the gesture while it is running and by
    // `shove` afterwards, and never by both at once; see the Follow.
    property real pushBack: 0

    // The grace window after a hover leaves.
    //
    // Leaving starts a timer rather than closing, the same as the menus. Hover
    // is a sloppy input and there is real dead space to cross: the corner arms
    // are in the band and the tray starts a gap below it, so an immediate close
    // makes the tray unreachable from the thing that opens it.
    property bool lingering: false

    // Summoned by the corner, and held open while the cursor is anywhere in the
    // tray.
    readonly property bool hovering: cornerTop.containsMouse || cornerSide.containsMouse || trayHover.hovered

    // OPEN IF ANY OF THEM SAYS SO. Derived, and written by nothing.
    //
    // Four separate things can hold this tray open and they overlap freely: a
    // pinned tray is also hovered the whole time you are reading it, a pull ends
    // with the pointer parked in the corner arms it started from, and the grace
    // timer is running underneath both of those. While this was a plain bool
    // that each of them assigned, whichever one finished LAST won the argument,
    // so a hover leaving closed a tray that was pinned, and the grace timer
    // firing closed a tray the pointer had never actually left. Every fix for
    // that is the same fix: check the other three before writing, at which point
    // the flag is no longer the answer, it is a cache of the answer.
    //
    // A union has no ordering to get wrong. The tray is open while any reason to
    // be open is still true, and it shuts when the last of them lets go.
    readonly property bool expanded: root.hovering || root.pulling || root.pinned || root.lingering

    // WHETHER ESCAPE HAS TO REACH THIS TRAY, for the window to read: a layer
    // surface is handed no key events at all unless its window asks the
    // compositor for them, and the window is the only thing that can ask (see
    // ShellWindow's keyboardFocus, and components/Prompts.qml, which exists
    // entirely because of that one fact).
    //
    // THE PIN, and not `expanded`, though the union above is what "the tray is
    // out" means everywhere else in this file. The other three terms are a
    // pointer's: a hovered tray is closed by the pointer leaving, a pull is a
    // finger that has not let go yet, and the grace window is the tail of both.
    // None of them is a thing that was ASKED for, and a shell that took the
    // keyboard away from the window underneath every time a cursor crossed the
    // top-right corner would be swallowing somebody's typing on behalf of a tray
    // they never opened. The pin is the one term that means somebody said so, and
    // it is the only one that will not go away on its own, which is exactly the
    // set that needs a key to get rid of.
    readonly property bool wantsEscape: root.pinned

    // WHETHER SOMETHING ELSE IN THIS WINDOW IS ALREADY READING EVERY KEY. Handed
    // down rather than worked out here, because the launcher, the power panel,
    // the hotkey sheet and a menu holding a live prompt are ShellWindow's to know
    // about, and a tray that went looking for them by id would be reaching up
    // into the file that declares it.
    //
    // IT GATES THE GRAB AND NOTHING ELSE. Qt gives active focus to exactly ONE
    // item in a window, so a pin arriving while one of those is up takes the
    // caret out of the launcher's search field, or the selection off the power
    // panel's Up and Down: the panel goes on drawing and stops hearing, and
    // nothing gives it back, because ShellWindow's exclusions fire when a panel
    // OPENS and this pin arrived second. `banditshell notifications toggle` is
    // meant to be bound to a key, and a compositor bind is still delivered while
    // a layer surface holds the keyboard, so a pin landing on top of the thing
    // you are typing into is a keystroke away at all times.
    //
    // The tray loses nothing by waiting. What a pin wants is ONE key, and while
    // the focus is elsewhere ShellWindow's Escape fallback drops this pin exactly
    // as this item's own handler would; what a search field wants is every key,
    // and there is nothing that can say that on its behalf.
    property bool keyboardHeld: false

    // THE GRAB ITSELF, behind the same two questions asked at the moment it
    // happens rather than at the moment it was queued. It is deferred (see
    // below), so between the pin going on and this running the pin can have come
    // off again, or a panel that takes every key can have opened over it, and a
    // callLater bound straight to `keys.forceActiveFocus` would carry out a
    // request the shell has stopped meaning. Menus states the same function for
    // the same reason and has a third term to add to it, because a menu can hold
    // a field of its own.
    function claimKeys(): void {
        if (root.wantsEscape && !root.keyboardHeld)
            keys.forceActiveFocus();
    }

    // Taken when the pin goes on and handed back when it comes off, DEFERRED:
    // the surface only asks the compositor for the keyboard once `wantsEscape`
    // has propagated, and focus forced before that lands is focus in a surface
    // with no keys to give. Every panel in this shell that holds a key does this
    // dance; the settings page and SessionMenu both write it down.
    //
    // Handing it back matters more here than the taking does. Nothing arrives
    // once the surface stops asking, so a stale focus breaks nothing by itself;
    // what it leaves behind is a closed tray's item holding the window's focus
    // while a panel that IS on screen goes looking for it.
    onWantsEscapeChanged: {
        if (root.wantsEscape)
            Qt.callLater(root.claimKeys);
        else
            keys.focus = false;
    }

    // Hover drives the grace window and NOTHING else. It is one of four inputs
    // now, not the state itself, so it has no business deciding whether the tray
    // is open: it only says how long its own claim outlives the cursor.
    onHoveringChanged: {
        if (root.hovering) {
            grace.stop();
            root.lingering = false;
        } else {
            root.lingering = true;
            grace.restart();
        }
    }

    Timer {
        id: grace

        interval: Appearance.anim.grace
        onTriggered: root.lingering = false
    }

    readonly property var items: root.expanded ? Notifs.history : Notifs.popups

    // Visible when there is something to show, and whenever it is summoned: an
    // empty tray that says so is the answer to "did I miss anything", and a
    // corner that does nothing is indistinguishable from a corner that is broken.
    readonly property bool any: root.items.length > 0 || root.expanded

    // Nothing expires while the list is being read.
    onExpandedChanged: Notifs.paused = root.expanded

    // What the window's input mask should cover: the TRAY, not this item.
    //
    // This item fills the screen, because the tray is positioned inside it.
    // Handing it to the mask as-is made the whole screen interactive the moment
    // any notification existed, so the shell swallowed every click anywhere. A
    // critical notification never times out, so it stayed that way.
    readonly property Item maskItem: tray

    // The corner square, ALWAYS, for the reason the settings corner and the
    // launch edge both wrote down: at rest it is the only thing there is, and a
    // target that only exists once it has already been hit is not a target. It
    // is a second entry rather than part of `maskItem` because that one is
    // conditional on there being anything in the tray, and this one must not be:
    // the whole point of a corner you can pull is that it answers when the tray
    // is empty and nothing is on screen.
    readonly property Item grabItem: corner

    // The tray's rectangle, for the chassis to melt in.
    //
    // PUSHED, not bound. A binding here has to read the tray's geometry, and
    // reading a lazy binding re-evaluates it, which emits the very change signal
    // that invalidates this list WHILE it is being computed: a binding loop on
    // every frame of every arrival. Qt.callLater coalesces the pushes, so a tray
    // that moves and resizes in the same frame rebuilds this once.
    property var blobs: []

    // IT REACHES THE SCREEN'S TOP EDGE, not the tray's own top.
    //
    // The tray is drawn an `inset` in from the content area so its contents
    // clear the band, and handing THAT rectangle to the field made the tray a
    // free-floating box a gap away from the body, joined only by whatever the
    // smooth minimum could stretch across the space. A smin bridging a gap does
    // not make a fillet, it makes a NECK, and a neck has an inflection at each
    // end: the tray's left flank came out with a visible tooth where its own
    // rounded top corner and the band's inner edge each pulled the contour a
    // different way. It looked like a corner drawn wrong, which is what it was.
    //
    // Extended to y = 0 the two overlap instead of reaching for each other, so
    // there is nothing to bridge. The only join left is where the tray's flank
    // crosses the band's inner edge, and that is a plain concave fillet: one
    // tongue hanging out of the corner, which is what it is meant to be.
    //
    // The same reason TopNotch's blob is anchored at y = 0 rather than parked
    // below the band. Melt where one thing emerges from another (DESIGN.md 14),
    // and emerging means touching.
    function sync(): void {
        if (!root.any || tray.height <= 0) {
            root.blobs = [];
            return;
        }
        root.blobs = [
            {
                x: tray.x,
                y: 0,
                w: tray.width,
                h: tray.y + tray.height,
                radius: Appearance.rounding.large
            }
        ];
    }

    onAnyChanged: Qt.callLater(root.sync)
    onWidthChanged: Qt.callLater(root.sync)

    // Summon zone: an L along the two edges that meet at the corner.
    //
    // Both arms lie INSIDE the band, which is already in the input mask, so
    // neither needs a mask entry of its own. A corner is the cheapest target on
    // a screen: the pointer cannot overshoot it, so the arms can be exactly as
    // thin as the band and still be trivial to hit.
    readonly property real armLength: Appearance.sizes.cornerZone

    MouseArea {
        id: cornerTop

        hoverEnabled: true
        anchors.top: parent.top
        anchors.right: parent.right
        width: root.armLength
        height: root.edgeInset
    }

    MouseArea {
        id: cornerSide

        hoverEnabled: true
        anchors.top: parent.top
        anchors.right: parent.right
        width: root.edgeInset
        height: root.armLength
    }

    // HOW BIG THE THING YOU HAVE TO HIT IS, which is not how big the arms that
    // notice a cursor are.
    //
    // Same derivation and the same reasoning as modules/SettingsCorner.qml:46-52
    // (and LaunchEdge's `grab` before it): a target cannot be conditional on
    // having already been hit. The arms above are exactly the band's thickness,
    // ten pixels or so, which is plenty for a cursor thrown at a corner that
    // cannot be overshot and useless for a fingertip, which has no edges to
    // catch it and no hover to swell anything first. So the press gets a patch
    // of its own: the band plus its padding, never under the minimum size
    // anything in this shell is allowed to be.
    readonly property real grab: Math.max(root.edgeInset + Appearance.padding.normal, Appearance.sizes.minTarget)

    // The same corner, taken as a gesture. PRESS only; the arms above keep the
    // hover.
    Pull {
        id: corner

        // Top-right: the inward diagonal, written as a vector, so left and
        // down. The only two numbers here that say which way the gesture runs,
        // so moving the tray to another corner is these two and the anchors, and
        // nothing else.
        dirX: -1
        dirY: 1

        // A SUMMONING pull, measured against the screen's own diagonal, so it is
        // a proportion of the surface it is dragged across rather than a pixel
        // count that means one thing on a laptop panel and another on a desk
        // monitor. The tray itself is no use as a scale here: at the moment the
        // gesture starts it is either not there at all or is showing whatever
        // happened to arrive, so its height is not a fact about the gesture.
        travel: Math.hypot(root.width, root.height) * Appearance.sizes.pullTravel

        anchors.top: parent.top
        anchors.right: parent.right
        width: root.grab
        height: root.grab

        // ABOVE THE PUSH ZONE, and this is the one place in the file where
        // declaration order is not enough to say what should win.
        //
        // The tray begins an `inset` down from the top, which is twenty pixels,
        // and this square is `grab`, which is twenty-four. So the last four
        // pixels of the corner overlap the tray's rectangle, and the push zone
        // wears that rectangle. Declared later, the push would take those four
        // pixels, and it has no `onTapped`, so a tap landing in them would do
        // nothing at all: the corner would be a twenty-four pixel target that
        // answers over twenty of its height, which is under the minimum this
        // shell holds everything else to.
        //
        // Raising this instead of reordering the two, because the push must stay
        // below the tray's own contents and the corner must stay above the push,
        // and those two facts do not fit in one ordering of three siblings. The
        // four pixels cost the push nothing: they are the extreme corner of the
        // tray's padding, which is the last place a hand would start a shove
        // from, and the corner tap is the thing that has to be reliable there.
        z: 1

        // NO hoverEnabled here, deliberately, and it must stay that way. Qt hands
        // hover to the topmost item that accepts it and gives none to anything
        // underneath, so a hover-enabled square sitting over the two arms would
        // take their hover away and the tray would stop opening for a cursor
        // that arrived at the corner: exactly the bug this file already records
        // twice, once for `trayHover` below and once on the notification card.
        // With hover off this is invisible to hover and the arms underneath go on
        // getting it, which is the whole arrangement: the arms notice, this one
        // is pressed.

        // THE FRACTION IS DROPPED ON PURPOSE, and this is not a dangling
        // argument. Everything else in this shell that gets pulled has a travel
        // to track the pointer along, a panel's height or a rail's length, so it
        // can show you how far you have got and let you decide from the picture.
        // The tray has no such dimension: its height is whatever its contents
        // are, and a tray drawn one third open is not a smaller tray, it is a
        // clipped one. So the pull's whole job is to say "open" the moment it is
        // recognised as a pull, and the reversal is the entirety of the feedback:
        // you are looking at the tray, and pushing back into the corner puts it
        // away again.
        onPulled: root.pulling = true

        // Let go. `open` false clears `pinned` even when something earlier had
        // set it, which is right rather than an oversight: reversing a pull back
        // into the corner is the same gesture as shoving the tray into it, so it
        // has to close a tray that a previous pull left pinned.
        onFinished: open => {
            root.pulling = false;
            root.pinned = open;
        }

        // The other half of the touch story. A touchscreen has no hover at all,
        // so without a tap the corner arms above are unreachable and the tray
        // could only ever be opened by a swipe, which is a lot to ask of someone
        // who does not know the swipe is there. A tap opens it and it stays; a
        // second tap puts it away.
        //
        // It is no longer the ONLY way to close a pulled tray, and it should not
        // have been: it used to mean that putting the tray away meant finding a
        // twenty-four pixel invisible square in the screen's corner again, from
        // wherever in the list your hand had got to. The tray now takes the same
        // reversal on its own body (see `push` below), and this stays for the
        // pointer, which is the input the corner was always the cheapest target
        // for.
        //
        // onTapped and never onClicked: Pull holds the press for the gesture, so
        // a click that turned out to be the end of a swipe is not a click and
        // must not read as one.
        onTapped: root.pinned = !root.pinned
    }

    // THE WAY BACK: the corner's pull, pointed the other way, and made from
    // wherever on the tray your hand has already got to.
    //
    // A SIBLING of the tray wearing the tray's rectangle, and NOT a child of it,
    // which is a correctness requirement rather than a matter of taste. Pull
    // keeps its press anchor as `root.x + mouse.x`, and that is invariant while
    // the PULL moves inside a parent that does not: the item's x rises by d, the
    // pointer's position within it falls by d, and the sum stays put. It does not
    // survive the PARENT moving, and moving the tray is this gesture's entire
    // job. Inside the tray it would have been measuring itself against its own
    // effect: every frame the tray slid away it would take that distance back off
    // the delta, so a finger travelling steadily would report the remainder
    // rather than the travel, and the push would dissolve into noise. Out here
    // the parent is the screen-filling root, which never moves, and the bindings
    // below hand it the tray's rectangle anyway, so the zone still slides away
    // with the tray: exactly the case the invariant was written for.
    //
    // DECLARED BEFORE THE TRAY, which is what keeps it out of everything else's
    // way. Declaration order is input order, so the cards, the scroll and the
    // Clear pill are all above this and take their own presses first, and what is
    // left for the push is the tray's padding ring plus the empty parts of the
    // header row while the list is short enough that the Flickable is not
    // interactive and lets presses through. That is the same arrangement `z: -1`
    // buys the notification card's drag area inside its own card, and the z is
    // not needed once the order says it.
    Pull {
        id: push

        // The tray's rectangle, followed rather than shared. It has to move with
        // the tray while the tray is being pushed, or the last part of the push
        // would be made on a zone the tray had already left.
        x: tray.x
        y: tray.y
        width: tray.width
        height: tray.height

        // ONLY WHILE THERE IS A TRAY. `tray.visible` is `root.any`, which is
        // false whenever the tray is empty and unsummoned, and a gesture zone
        // that outlived the thing it pushes would be a patch of screen that
        // swallows presses and answers with nothing. It cannot go false during a
        // push made on a pinned tray, because `pinned` holds `expanded` and
        // `expanded` holds `any` until the release clears it; it CAN go false
        // mid-push on a tray that only hover was holding open, and the right
        // answer there is the one this gives: the item goes invisible, Qt takes
        // the grab away, and Pull's own `onCanceled` ends the gesture as a
        // reversal rather than leaving it half made.
        visible: tray.visible

        // Up and to the right: the corner pull's `(-1, 1)` negated, which is the
        // whole of what "the same gesture, reversed" means once the direction is
        // a vector rather than a corner the component was told to sit in. Move
        // the tray to another corner and these two numbers and the corner's two
        // are the entire change.
        dirX: 1
        dirY: -1

        // A PUTTING-AWAY pull, so it measures against the thing being pushed
        // rather than against the screen: the tray is right there under the hand
        // and the point of the drag is that it tracks it. Pull's own `travel`
        // note has the two cases; this is the second one.
        //
        // THE SETTLED RECTANGLE, never a live one. A travel computed from
        // something the gesture is itself collapsing or moving shrinks as the
        // gesture proceeds, which makes the fraction accelerate and the panel run
        // away from the hand. So the width is asked of `panelWidth`, which is
        // where the tray's width comes from in the first place, rather than of
        // the item this push is busy shoving; the two are the same number today
        // and only one of them is guaranteed to stay that way. The height is the
        // tray's own, because nothing here touches it: a tray holding two
        // notifications is a shorter push than one holding ten, which is right,
        // since it is a smaller thing to shove.
        travel: Math.hypot(root.panelWidth, tray.height)

        // The default `angle` is the corner tolerance and that is the correct one
        // here, because what this is aimed at IS a corner: there are ninety
        // degrees of "off the screen" to divide up, and thirty either side of the
        // diagonal still leaves the ends of the arc to the gestures that run
        // ALONG an edge. The edge figure would swallow a swipe that was really
        // running up the right-hand side.

        // NO hoverEnabled, for the reason this file has already recorded twice. A
        // hoverEnabled MouseArea is the topmost thing that gets hover and
        // everything under it gets none, and `trayHover` is one of the four
        // things holding this tray open: a hover-enabled zone the size of the
        // tray would close the tray it is sitting on the moment a cursor arrived.

        onPulled: fraction => root.pushBack = fraction

        onFinished: open => {
            // Hand the offset to the spring whichever way it ended. A reversed
            // push has to walk back out to where it came from, and a committed
            // one has to be home before the tray is next shown, or the next
            // notification would arrive in a tray that was already halfway into
            // the corner.
            shove.value = root.pushBack;
            shove.target = 0;

            // ONE claim dropped, not an order to close. `expanded` is a union of
            // four things and this is one of them, so clearing it says "the pull
            // no longer holds this open" and leaves the other three to answer for
            // themselves. With a cursor still resting on the tray it stays up on
            // `hovering` and then on the grace timer, which is right: the pointer
            // is sitting in the middle of the thing it just pushed and has not
            // left yet. With a finger there is no hover to hold anything, so it
            // goes at once, which is also right: a hand that pushed it away has
            // said everything it is going to say. Writing `expanded` here instead
            // would be the argument that union exists to end.
            if (open)
                root.pinned = false;
        }

        // NO onTapped, deliberately. A tap on the tray's padding is the miss you
        // make reaching for a card, and answering it by closing the tray would
        // take the list away at the exact moment you were trying to touch it.
        // Tapping to close belongs to the corner, because tapping to open does.
    }

    // Walks the push home when the gesture ends, whichever way it ended.
    //
    // Gated on the gesture, exactly like the notification card's `settle`: while
    // a finger is down the tray's position is the FINGER'S, and a smoother
    // chasing the same value would be a second thing writing it. The epsilon is
    // the reveal one rather than the default, because this is a 0 to 1 fraction
    // and not a pixel count: a quarter of a pixel is nothing and a quarter of
    // this is a tray that stops a quarter of the way into the corner and stays
    // there.
    Follow {
        id: shove

        speed: Appearance.anim.revealSpeed
        epsilon: 0.005
        target: 0
        onValueChanged: if (!push.pulling)
            root.pushBack = value
    }

    Item {
        id: tray

        // Flush with the SCREEN edge, not with the band's inner edge. The tray
        // and the band are one body; held off the edge it would join the shell
        // through a neck instead of simply being part of it.
        //
        // ...and then however far it has been pushed back into the corner, which
        // is the one thing allowed to move it off that edge. A full push is
        // exactly one panel width, so the tray that has been pushed all the way
        // is entirely gone rather than merely mostly gone, and the fade below
        // reaches nothing at the same moment for the same reason.
        x: root.width - root.panelWidth * (1 - root.pushBack)
        y: root.inset
        width: root.panelWidth

        // Everything in it, together, so the push takes the tray away as one
        // object. It is on the container rather than on the Flickable because the
        // padding ring is part of the tray too, and a card sliding out of a frame
        // that stayed behind would read as the cards leaving rather than the tray.
        opacity: 1 - root.pushBack

        // Nothing tall, when there is nothing in it. The padding used to be
        // added unconditionally, so an empty tray was still two padding tiers
        // high and the tongue POPPED that far out of the band before the first
        // row had drawn a pixel. Growing from zero is what makes the arrival the
        // band swelling rather than a box appearing and then filling up.
        readonly property real contentHeight: Math.min(list.height, root.height - root.inset * 2)

        height: contentHeight > 0 ? contentHeight + Appearance.padding.normal * 2 : 0
        visible: root.any

        // PUSHED, all three of them, and the x one is new with the push. The
        // chassis blob is built from this item's rectangle, so a tray that slides
        // toward the corner without saying so would leave the tongue it is melted
        // into standing where the tray used to be: the shell would hold the shape
        // of a tray that is halfway off the screen. It is wired the same way as
        // the other two and for the reason `blobs` records: a BINDING here reads
        // the geometry it is rebuilt by and re-evaluates it, which emits the
        // change that invalidates the list while it is being computed.
        // Qt.callLater coalesces, so a frame of the push that moves x and nothing
        // else costs one rebuild.
        onXChanged: Qt.callLater(root.sync)
        onYChanged: Qt.callLater(root.sync)
        onHeightChanged: Qt.callLater(root.sync)

        // A HANDLER, not a MouseArea. A hoverEnabled MouseArea is the topmost
        // thing that gets hover and everything under it gets none, so the moment
        // the cursor reached a row the tray stopped being hovered, decided the
        // cursor had left, and closed itself: the list vanished the instant you
        // tried to touch it. A HoverHandler is passive and stays hovered while
        // its own descendants are.
        HoverHandler {
            id: trayHover
        }

        // Scrolls only when it has to. A tray shorter than the screen is a
        // panel; one that always scrolls is a document.
        Flickable {
            id: view

            x: Appearance.padding.normal
            y: Appearance.padding.normal
            width: tray.width - Appearance.padding.normal * 2
            height: Math.max(0, tray.height - Appearance.padding.normal * 2)

            contentHeight: list.height
            interactive: contentHeight > height
            clip: interactive
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: list

                width: view.width
                spacing: Appearance.padding.normal

                // The header only exists while the tray is a list rather than a
                // couple of arrivals, and it collapses the same way a row does
                // so the tray never jumps when it appears.
                Item {
                    id: headerSlot

                    readonly property real open: reveal.value

                    width: parent.width
                    height: header.implicitHeight * open
                    clip: true
                    visible: open > 0

                    Follow {
                        id: reveal

                        speed: Appearance.anim.revealSpeed
                        epsilon: 0.005
                        target: root.expanded ? 1 : 0
                    }

                    // ANCHORED, not a Row. In a Row the title had to subtract the
                    // pill's width and the spacing by hand, which is only right
                    // while the pill is there: with nothing unread it was still
                    // reserving room for a button that had gone.
                    Item {
                        id: header

                        width: parent.width
                        implicitHeight: Math.max(title.implicitHeight, clearAll.implicitHeight)

                        StyledText {
                            id: title

                            anchors.left: parent.left
                            anchors.right: clearAll.visible ? clearAll.left : parent.right
                            anchors.rightMargin: Appearance.padding.normal
                            anchors.verticalCenter: parent.verticalCenter

                            text: Notifs.count > 0 ? `${Notifs.count} unread` : "Nothing unread"
                            font.pixelSize: Appearance.font.size.small
                            color: Appearance.colour.textFaint
                            elide: Text.ElideRight
                        }

                        Pill {
                            id: clearAll

                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter

                            visible: Notifs.count > 0
                            text: "Clear"

                            onClicked: Notifs.clear()
                        }
                    }
                }

                Repeater {
                    // A ScriptModel, NOT the array itself. A Repeater over a
                    // plain JS array has no idea what changed, so every
                    // assignment tears down every delegate and builds it again:
                    // dismissing one notification re-created all of them, which
                    // restarted their animations and dropped their state. This
                    // diffs the array into inserts and removes, so the rows that
                    // did not change are never touched.
                    model: ScriptModel {
                        values: root.items
                    }

                    delegate: NotificationCard {
                        required property var modelData

                        entry: modelData
                        fullWidth: list.width
                        // Asked for, and nothing in here expires while it is
                        // open, so this is the half of the tray with time to
                        // read in. See NotificationCard's `roomy`.
                        roomy: root.expanded
                        onDismissed: Notifs.dismiss(modelData)
                    }
                }
            }
        }
    }

    // THE KEYBOARD, on an item of its own rather than on the tray, and last in
    // the file rather than beside the property that asks for it.
    //
    // ON ITS OWN because the tray is `visible: root.any`, which is false for
    // exactly the case that matters least and the case that matters most: an
    // empty unsummoned tray, and every frame between one closing and the next
    // arriving. An invisible item cannot hold focus, so a key handler on the tray
    // would go deaf at the moments it is most obviously wrong to. SessionMenu
    // learned this first and the settings page repeats it. This one has no size
    // and is never hidden, so it is always focusable.
    //
    // LAST because everything above it sits somewhere deliberate in this file's
    // input order (the corner over the push, the push under the cards) and this
    // sits nowhere in it: no geometry, no drawing, no mouse buttons. Declared
    // among them it would have been one more thing to reason about in an ordering
    // three comments already justify.
    Item {
        id: keys

        Keys.onPressed: event => {
            // ONE claim dropped, not an order to close, which is the same thing
            // the corner's tap and the push-back's release both say (see both).
            // `expanded` is a union and this is one term of it: with a cursor
            // still resting in the tray it stays up on `hovering`, and that is
            // right rather than a miss, because the pointer has not gone
            // anywhere and the tray will follow it out. Writing `expanded` here
            // would be the argument that union exists to end.
            if (event.key === Qt.Key_Escape) {
                root.pinned = false;
                event.accepted = true;
            }
        }
    }
}
