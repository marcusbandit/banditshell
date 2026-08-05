pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

// The menu layer: at most one menu open at a time, hanging off the sidebar.
//
// It owns three things the panel itself should not care about:
//
//   WHICH is open, so opening a second closes the first without a flicker. The
//   panel never unmounts between menus; it slides to the new anchor, travels to
//   the new content's height and cross-fades to it, which is why switching feels
//   like one object changing rather than two appearing.
//
//   WHERE it sits: the panel's centre follows the icon that asked for it, by
//   exponential smoothing, clamped so it never runs past the chassis.
//
//   WHETHER it stays: hover is a sloppy input, and a menu that lives only while
//   the cursor is exactly on its icon or exactly on its panel makes a minefield
//   of the band between them. It stays while the cursor is anywhere on the
//   SHELL, with a short grace timer over leaving even that, so the only two
//   things that close a menu are asking for a different one and going back to
//   your own windows.
//
// ALL THREE OF THOSE ARE ABOUT A CURSOR, and a finger has none of it.
//
// Hover answers "is the pointer still here", which is a continuous state, and a
// continuous state is a thing a menu can be held open BY. A tap is an instant:
// by the time the panel exists the gesture that asked for it is already over, so
// there is nothing left holding it. Both tests above are permanently false on a
// touchscreen (a HoverHandler answers hovering devices, and a finger is not
// one), which made every menu either die a fifth of a second after the finger
// lifted, or, in the other synthesis branch, live forever with nothing able to
// close it. Reaching for the menu meant lifting, and lifting was what killed it.
//
// So a menu that was asked for outright is PINNED, and the pin is a latch that
// hover has no opinion about. It goes on by a tap, by the CLI, or by the grace
// timer noticing that no pointer was ever involved; it comes off by hide()
// alone. That is the same shape the notification tray writes down at its own
// `pinned`, for the same reason, and it is the rule DESIGN.md 15 states for the
// whole shell: what hover opened, hover closes; what was asked for stays until
// it is put away, and putting it away is the gesture that brought it out,
// reversed.
Item {
    id: root

    // Where the chassis ends and the desktop begins. The panel starts exactly
    // here so the two never overlap.
    required property real originX
    // The band, so the panel cannot slide into the rounded screen corners.
    required property real inset

    readonly property bool open: currentKey !== ""

    // THE GHOST, not the panel. See `held` below: the shell's input region is
    // allowed to lag the panel shrinking, so that collapsing a layer under the
    // cursor does not pull the floor out from under it.
    readonly property Item maskItem: ghost

    // PINNED: this menu was asked for outright, so nothing that merely wandered
    // off gets to take it away. See the header for why an instant needs a latch
    // where a continuous state does not.
    //
    // The rejected alternative was to leave this file alone and simply not run
    // the grace timer for touch. Nothing here can tell a touchscreen from a
    // mouse that has not moved yet, and a timer that never fires is a menu that
    // can never be closed, which is the other half of the same bug.
    property bool pinned: false

    // Whether a POINTER has been on the shell at all since this menu opened.
    //
    // Recorded on the CHANGE rather than read once inside show(): a cursor that
    // lands straight on an icon from off the shell answers both questions in one
    // event, and Qt updates the deepest item that took the hover before it gets
    // to an ancestor's handler, so a read at show() time can miss a pointer that
    // is very much there. A flag set by the change cannot miss it: whichever
    // order the two arrive in, the change still arrives.
    property bool sawPointer: false

    // The whole screen off the menu, for the window's input region, and only
    // ever asked for while pinned. See the MouseArea itself for why it is
    // conditional and why it stops at the bar.
    readonly property Item catcher: offPanel

    // True while something in the open menu is waiting to be typed into, which
    // is the only reason a menu ever has to hold the keyboard. See ShellWindow's
    // keyboardFocus for why holding it the whole time a menu is up would be
    // worse than not holding it at all.
    //
    // Asked of Prompts rather than of the content, because the content is a
    // Component this file is handed and never looks inside; the field that wants
    // the keyboard says so directly. Still gated on `open`: a menu that is not
    // on screen cannot be the reason the shell is keeping the keyboard from the
    // desktop, whatever a stale claim says.
    readonly property bool needsKeyboard: root.open && Prompts.active

    // What the chassis needs to melt this panel into the shell's body. A closed
    // panel has zero width, which the field skips, so it costs nothing rather
    // than leaving a stub behind.
    readonly property var blobs: panel.width > 0 ? [
        {
            x: panel.x,
            y: panel.y,
            w: panel.width,
            h: panel.height,
            radius: panel.cornerRadius
        }
    ] : []

    // Where the caller asked for it, kept so the clamp can be RE-evaluated.
    property real requestedCentre: 0

    property string currentKey: ""
    property string currentTitle: ""
    // The component the open menu shows. Handed in by whoever knows what a menu
    // key means, so this file stays about position and lifetime.
    property Component currentBody: null

    // WHAT THE PANEL USED TO BE, kept for as long as the cursor is standing in
    // it.
    //
    // Closing a layer makes the panel shorter, and the panel is centred, so the
    // top edge comes DOWN to meet the new height. Press the chevron near the top
    // and the edge sweeps past the cursor: the panel is now somewhere below,
    // and the cursor is over bare desktop. The input region is the panel, so the
    // shell stopped being told about the cursor at all, `shellHovered` went
    // false on the next motion event, and the menu you had just finished using
    // closed itself. You collapsed a layer and lost the menu.
    //
    // So the region is the union of where the panel is and where it has been,
    // and it is only allowed to give the difference back when the cursor is not
    // standing in it. That is the whole rule. It cannot be "give it back once
    // the cursor is on the panel again", which is the obvious version and loses
    // the same race: the cursor IS on the panel for the first frames of the
    // shrink, so the ghost would follow the edge down and arrive nowhere.
    //
    // The cost is an invisible piece of shell that eats clicks, and it lasts
    // exactly as long as the cursor stays in it.
    property rect held: Qt.rect(0, 0, 0, 0)

    readonly property rect panelRect: Qt.rect(panel.x, panel.y, panel.width, panel.height)

    function syncGhost(): void {
        const r = root.panelRect;
        if (!ghostPointer.hovered) {
            root.held = r;
            return;
        }
        const x = Math.min(root.held.x, r.x);
        const y = Math.min(root.held.y, r.y);
        root.held = Qt.rect(x, y, Math.max(root.held.x + root.held.width, r.x + r.width) - x, Math.max(root.held.y + root.held.height, r.y + r.height) - y);
    }

    onPanelRectChanged: root.syncGhost()

    // The moment the cursor steps out, the loan is called in.
    Connections {
        target: ghostPointer

        function onHoveredChanged(): void {
            root.syncGhost();
        }
    }

    // True while the cursor is on the panel itself, which keeps it open. The
    // ghost counts: the space the panel just vacated is still the menu as far as
    // the person reaching across it is concerned.
    readonly property bool hovered: pointer.hovered || ghostPointer.hovered

    // True while the cursor is anywhere on the shell at all, which ALSO keeps it
    // open. Handed down rather than worked out here: the surface's input mask is
    // already the authority on where the shell is, and a second answer to the
    // same question is a second answer to get wrong.
    property bool shellHovered: false

    // Leaving the shell is the one gesture that means "I am done with this".
    // Everything else is somewhere on the way to somewhere.
    //
    // ARRIVING is worth recording as well, and it is recorded here rather than
    // asked for later: `sawPointer` is what separates a menu the pointer has
    // left from a menu the pointer was never on, and only the second one is
    // being closed for a reason that never happened.
    onShellHoveredChanged: {
        if (root.shellHovered) {
            root.sawPointer = true;
            return;
        }
        root.release();
    }

    function show(key: string, title: string, body: Component, centreY: real, pin: bool): void {
        // Asked BEFORE currentKey changes, and asked of the state rather than of
        // the animation's value: "is the reveal at zero" is a float test, and a
        // float test for closed is exactly the kind that works until it doesn't.
        const wasClosed = !root.open;

        // WHETHER THIS IS A DIFFERENT MENU, which is not the same question as
        // whether it is a different Component.
        //
        // The panel cross-fades when its `body` changes, and for the gauges that
        // is exact: one Component each, so a new menu is always a new component.
        // The tray is a list of the same kind of thing, so every item in it
        // shares ONE component and hands the panel a value instead; moving from
        // one tray icon to the next would then change nothing the panel watches,
        // and it would go on showing the previous item's name over the new
        // item's rows. The KEY changing is what means a different menu.
        const swapping = key !== root.currentKey;
        const sameBody = body === root.currentBody;

        grace.stop();
        root.currentKey = key;
        root.currentTitle = title;
        root.currentBody = body;
        if (swapping && sameBody)
            panel.swap();
        root.requestedCentre = centreY;
        if (wasClosed) {
            // Nothing to slide from when it was closed: place it, then grow.
            centre.snap();
            // And a fresh answer to "has a pointer been anywhere near this",
            // seeded with whatever is true right now. A swap from one menu to
            // the next is the same visit and keeps the old answer.
            root.sawPointer = root.shellHovered;
        }
        reveal.target = 1;

        // THE LATCH, and the only two things this call is allowed to do to it.
        //
        // A deliberate open puts it on, and nothing here ever takes it off
        // again, because hide() is the one thing that ends a menu outright.
        //
        // An INCIDENTAL open of a DIFFERENT menu takes it off, which reads as
        // the opposite of "the second gauge you tapped is as deliberate as the
        // first" and is exactly what makes that work. One tap on a touchscreen
        // makes TWO requests: Qt synthesises a mouse from the touch, so the
        // icon's containsMouse goes true under the finger and the press arrives
        // here as a hover, and the release arrives as the tap. If the press
        // carried the previous menu's pin across onto this one, the tap an
        // instant later would find its own menu already latched and read as a
        // SECOND tap on it, which is the gesture that CLOSES: tapping a second
        // gauge would open it and put it away again in one press. Dropping the
        // pin here costs nothing, because the tap that follows pins the new menu
        // itself, and a hover-driven swap has a pointer holding it anyway.
        if (pin)
            root.pinned = true;
        else if (swapping)
            root.pinned = false;
    }

    function hide(): void {
        grace.stop();
        root.currentKey = "";
        // THE ONE THING THAT ENDS A MENU OUTRIGHT, so it is the one thing that
        // takes the latch off. Everything else in this file either adds a reason
        // to stay or asks; this is the answer.
        root.pinned = false;
        reveal.target = 0;
        // Nothing left to protect, and a ghost outliving its menu would be a
        // patch of screen that swallows clicks for no reason at all.
        root.held = Qt.rect(0, 0, 0, 0);
    }

    // Leaving anything hoverable asks to close; only the timer running out
    // actually closes it.
    //
    // A pinned menu is not asking anybody. The pointer leaving is not news about
    // a menu the pointer never opened, and starting the timer anyway would mean
    // the pin had to be re-checked when it fired: one question, answered twice,
    // which is the arrangement the notification tray had to unpick.
    function release(): void {
        if (root.open && !root.pinned)
            grace.restart();
    }

    // THE PUSH BACK INTO THE BAR, driven from the Pull wearing the panel's
    // rectangle below.
    //
    // The panel already opens by growing its width from nothing, so there is a
    // 0-to-1 reveal here to run backwards and no second animation to invent: at
    // fraction 1 the panel is exactly as wide as it is while closed, which is
    // the open, played in reverse, under the finger.
    //
    // FLOORED AT THE FOLLOW'S OWN EPSILON, not at zero, and the difference is
    // not cosmetic: MenuPanel's page Loader is `active: reveal > 0`, so a panel
    // pushed the whole way would throw its contents out mid-gesture and a
    // reversal would build a fresh menu rather than putting back the one you
    // were looking at. A sliver of a pixel keeps it alive until the release
    // decides. The floor is the Follow's own landing distance rather than a
    // number of my own, because that is precisely the distance at which "not
    // quite closed" stops being distinguishable from closed anyway.
    function push(fraction: real): void {
        reveal.target = Math.max(reveal.epsilon, 1 - fraction);
    }

    // Let go. `committed` is Pull's "carried on", which for a push INTO the bar
    // means the menu goes away; anything else puts it back where it was.
    function pushEnd(committed: bool): void {
        if (committed)
            root.hide();
        else
            reveal.target = 1;
    }

    function clampCentre(y: real): real {
        const half = panel.implicitHeight / 2;
        return Math.max(root.inset + half, Math.min(y, root.height - root.inset - half));
    }

    Timer {
        id: grace
        interval: Appearance.anim.grace

        onTriggered: {
            // Three separate things can still be holding this menu, and they
            // overlap freely, so the timer asks all of them rather than trusting
            // whichever one spoke last. Same lesson, and the same shape, as the
            // notification tray's `expanded`.
            if (root.pinned || root.hovered || root.shellHovered)
                return;

            // NOTHING EVER HELD THIS ONE, so there is nothing to have let go of.
            //
            // The test above is "did the pointer leave", and it cannot tell that
            // apart from "there was never a pointer": a HoverHandler answers
            // hovering devices only, and a finger is not one, so on a touchscreen
            // both operands are false the entire time a menu is up rather than
            // false because something moved away. Closing on that is closing
            // because nobody was ever there, which is how a tray menu opened by
            // a long press vanished a fifth of a second after the finger lifted.
            //
            // Latch it instead. Something asked for this menu, and the two
            // things that put a menu away by hand (a tap off it, a push back
            // into the bar) are both still there. This is the same argument the
            // CLI's open makes for defaulting to pinned, arrived at from the
            // other end: no pointer, nothing to hold it, so hold it here.
            if (!root.sawPointer) {
                root.pinned = true;
                return;
            }

            root.hide();
        }
    }

    Follow {
        id: centre

        // BOUND, not assigned once.
        //
        // The clamp depends on the panel's height, and at the moment show() runs
        // the panel is still closed: its body Loader has not instantiated, so
        // implicitHeight is the minimum. Clamping there and never revisiting it
        // let a tall menu hang up to 170px off the bottom of the screen. As a
        // binding it re-evaluates when the content arrives and the panel grows.
        target: root.clampCentre(root.requestedCentre)

        // A menu that has to travel further should not take longer, so the panel
        // keeps up with the cursor moving down a column of icons.
        speed: Appearance.anim.trackSpeed
    }

    Follow {
        id: reveal
        speed: Appearance.anim.revealSpeed
        epsilon: 0.005
    }

    // A TAP ANYWHERE OFF THE MENU, which is the way out that has to be found
    // before it can be used, and therefore the one that must always be there.
    //
    // FIRST in this file, so everything else in the layer sits on top of it: the
    // panel takes its own presses and this only ever hears the ones that missed.
    //
    // It starts at the panel's own left edge rather than at the screen's, so the
    // SIDEBAR is not covered. The bar is where menus come out of: tapping a
    // second gauge has to reach that gauge and swap the menu, and tapping the
    // gauge you are already looking at has to reach it to toggle it off. A
    // catcher over the bar would turn every move between menus into a dismiss,
    // which is the one gesture in the sidebar nobody would be aiming for.
    MouseArea {
        id: offPanel

        x: root.originX
        y: 0
        width: root.width - root.originX
        height: root.height

        // ONLY WHILE PINNED, and never merely while open.
        //
        // A hover-opened menu is closed by the pointer leaving, and it lets
        // clicks through to the desktop the whole time it is up. Catching those
        // as well would cost a mouse user a click every time they reached past a
        // menu that opened because they crossed the bar: they never asked for
        // it, so there is nothing for them to dismiss. Only a menu that was
        // asked for has anything to answer a tap with. The window's mask entry
        // is gated on the same flag for the same reason; see ShellWindow.
        enabled: root.pinned

        onClicked: root.hide()
    }

    // THE PANEL GOES BACK INTO THE BAR IT CAME OUT OF, by the gesture that
    // brought it out, reversed (DESIGN.md 15). Leftward, along the edge's own
    // normal, so the menu is put away by shoving it at the sidebar.
    //
    // A SIBLING WEARING THE PANEL'S RECTANGLE, not a child of the panel, and
    // that is the whole reason this is not simply declared inside MenuPanel with
    // a `z: -1`. Pull keeps its press anchor in its PARENT's coordinates, which
    // survives the Pull itself moving or resizing (its x rises by d, mouse.x
    // falls by d, the sum is unchanged) and does not survive the parent moving
    // underneath it. This panel moves constantly: it follows the icon that
    // opened it, it travels to each new content height, and the push below
    // drives its width. Measured against that frame the gesture would be reading
    // its own effect back as pointer movement. `root` holds still, so the
    // anchor means what it says.
    //
    // Declared BEFORE the panel, which is what keeps the arrangement the `z: -1`
    // was for: declaration order is input order, so every row, slider and button
    // inside the panel is above this and takes its own press, and only the
    // panel's bare padding ever starts a push.
    Pull {
        x: panel.x
        y: panel.y
        width: panel.width
        height: panel.height

        // Leftward, and nothing else in this file says which way the gesture
        // runs. The menu hangs off the bar's right flank, so back into the bar
        // is straight left.
        dirX: -1
        dirY: 0

        // AN EDGE'S TOLERANCE, not a corner's. A corner has ninety degrees of
        // "into the screen" to divide up between its neighbours; a flank has a
        // hundred and eighty and nothing else running through them here, so the
        // gate can be twice as generous and still refuse a swipe that set off up
        // or down the panel.
        angle: Appearance.sizes.pullAngleEdge

        // A PUTTING-AWAY pull, so it measures against the panel, which is right
        // there under the hand: one finger-length of panel is one finger-length
        // of travel. The SETTLED width, never the live one: the live width is
        // what this gesture is collapsing, so using it would shrink the scale as
        // the push proceeded and the panel would run away from the finger.
        travel: panel.fullWidth

        // ARMED ONLY WHILE THERE IS A MENU. A sibling is not inside anything
        // that is conditionally enabled, so it says so itself, and it says it
        // with `armed` rather than `enabled` because Pull rejects an unarmed
        // press outright and lets it fall through, where disabling a MouseArea
        // mid-gesture would tear down a grab it was holding.
        armed: root.open

        onPulled: fraction => root.push(fraction)
        onFinished: committed => root.pushEnd(committed)

        // NO onTapped, deliberately. A tap on the panel's own padding is a tap
        // on the thing you are using, and it must do nothing at all: the way out
        // is off the panel or through it, never on it.
    }

    MenuPanel {
        id: panel

        title: root.currentTitle
        body: root.currentBody
        available: root.height - root.inset * 2
        reveal: reveal.value

        x: root.originX
        // The panel's LIVE height, not the size it is heading for. Centring on
        // the destination would move the panel by half the difference the
        // instant the content changed, and then grow it into a place it was
        // already sitting: the travel has to be centred on the travelling size.
        y: centre.value - height / 2

        // A HANDLER, not a MouseArea.
        //
        // This is declared at the use site, so it lands in the panel's `data`
        // after everything MenuPanel builds and sits on top of all of it. As a
        // hoverEnabled MouseArea that made the panel a sheet of glass over its
        // own contents: it took every hover, so nothing inside ever lit up, and
        // it accepted every press, so nothing inside could be clicked or
        // dragged. Every menu in the shell was a picture of a control panel.
        //
        // A handler is passive on both counts, and an ancestor is told about the
        // hover its children accept, so leaving the panel is still an event this
        // can hear. Same lesson as the tray's rows, from the other side: there,
        // the catch-all was under the rows and heard nothing.
        HoverHandler {
            id: pointer
        }
    }

    // Geometry and nothing else: it draws nothing, and an Item accepts no mouse
    // buttons, so it does not stand between the panel and a press. It is only
    // ever read by the window's input region and by the handler inside it.
    //
    // AFTER the panel, so it is not a lid over it. Handlers do not consume
    // hover the way a MouseArea does, so both are told at once.
    Item {
        id: ghost

        x: root.held.x
        y: root.held.y
        width: root.held.width
        height: root.held.height

        HoverHandler {
            id: ghostPointer
        }
    }
}
