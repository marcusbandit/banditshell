pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// The shell's half of the settings page: the card, while the shell is the one
// drawing it.
//
// It lives in ShellWindow like every other summoned panel, and it is the only
// one that can stop being drawn without being closed. `Settings.floating` going
// true does not mean the page went away; it means a window took it, and this
// stops drawing so there are not two of the same card on the screen.
//
// WHERE IT BELONGS is the middle of the content area, not the middle of the
// screen. The chassis's hole is off-centre by the width of the sidebar, and a
// page centred on the screen would sit visibly to the right of the space it is
// actually in.
//
// HOW IT GETS THERE has two answers, and that is the whole file:
//
//   opened          it is already home. Nothing to travel from, so it appears
//                   there and fades up.
//   handed back     it appears exactly where the window was standing, holds
//                   still long enough to have been seen there, and then flies
//                   home. The holding is what makes it the same object: a card
//                   that started moving on the same frame it appeared would read
//                   as a new card that happened to start near the window.
Item {
    id: root

    required property ShellScreen screen

    // The content area, from the chassis. Not the screen: see above.
    required property real holeX
    required property real holeY
    required property real holeWidth
    required property real holeHeight

    // The page is open AND it is this screen's to draw.
    readonly property bool mine: Settings.open && Settings.screenName === root.screen.name

    // ...and the shell, rather than a window, is currently holding it.
    readonly property bool docked: root.mine && !Settings.floating

    readonly property real homeWidth: Settings.homeWidth
    readonly property real homeHeight: Settings.homeHeight
    readonly property real homeX: root.holeX + (root.holeWidth - root.homeWidth) / 2
    readonly property real homeY: root.holeY + (root.holeHeight - root.homeHeight) / 2

    // WHILE THIS IS SET the card stands still, wherever the window it is taking
    // over from was standing. Settings clears it once both surfaces have had a
    // frame drawing the same thing, and the flight home starts from that.
    readonly property var held: Settings.handoff

    // WHERE THE PAGE COMES OUT OF: the content area's bottom-right corner, which
    // is the corner the nook that opens it lives in (modules/SettingsCorner.qml).
    //
    // A page that fades up in the middle of the screen has no relationship to
    // the thing you pressed to get it. This one grows out of exactly the point
    // the cursor is resting on, so the corner and the page are one object seen
    // twice rather than a button and an unrelated card.
    readonly property real cornerX: root.holeX + root.holeWidth
    readonly property real cornerY: root.holeY + root.holeHeight

    // BEING PULLED OUT OF THAT CORNER BY HAND, and how far.
    //
    // The third state, and the reason the page needed one. `docked` or not was
    // enough while the only ways in were a click and the CLI, both of which are
    // instants: the page was either travelling or it was not. A pull is neither.
    // While it is happening the page's depth is the POINTER'S rather than the
    // reveal animation's, because a card that lagged the hand by a smoother's
    // worth of easing would be a switch with a picture of a drag on it, and the
    // whole value of the gesture is that you can see how much you have pulled out
    // and change your mind. The animation takes over at the moment of release,
    // from wherever the drag left it.
    property bool pulling: false
    property real pullProgress: 0

    // HOW MUCH OF THAT GROWTH HAS HAPPENED, which is the reveal EXCEPT when a
    // window is involved, or a hand is.
    //
    // Both handovers are the same object changing hands in place, and a card
    // that flew off to the corner while the window took over from it, or grew
    // out of the corner instead of standing where the window was, would be
    // saying the opposite of what the handover means. Pinned to 1 for the whole
    // of both, so the fade is all that is left of the transition.
    //
    // A pull outranks the reveal for the opposite reason: there the point is
    // that the card is exactly as far out as the gesture has pushed it, so the
    // smoother has to be out of the loop entirely rather than chasing the
    // finger. `reveal` is left alone underneath, still resting at its target,
    // which is what lets the release hand over in a single assignment instead of
    // starting a second animation.
    readonly property real emerge: root.held || Settings.windowOpen ? 1 : root.pulling ? root.pullProgress : reveal.value

    // THE CARD, and nothing else. Not the whole screen.
    //
    // Every other summoned thing in this shell masks the lot while it is up, so
    // that a click anywhere off it puts it away. That is right for a menu, a
    // launcher and a power panel, which are all things you are in the middle of
    // doing. It is wrong for this one: a settings page is a thing you leave open
    // while you go and look at what you changed, and a page that dies the moment
    // you touch your terminal cannot be left open at all.
    //
    // So the desktop stays live around it, which is also why the shell asks for
    // the keyboard on demand rather than exclusively while it is docked (see
    // ShellWindow). Escape closes it once it has been clicked; the CLI closes it
    // from anywhere.
    readonly property Item maskItem: card

    function hide(): void {
        Settings.hide();
    }

    // WHETHER THE PRESS UNDER WAY BEGAN ON THE GRIP, decided at the moment it
    // began and then simply remembered.
    //
    // The Pull's `fromX`/`fromY` survive until the next press and are the right
    // ORIGIN to judge (see the Pull's `onTapped` for why the origin and not the
    // release point), but a point is only half of a hit test: the other half is
    // where the grip was when the finger touched it, and the grip is on a card
    // that is very often moving. `emerge` is mid-flight for the whole of the
    // opening and closing animation, the fx/fy Follows are mid-flight for the
    // whole of a flight home from a window, and `armed: root.docked` excludes
    // none of that, so a press is perfectly free to land while the grip is
    // travelling. Resolving the stored point at RELEASE asked the geometry
    // where it is NOW: release a shove at sixty per cent, tap a quiet part of
    // the page while it finishes opening, and the grip can arrive under the
    // recorded point in time to close a page you tapped the surface of, which
    // is exactly the trap the Pull's comment says this must not be. The inverse
    // is the same bug being polite: a real tap on the grip of a card flying
    // home maps outside it, and the close does nothing.
    //
    // So the answer is taken while the two halves are contemporaneous, and the
    // release only reads it back.
    property bool pressedGrip: false

    // Whether a point, in THIS item's coordinates, lands on the face's corner
    // grip. The Pull records its press origin in its parent's frame, and its
    // parent is this item (that siblinghood is load-bearing, see the Pull
    // below), so the origin can be handed straight in here. Mapped INTO the
    // grip rather than the grip's rect mapped out, because mapFromItem walks
    // the whole ancestor chain and therefore survives the card's scale
    // transform; restating the grip's position arithmetic on this side would
    // be a second copy of geometry SettingsFace already owns, wrong the first
    // time the grip moved.
    //
    // ANSWERED WHEN THE PRESS LANDS, NEVER WHEN IT LIFTS, which is the point of
    // `pressedGrip` below and the one thing about this function that is not
    // obvious. Walking the ancestor chain is what makes the scale transform
    // survivable, and it is also what makes the answer a fact about WHEN it was
    // asked: the chain it walks is the card's live one, and the card's rect and
    // scale are driven by `emerge` and by the fx/fy Follows, all of which move.
    // Asked at release about a point recorded at press, it would be hit-testing
    // this instant's grip against the last instant's finger.
    function pressOnGrip(x: real, y: real): bool {
        const grip = face.gripItem;
        if (!grip || !grip.visible)
            return false;
        return grip.contains(grip.mapFromItem(root, x, y));
    }

    // Hand the page to a window, at exactly the rect the card occupies THIS
    // frame rather than the one it rests at. Pulling it out mid-flight is a
    // perfectly reasonable thing to do, and the window should still land on it.
    function popOut(): void {
        Settings.popOut(root.screen, fx.value, fy.value, fw.value, fh.value);
    }

    function dragTo(fraction: real): void {
        // Nothing to pull out of the corner that is not already out. The corner
        // stays live while the page is open because a tap on it still closes the
        // page, so it is here rather than at the call site that the pull is the
        // part that stops applying.
        //
        // `Settings.open` rather than this panel's own `docked`, and the wider
        // test is the right one. There is ONE page, not one per monitor, so a
        // pull on a screen that is not currently holding it would otherwise play
        // the whole gesture out and then fade back to nothing on release, when
        // `show` declined to open a page that was already open somewhere else.
        // The same goes for a page that a window is holding: it is open, it is
        // just not here, and dragging a second copy of it out of a corner is not
        // a thing this page can do. A gesture that cannot commit should refuse
        // at the start rather than mislead for its whole length.
        if (Settings.open)
            return;
        root.pulling = true;
        root.pullProgress = Math.max(0, Math.min(fraction, 1));
    }

    function dragEnd(open: bool): void {
        // Guarded, because a release always arrives and a pull does not always
        // precede it: the corner reports the end of every gesture it recognised,
        // including ones this page ignored above because it was already open.
        if (!root.pulling)
            return;
        root.pulling = false;
        // Hand the smoother the depth the drag ended at, so the page carries on
        // from there rather than snapping back to the corner to start the
        // journey again. Let go short of it and `reveal`'s target is still 0, so
        // the same assignment is what walks it home.
        reveal.value = root.pullProgress;
        root.pullProgress = 0;
        // BY NAME, and this screen's: the corner that was pulled is on a
        // particular monitor, and a page that opened on whichever one happens to
        // hold the focused window would arrive somewhere you are not looking.
        // `show` refuses to do anything while the page is already open, so a
        // release that lands after something else opened it mid-gesture is
        // harmless rather than a second opening.
        if (open)
            Settings.show(root.screen.name);
    }

    function pushTo(fraction: real): void {
        // Only while this panel is the one actually drawing the page. `docked`
        // rather than dragTo's `Settings.open`, and the two guards are the same
        // question asked from opposite ends: a pull may not run while the page
        // is open ANYWHERE, and a push may only run while the page is open
        // HERE. A window holding it has the compositor's own frame to be closed
        // by, and a push on a card this panel is not drawing is a push on
        // nothing, which would play the whole gesture out and then find there
        // was never anything to put away.
        if (!root.docked)
            return;
        root.pulling = true;
        // THE ONE SUBTRACTION, and the only place either direction has to know
        // about the other. The gesture reports how far AWAY the page has been
        // pushed; `pullProgress` has always meant how far OUT it is. Flipping it
        // here rather than anywhere downstream is what lets `emerge`, the card's
        // offset, its scale and its opacity go on meaning exactly what they
        // meant when the only gesture was the one that opened it.
        root.pullProgress = 1 - Math.max(0, Math.min(fraction, 1));
    }

    function pushEnd(gone: bool): void {
        // Guarded for dragEnd's reason: a release always arrives and a push does
        // not always precede it, because the guard above turns some presses into
        // gestures this panel never took part in.
        if (!root.pulling)
            return;
        root.pulling = false;
        // The same handover dragEnd makes, and it reads the same way pointed
        // either direction: give the smoother the depth the gesture ended at, so
        // the page carries on from where the hand left it instead of jumping.
        // Committed, and `hide` below drops the target to 0, so this finishes
        // the journey the push started. Let go short of it and the page is still
        // docked, so the target is still 1 and the very same assignment is what
        // walks it back home.
        reveal.value = root.pullProgress;
        root.pullProgress = 0;
        if (gone)
            Settings.hide();
    }

    Follow {
        id: fx

        target: root.held ? root.held.x : root.homeX
        speed: Appearance.anim.resizeSpeed
        epsilon: 0.5
    }

    Follow {
        id: fy

        target: root.held ? root.held.y : root.homeY
        speed: Appearance.anim.resizeSpeed
        epsilon: 0.5
    }

    Follow {
        id: fw

        target: root.held ? root.held.w : root.homeWidth
        speed: Appearance.anim.resizeSpeed
        epsilon: 0.5
    }

    Follow {
        id: fh

        target: root.held ? root.held.h : root.homeHeight
        speed: Appearance.anim.resizeSpeed
        epsilon: 0.5
    }

    Follow {
        id: reveal

        target: root.docked ? 1 : 0
        speed: Appearance.anim.revealSpeed
        epsilon: 0.005
    }

    onDockedChanged: {
        if (!root.docked) {
            // AND HANDED BACK, which is the half with nothing on screen to
            // remind anybody it was missing. Focus is not the keyboard here
            // (see `keys` below), so a stale focus costs nothing while this
            // window is asking the compositor for nothing; the trouble is that
            // the window is SHARED. A pinned tray or notch asks for the
            // keyboard exclusively (ShellWindow's keyboardFocus says why), and
            // the key those pins exist to answer would then be delivered to a
            // closed page's item, accepted there, and spent on a Settings.hide
            // that early-returns: an Escape that cannot put away the thing it
            // was aimed at, and an exclusive grab with nothing left able to
            // release it. Every other focus-taking panel in this shell performs
            // the same handover (Menus, NotificationTray, TopNotch, SessionMenu,
            // CheatSheet, both launchers) and for the milder version of exactly
            // this reason.
            keys.focus = false;
            return;
        }

        // Placed, never travelled to. Both ways in have a place the card is
        // supposed to already be: home when it is opened, and the window's own
        // rect when it is handed back. Chasing either from wherever the card
        // last happened to be would animate from a position with no meaning.
        fx.snap();
        fy.snap();
        fw.snap();
        fh.snap();

        if (root.held) {
            // Taking over from a window, which is already at full weight. There
            // is nothing to fade in FROM; a fade here would be the page blinking
            // at the exact moment it is meant to be one continuous object.
            reveal.snap();
        }

        // DEFERRED, like every other panel here: the surface only asks the
        // compositor for the keyboard once `docked` has propagated, and forcing
        // focus before that gets a focused item that receives nothing.
        Qt.callLater(keys.forceActiveFocus);
    }

    // The keyboard, on an item of its own rather than on the card: the card is
    // invisible until the reveal has moved off zero, and an invisible item cannot
    // hold focus. See SessionMenu, which learned this the same way.
    //
    // AND IT IS ONLY HALF OF WHAT ESCAPE NEEDS, which is worth writing down here
    // rather than being re-derived by the next person who tries it. Focus inside
    // the window is not the keyboard: the surface is granted the keyboard ON
    // DEMAND while the page is docked (ShellWindow's keyboardFocus says why, at
    // length), and on demand means the compositor hands it over when the surface
    // is CLICKED. Until something on the shell has been clicked, no key event
    // reaches this window at all and this item, focused or not, hears nothing.
    // So Escape closes the page from the moment the page, the band, a gauge or
    // any other part of the shell has been touched, and not before.
    //
    // The two ways to close that gap were both measured against the paragraph
    // this file opens with, and both were rejected:
    //
    //   ASK EXCLUSIVELY while docked. That is what every other summoned panel
    //   does, and it is exactly what a settings page must not do: the page is a
    //   thing you leave open while you go and look at what you changed, and an
    //   exclusive grab means you cannot type into the thing you opened it to
    //   change. It would trade a keypress for the page's whole reason to be
    //   dismissable by click-through in the first place.
    //
    //   ASK ON DEMAND ALWAYS, so the click that opens the page is itself the
    //   click that hands the surface the keyboard. The corner tap lands while
    //   the surface is still asking for nothing, so it cannot be the one; making
    //   the shell ask unconditionally would mean every press on a gauge, a
    //   workspace pip or the bare band took the keyboard off the focused window,
    //   which is a far larger surprise than the one being fixed, and it would
    //   break for the CLI and keybind routes anyway, since neither clicks
    //   anything.
    //
    // What is left is honest: the page answers Escape the moment the keyboard
    // can reach it, and the CLI closes it from anywhere.
    Item {
        id: keys

        // GATED ON `docked`, which is not the same guard as the release above
        // and does not make it redundant. The release moves the focus; this
        // decides what this item is entitled to answer while it still has it,
        // which covers the frame the release has not propagated through yet and,
        // more than that, covers the state the release cannot reach at all: the
        // page pulled out into a WINDOW. There `docked` is false while the page
        // is very much open, the window draws the card and answers for it, and
        // an ungated handler here would spend an Escape aimed at whatever else
        // is pinned on closing the user's settings window instead.
        Keys.onPressed: event => {
            if (root.docked && event.key === Qt.Key_Escape) {
                root.hide();
                event.accepted = true;
            }
        }
    }

    // PUSHED BACK INTO THE CORNER IT CAME OUT OF, which is not a second gesture
    // to learn: it is the one that opened the page, with its direction turned
    // round (DESIGN.md 15). Everything in this shell goes back into the edge or
    // corner it came out of, by the gesture that brought it out, reversed.
    //
    // WITHOUT IT the page had four ways to close and exactly one of them could
    // be reached without a keyboard: a tap on a 24 by 24 invisible square in the
    // OPPOSITE corner of the screen from the card, which nothing on the page
    // mentions and nothing about the card points at. The obvious alternative is
    // a close button, and that is precisely the small permanent control this
    // shell is built not to have (DESIGN.md 2.1). A panel you can push needs
    // nothing drawn on it, and the answer to "how do I get rid of this" is then
    // the same answer everywhere. SettingsFace draws a corner grip so the page
    // says which way it goes; that mark takes no clicks, because this does.
    //
    // A SIBLING OF THE CARD RATHER THAN A CHILD OF IT, wearing the card's own
    // rect, and that is load-bearing rather than tidiness waiting to be undone.
    // Pull keeps its press anchor as `root.x + mouse.x`, which is exactly the
    // invariant for an area that MOVES OR RESIZES INSIDE A STATIONARY PARENT,
    // and is no invariant at all when the parent is the thing that moves. The
    // card is the worst possible parent here: its x, its y and its scale are all
    // bound to `emerge`, and `emerge` is what this gesture drives. Inside it a
    // finger that had not moved would still read as having moved, by however far
    // the card had just gone and by however much it had just shrunk, so the push
    // would be measuring its own output and the corner would crawl away from the
    // pointer instead of following it. Out here the parent is `root`, which
    // never moves and never scales, so the delta is the pointer's and nothing
    // else's. Folding this back into the card would read as a simplification and
    // would quietly break the gesture.
    //
    // BEFORE the card, because declaration order is input order. Everything the
    // page draws sits on top of this, so SettingsFace's pop-out button keeps the
    // clicks that belong to it and only the page's empty parts, which take no
    // mouse at all, fall through to here. That is what a `z: -1` inside the card
    // would have bought, and out here it comes free.
    //
    // AND `onTapped` ANSWERS EXACTLY ONE RECTANGLE. A tap on the page's own
    // surface still does nothing at all: there is no click-away dismissal here
    // (see `maskItem` above for why a settings page in particular has to
    // survive being clicked past), and a page that closed when you pressed the
    // space beside its own title would be that same trap drawn in a smaller
    // box. The one exception is the corner grip, because the grip is the mark
    // that already points at the close, and a mark you can see but not press
    // is a lie about half of itself (SettingsFace says the rest). The handler
    // lives HERE, on the Pull, rather than as a MouseArea on the grip, because
    // a press on the grip is ambiguous until it moves: it may be this tap or
    // the first inch of the shove, and only the Pull can tell a tap from a
    // pull from a spent press, that arbitration being the whole of what it is.
    // A MouseArea over the grip would win the press by stacking order and the
    // shove could never start from the one mark that draws its direction.
    Pull {
        id: shoveBack

        // THE CARD'S DRAWN RECT, which is not the card's `width` and `height`.
        // The card is SCALED about its bottom-right rather than resized (see
        // below), so what is actually on screen is its size times `emerge`, hung
        // off the corner it collapses toward. Taking the region from the
        // unscaled rect would leave a live patch of screen with nothing drawn in
        // it for the whole of the opening flight.
        //
        // These move while the gesture runs, and that is the case Pull's anchor
        // is built for: `x` rises by d, `mouse.x` falls by d, and the sum is the
        // pointer.
        x: card.x + card.width * (1 - root.emerge)
        y: card.y + card.height * (1 - root.emerge)
        width: card.width * root.emerge
        height: card.height * root.emerge

        // ARMED rather than enabled, which is Pull's own distinction and it
        // lands here for the mirror image of the reason it exists. Disabling a
        // MouseArea mid-gesture tears down the grab it is holding, and the
        // gesture that takes this page away is the very gesture that stops it
        // being docked: the release would be arriving at an item that had just
        // been switched off. Unarmed it rejects the press instead and the press
        // falls through, which is what should happen to a click on a page a
        // window is holding, or on one that is not this screen's to draw.
        armed: root.docked

        // Down and to the right, back toward the content area's bottom-right
        // corner, which is the point the card grew out of and the point it
        // collapses to. SettingsCorner's summoning pull is (-1, -1); this is
        // that vector negated, and that is the entire difference between the way
        // in and the way out.
        dirX: 1
        dirY: 1

        // The default `angle` stays, because it is the CORNER tolerance and the
        // target here is a corner. An edge's wider tolerance would be wrong
        // twice over: there are ninety degrees of "toward the corner" to divide
        // up rather than a hundred and eighty, and a push straight down or
        // straight right is a push at a screen edge rather than at the corner
        // the page belongs in.

        // HOW FAR A FULL PUSH IS: exactly how far the card's own bottom-right
        // corner travels between `emerge` 1 and `emerge` 0. It rests at
        // `homeX + homeWidth` by `homeY + homeHeight` and collapses onto
        // `cornerX` by `cornerY`, so the pointer and the corner cover the same
        // ground and the card's corner tracks the finger one for one.
        //
        // FROM THE RESTING GEOMETRY, not from the followed values the card is
        // actually drawn at, and the difference only shows when it matters. The
        // Follows are mid-flight exactly while the card is travelling home from
        // a window, and a `travel` read off them would be shrinking as the card
        // arrived: the scale of the gesture would depend on when in the flight
        // you grabbed it. Where the page RESTS is a fact about the page; where
        // it happens to be this frame is not.
        //
        // NOT the screen-diagonal figure the summoning pull uses, and the
        // difference is the whole reason Pull takes `travel` as an argument
        // rather than working it out. A gesture that SUMMONS has nothing on
        // screen to measure against: the page does not exist until the pull is
        // over, so a fraction of the surface is the only honest scale there is.
        // A gesture that PUTS SOMETHING AWAY has the thing right there under the
        // finger, so the honest scale is how far that thing has to go, and one
        // screen's worth of swipe would close a card that only needed half of
        // one.
        travel: Math.hypot(root.cornerX - root.homeX - root.homeWidth, root.cornerY - root.homeY - root.homeHeight)

        onPulled: fraction => root.pushTo(fraction)
        onFinished: gone => root.pushEnd(gone)

        // THE HIT TEST, TAKEN WHILE THE PRESS IS THE PRESENT TENSE. See
        // `pressedGrip` for why the answer cannot wait for the release.
        //
        // The point is assembled here rather than read off `fromX`/`fromY`,
        // and it is the same sum: the Pull's press handler stores
        // `x + mouse.x` for the reason it explains, and `x + mouseX` is that
        // expression evaluated from the outside. Taking it here removes the
        // question of whether the Pull's own `onPressed` has run yet, because
        // MouseArea cannot report itself pressed before it has stored the
        // position that pressed it: `mouseX` is defined exactly while a button
        // is down, so the instant this fires is the first instant it is valid.
        // The alternative, hooking the Pull's `onPressed` from out here, would
        // have been a second handler on a signal the component already handles
        // for its own gesture, which is a thing to reach for only when there is
        // nothing else that answers.
        //
        // Unarmed presses are rejected by the Pull and never become a tap, so
        // an answer recorded for one is simply overwritten by the next press
        // that counts.
        onPressedChanged: {
            if (shoveBack.pressed)
                root.pressedGrip = root.pressOnGrip(shoveBack.x + shoveBack.mouseX, shoveBack.y + shoveBack.mouseY);
        }

        // The press that stayed a tap and never set off the wrong way. Gated
        // to the grip by WHERE IT BEGAN, not where it ended: `pressedGrip` is
        // the answer about the Pull's own press origin, in this item's frame,
        // taken when that origin and the grip were the same age. Judging the
        // release point instead would let a press that wobbled off the grip
        // within the slack stop counting as the tap it plainly was. A press
        // that became a shove never reaches this signal, and a press that went
        // the wrong way is spent and reaches nothing, so the three outcomes
        // cannot shadow each other.
        onTapped: {
            if (root.pressedGrip)
                root.hide();
        }
    }

    Item {
        id: card

        // AT HOME, pulled back toward the corner by however much of the
        // emergence has not happened yet.
        //
        // The offset lands the card's own bottom-right corner exactly on the
        // content area's at emerge 0, which is the point the scale below
        // collapses it to. The two agree, so the page comes out of the corner as
        // ONE motion rather than as a slide and a shrink that happen to overlap.
        x: fx.value + (root.cornerX - fw.value - fx.value) * (1 - root.emerge)
        y: fy.value + (root.cornerY - fh.value - fy.value) * (1 - root.emerge)
        width: fw.value
        height: fh.value

        // Scaled rather than resized. The page is a page at every size it passes
        // through, so nothing inside it reflows on the way out of the corner:
        // a card whose width was animated would be re-wrapping its own text
        // through the whole flight, which reads as the page assembling itself
        // rather than as the page arriving.
        transformOrigin: Item.BottomRight
        scale: root.emerge

        // DRAWN WHILE PULLED, and not masked while pulled, and the second half
        // of that is deliberate rather than a thing that was missed.
        //
        // Both of these have to know about the gesture. `reveal` does not move
        // until the drag has ended, so asking it alone would leave the page
        // invisible for the whole of the pull and then have it appear, already at
        // whatever depth the gesture reached, on the release: the gesture would
        // show nothing at all until it was over, which is the one thing a drag is
        // supposed to fix about a click.
        //
        // The mask is handed out on `docked` (see ShellWindow), which is false
        // for the whole pull, so there is a card on screen that the compositor is
        // not routing clicks to. That is correct: the corner holds an implicit
        // grab on the pointer from press to release, so every event in the
        // gesture is already going to the corner, and nothing needs the card to
        // be interactive until it has actually been opened. `enabled: root.docked`
        // says the same thing from the other side and stays exactly as it is.
        visible: reveal.value > 0.001 || root.pulling
        enabled: root.docked
        opacity: root.pulling ? root.pullProgress : reveal.value

        SettingsFace {
            id: face

            anchors.fill: parent

            windowed: false

            // The grip's pressed feedback, computed on THIS side of the seam
            // because only this side can see the press: the Pull owns it (a
            // hover area's `containsMouse` freezes under somebody else's
            // grab, so the face cannot sense it honestly). Re-evaluated on
            // press and release, which are the only edges that matter; the
            // origin does not move during a drag, so a shove that began on
            // the grip keeps its ribs lit for the whole ride, which is the
            // right feedback for a hand that is using the mark as the handle
            // it draws itself as.
            gripHeld: shoveBack.pressed && root.pressOnGrip(shoveBack.fromX, shoveBack.fromY)
            onHandover: root.popOut()
        }
    }
}
