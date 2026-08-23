pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
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
// hover cannot undo. It goes on by a tap, by the CLI, or by the grace timer
// noticing that no pointer was ever involved; it comes off by hide() alone. It
// is fastened to the MENU rather than to the layer (see pinnedKey), so hover
// still decides which menu is on screen and therefore whether the latch is
// currently holding anything, and a pinned menu wandered away from and come
// back to is pinned again. That is the same shape the notification tray writes
// down at its own `pinned`, for the same reason, and it is the rule DESIGN.md 15
// states for the whole shell: what hover opened, hover closes; what was asked
// for stays until it is put away, and putting it away is the gesture that
// brought it out, reversed.
Item {
    id: root

    // Where the chassis ends and the desktop begins. The panel starts exactly
    // here so the two never overlap.
    required property real originX
    // The band, so the panel cannot slide into the rounded screen corners.
    required property real inset

    readonly property bool open: currentKey !== ""

    // WHICH MENUS ARE BUILT BEFORE THEY ARE POINTED AT. Handed down rather than
    // listed here, for the reason this layer is handed a Component per open:
    // what a key MEANS is the bar's business, and a layer that went looking for
    // gauge menus by name would be reaching into the file that declares them.
    // MenuPanel.warm is where the whole argument for warming them is written.
    //
    // FILTERED THROUGH A COMPARISON, because the list handed down is rebuilt
    // constantly. A gauge's row carries its live icon and its alert, so
    // StatusIcons.items is a fresh array every time the volume moves or a
    // battery percentage ticks, and passing that straight to a Repeater of
    // PAGES would rebuild every warm menu several times a minute: precisely the
    // cost the warming exists to stop paying, reintroduced by the plumbing for
    // it. Only the key and the Component matter here, and while those are
    // unchanged the same array goes back out and the pages hear nothing.
    property var warmSource: []
    property var warm: []

    onWarmSourceChanged: {
        const next = root.warmSource.filter(e => !!e.body).map(e => ({
                    key: e.key,
                    body: e.body
                }));
        const now = root.warm;
        if (now.length === next.length && now.every((e, i) => e.key === next[i].key && e.body === next[i].body))
            return;
        root.warm = next;
    }

    // THE GHOST, not the panel. See `held` below: the shell's input region is
    // allowed to lag the panel shrinking, so that collapsing a layer under the
    // cursor does not pull the floor out from under it.
    readonly property Item maskItem: ghost

    // WHICH MENU WAS ASKED FOR OUTRIGHT, by key, and "" for none. What everything
    // else reads is `pinned` below; this is the thing that latch is fastened TO.
    //
    // A KEY, NOT A FLAG, and the difference is the whole of a bug where clicking
    // a gauge a second time did nothing at all. A flag belongs to the LAYER, so
    // it has to be taken off whenever the layer starts showing something else,
    // and drifting past a neighbouring gauge is exactly that:
    //
    //   click the audio gauge, and a flag goes on: the audio menu is latched;
    //   drift a few pixels up the bar, and crossing the network gauge asks for
    //     its menu incidentally, which under a flag took the latch off;
    //   drift back down, and the audio menu comes back, no longer latched;
    //   click the audio gauge again, and ShellWindow's toggle asks `pinned`,
    //     gets false, and so pins the menu instead of putting it away. Nothing
    //     visible happens at all. Closing it takes a THIRD click.
    //
    // The gauges sit four pixels apart and their targets meet in the middle of
    // that gap, so "drift a few pixels" is most of what a hand does between two
    // clicks.
    //
    // Fastened to a key it means what it says. The audio menu is the pinned one;
    // it is unlatched while something else is on screen and latched again when
    // it comes back, and nothing has to be remembered to un-say as the layer
    // changes what it is showing.
    //
    // THE TOGGLE IS THE WHOLE OF WHAT THE KEY FIXES, and the neighbouring bug it
    // does NOT fix is written down here so nobody reads a wider claim into it. A
    // pin still dies with the visit: pin the audio menu, drift up onto the
    // network gauge, which puts its menu on screen incidentally and makes
    // `pinned` false by arithmetic, and then leave the shell from there.
    // release() sees no pin and starts the grace timer, the timer sees no pin,
    // no hover and a pointer that was very much here, and hide() closes the
    // incidental menu and clears the key with it. The menu somebody asked for is
    // gone, and coming back does not bring it. Only the narrower case is cured:
    // wander onto a neighbour and back onto the pinned menu before leaving, and
    // the latch is holding again by the time the pointer goes.
    //
    // Curing the rest is not a test that belongs here. Nothing wants the
    // incidental menu to survive being abandoned; what should happen is that
    // abandoning it puts the PINNED one back, and this layer cannot do that,
    // because it is handed a title, a body and a centre per open (see show())
    // and deliberately remembers nothing about a key it is not showing. Whoever
    // knows what a key means would have to be asked to open it again.
    property string pinnedKey: ""

    // PINNED: this menu was asked for outright, so nothing that merely wandered
    // off gets to take it away. See the header for why an instant needs a latch
    // where a continuous state does not.
    //
    // DERIVED, so there is one fact here rather than two to keep in step: the
    // latch is on exactly while the menu on screen is the menu that was asked
    // for. That is the shape NotificationTray.expanded writes down, for the same
    // reason, and it is why nothing below has to clear anything on a swap.
    //
    // The rejected alternative was to leave this file alone and simply not run
    // the grace timer for touch. Nothing here can tell a touchscreen from a
    // mouse that has not moved yet, and a timer that never fires is a menu that
    // can never be closed, which is the other half of the same bug.
    readonly property bool pinned: root.pinnedKey !== "" && root.pinnedKey === root.currentKey

    // Whether a POINTER has been on the shell at all since this menu opened.
    //
    // Recorded on the CHANGE rather than read once inside show(): a cursor that
    // lands straight on an icon from off the shell answers both questions in one
    // event, and Qt updates the deepest item that took the hover before it gets
    // to an ancestor's handler, so a read at show() time can miss a pointer that
    // is very much there. A flag set by the change cannot miss it: whichever
    // order the two arrive in, the change still arrives.
    property bool sawPointer: false

    // THERE IS NO CATCHER HERE ANY MORE, AND THERE MUST NOT BE ONE AGAIN.
    //
    // A full-screen MouseArea used to sit at the top of this file and go into
    // the surface's input region whenever a menu was pinned, so that a tap
    // anywhere off the menu would put it away. It reads as a small courtesy and
    // it is not one. A Wayland surface that owns a region OWNS it: every press
    // there is delivered to this shell and to nothing else. So for as long as
    // any menu stood open, no window answered a click, no text could be
    // selected, and the press that eventually dismissed the menu was spent on
    // that instead of on whatever it was aimed at. Reaching past an open menu
    // cost two clicks, the first of which appeared to do nothing at all.
    //
    // Nothing about a menu is worth that, because nothing about a menu needs it.
    // The gauge it came out of closes it again (ShellWindow's onRequested),
    // Escape closes it, another gauge replaces it, and the push gesture shoves
    // it back into the bar. Four ways out, none of which costs the desktop a
    // single event. A fifth, bought by making everything else stop working, is
    // not a way out; it is a toll.
    //
    // The touchscreen was the case this was built for and it is covered by the
    // same four: a tap on the gauge opens the menu and a second tap on the same
    // gauge closes it, which is the one control a finger already knows where to
    // find. `sawPointer` below survives because the grace timer still needs to
    // tell "the pointer left" from "there was never a pointer", which is a
    // different question and always was.


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
    //
    // AND ASKED ABOUT THIS WINDOW, not about the shell, which is the whole of
    // what a second monitor changes here. There is one of these layers per
    // screen and one Prompts for all of them, so the shell-wide answer was yes
    // on every monitor the instant a field opened on any of them: a menu merely
    // left up over here would ask for the keyboard on behalf of a field over
    // there, both surfaces would hold it exclusively, and the typing would land
    // in neither. The claim belongs to one surface, and `shellWindow` is how
    // this one says which surface it is.
    readonly property bool needsKeyboard: root.open && Prompts.activeIn(root.shellWindow)

    // The surface this layer is drawn on, and on a second monitor it is one of
    // several. `QsWindow.window` is how an item names the window it is in;
    // modules/SettingsCorner.qml reads the same line for the same reason, that
    // being in a window and knowing which one are not the same thing.
    readonly property var shellWindow: QsWindow.window

    // WHETHER ESCAPE HAS TO REACH THIS LAYER, which is a different request from
    // `needsKeyboard` above and is deliberately not folded into it.
    //
    // `needsKeyboard` says a field is waiting to be typed into. It wants EVERY
    // key, which is why the launcher, the power panel and the hotkey sheet each
    // close a menu that claims it (ShellWindow says so three times): two things
    // cannot read one keyboard. This wants ONE key. Widening `needsKeyboard` to
    // mean both would have made those three exclusions fire for a menu somebody
    // merely left up, so reaching for the launcher would have taken away the
    // audio panel you were reading, which is precisely the surprise ShellWindow's
    // own note says it will not have. Two claims, because they are two claims.
    //
    // THE PIN ITSELF, not `pinned`, and the difference is one gauge of drift.
    // `pinned` is the pin AND the menu it names being the one on screen, so
    // crossing a neighbouring gauge makes it false by arithmetic (see pinnedKey)
    // and true again on the way back. As a keyboard request that is a grab
    // dropped and retaken per crossing, and a layer surface dropping the keyboard
    // hands it back to whatever window is underneath: a focus change and a border
    // repaint every time a hand wanders four pixels up the bar, for a menu that
    // never went anywhere. What has to be asked here is "did somebody ask for a
    // menu, and is one still up", which is what the KEY answers on its own. The
    // incidental menu the drift put on screen is closed by the same Escape,
    // because hide() is one answer for the whole layer rather than for a key.
    //
    // WHAT CHANGED IS NOT THIS FLAG BUT WHAT IS ASKED FOR IT. Escape used to be
    // fetched with an EXCLUSIVE keyboard claim, and that claim does not only
    // take the keyboard: Hyprland makes the asking surface the focused one and
    // routes the POINTER to it as well, straight over the input region the
    // surface set. Measured: with a menu holding the keyboard this way, the
    // shell was told the cursor was at 3844,720 in its own coordinates, a point
    // squarely inside the hole the mask subtracts, and every press there was
    // delivered here. So one key, asked for the wrong way, cost the desktop
    // everything the catcher above was already being blamed for. It is asked for
    // on demand now instead; see ShellWindow's keyboardFocus.
    readonly property bool wantsEscape: root.pinnedKey !== ""

    // WHETHER SOMETHING ELSE IN THIS WINDOW IS ALREADY READING EVERY KEY. Handed
    // down rather than worked out here, for the reason `shellHovered` below is
    // handed down: the launcher, the power panel and the hotkey sheet are
    // ShellWindow's to know about, and a layer that went looking for them by id
    // would be reaching up into the file that declares it.
    //
    // IT GATES THE GRAB AND NOTHING ELSE. Qt gives active focus to exactly ONE
    // item in a window, so a pin going on while one of those three is up takes
    // the caret out of the launcher's search field: the field goes on drawing and
    // stops hearing, and nothing anywhere gives it back, because ShellWindow's
    // exclusions fire when those panels OPEN and this pin arrived second. A menu
    // loses nothing by waiting. What a pin wants is ONE key, and while the focus
    // is elsewhere ShellWindow's Escape fallback says exactly what this layer
    // would have said; what the field wants is every key, and there is nothing
    // that can say that on its behalf.
    property bool keyboardHeld: false

    // THE GRAB ITSELF, in one place, because the two handlers below arrive at it
    // from opposite directions and every condition on it belongs to both.
    //
    // ASKED AGAIN HERE rather than only at the signal that queued it, which is
    // the whole reason this is a function rather than two calls to
    // forceActiveFocus. The grab is deferred (see below), and between the request
    // and this running the layer can have closed, the pin can have come off, a
    // field can have claimed the keyboard or a panel that takes every key can
    // have opened: a callLater bound straight to `keys.forceActiveFocus` carries
    // out a request the shell has stopped meaning.
    //
    // `open` IS THE TERM THAT WAS MISSING, and it is not a hypothetical. hide()
    // clears currentKey BEFORE pinnedKey, so a menu holding a live prompt drops
    // `needsKeyboard` a line before it drops `wantsEscape`, and the second
    // handler below fired in between, with the pin still on, and handed the
    // window's focus to a layer that was already off screen. That layer's Escape
    // handler then answered every press with a hide() of nothing and accepted it,
    // so a tray or a notch pinned underneath, whose surface is holding the
    // compositor's keyboard exclusively, could no longer be closed by key at all.
    // Reordering the two writes in hide() fixes that one path and leaves the next
    // caller to rediscover it; asking the state at the moment of the grab cannot
    // be got wrong from outside.
    function claimKeys(): void {
        if (root.open && root.wantsEscape && !root.needsKeyboard && !root.keyboardHeld)
            keys.forceActiveFocus();
    }

    // Taken when the pin goes on, handed back when it comes off.
    //
    // DEFERRED, like every other panel here: the surface only asks the compositor
    // for the keyboard once this has propagated (ShellWindow's keyboardFocus), and
    // focus forced before that lands is focus in a surface with no keys to give.
    //
    // Handing it back is not merely tidiness. Nothing arrives here once the
    // surface stops asking, so leaving the focus on `keys` breaks nothing today;
    // what it would leave behind is a hidden layer's item holding the window's
    // focus while a panel that IS on screen goes looking for it.
    onWantsEscapeChanged: {
        if (root.wantsEscape)
            Qt.callLater(root.claimKeys);
        else
            keys.focus = false;
    }

    // A PROMPT ENDING GIVES THE KEY BACK, and without this the second Escape of
    // the pair goes nowhere.
    //
    // PasswordField takes the window's focus the moment it appears and answers
    // its own Escape by cancelling, which is the right order: the first Escape
    // answers the question you are being asked, the second puts away the thing
    // that asked it. But the field takes the focus off `keys` to do it and hands
    // it back to nobody, so the second press would arrive at an item that has
    // stopped listening. Asked of `needsKeyboard` falling rather than of the
    // field, which this file never sees and must not have to: the claim is kept
    // in Prompts precisely so no menu has to know one exists.
    //
    // THROUGH claimKeys RATHER THAN GATED ON THE PIN HERE, because the two claims
    // do NOT drop at once, which is what this handler used to assume and what
    // hide() plainly does not do: it clears the key first and the pin second, so
    // this fires in between, with `wantsEscape` still true, for a menu that has
    // already gone. Every condition the grab needs is stated once, up there.
    onNeedsKeyboardChanged: {
        if (!root.needsKeyboard)
            Qt.callLater(root.claimKeys);
    }

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

        // THE LATCH, and the one thing this call is allowed to do to it.
        //
        // A deliberate open fastens it to the menu being opened, and nothing
        // here ever takes it off again, because hide() is the one thing that
        // ends a menu outright.
        //
        // AN INCIDENTAL OPEN TAKES NOTHING OFF, and no longer has to. `pinned`
        // is derived from the key it was fastened to (see pinnedKey), so a hover
        // that puts a different menu on screen unlatches the layer by arithmetic
        // rather than by forgetting, which is what makes "the second gauge you
        // tapped is as deliberate as the first" work. One tap on a touchscreen
        // makes TWO requests: Qt synthesises a mouse from the touch, so the
        // icon's containsMouse goes true under the finger and the press arrives
        // here as a hover, and the release arrives as the tap. If the press
        // carried the previous menu's pin across onto this one, the tap an
        // instant later would find its own menu already latched and read as a
        // SECOND tap on it, which is the gesture that CLOSES: tapping a second
        // gauge would open it and put it away again in one press. It cannot,
        // because the pin names the menu it belongs to and that is not this one.
        if (pin)
            root.pinnedKey = key;
    }

    function hide(): void {
        grace.stop();
        root.currentKey = "";
        // THE ONE THING THAT ENDS A MENU OUTRIGHT, so it is the one thing that
        // takes the latch off. Everything else in this file either adds a reason
        // to stay or asks; this is the answer.
        //
        // CLEARED, rather than left to the derivation above. `pinned` is already
        // false the instant currentKey is, so this changes nothing today; a key
        // left lying here would fasten itself back on the next time that same
        // menu opened, and a menu that a passing cursor opened would come up
        // latched by a click somebody made minutes ago.
        root.pinnedKey = "";
        reveal.target = 0;
        // Nothing left to protect, and a ghost outliving its menu would be a
        // patch of screen that swallows clicks for no reason at all.
        root.held = Qt.rect(0, 0, 0, 0);
    }

    // Leaving anything hoverable asks to close; only the timer running out
    // actually closes it.
    //
    // A pinned menu is not asking anybody. The pointer leaving is not news about
    // a menu that was asked for by name: it is somebody going off to use the
    // window they opened the menu about, and the menu is what they will look
    // back at. Starting the timer anyway would mean the pin had to be re-checked
    // when it fired: one question, answered twice, which is the arrangement the
    // notification tray had to unpick.
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
            if (root.pinned || root.hovered || root.shellHovered || root.needsKeyboard)
                return;

            // `needsKeyboard` is the newcomer in that list, and it covers a menu
            // that was never pinned at all: a network row pressed out of a menu
            // the cursor merely opened puts a password field on screen, and a
            // field is the one thing here that a hand deliberately leaves the
            // mouse to use. Without it, moving off to reach the keyboard closed
            // the question being answered.

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
                root.pinnedKey = root.currentKey;
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
        // BEFORE the body, and that is an ordering rather than a coincidence.
        // show() assigns the key first and the body last, the panel swaps on the
        // body arriving, and the swap has to know which menu it is placing.
        key: root.currentKey
        body: root.currentBody
        warm: root.warm
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

    // THE KEYBOARD, on an item of its own rather than on the panel, and last in
    // the file rather than beside the property that asks for it.
    //
    // ON ITS OWN because the panel is invisible until the reveal has moved off
    // zero, and an invisible item cannot hold focus: focusing the panel on the
    // way up would silently do nothing and the first Escape would go to the
    // desktop. The settings page says the same sentence over its own `keys`, and
    // SessionMenu learned it first. This one has no size and is always visible,
    // so it is always focusable.
    //
    // LAST because every item above it says where it stands in this layer's input
    // order, and this one stands nowhere in it: it draws nothing, has no geometry
    // and accepts no mouse buttons at all, so the catcher is still the first thing
    // a stray press meets and the ghost is still the last thing hover reaches.
    // Declared among them, both of those sentences would have needed a footnote
    // about an item that takes no input.
    Item {
        id: keys

        Keys.onPressed: event => {
            // hide(), so the layer is put away WHOLE: the key, the pin, the
            // reveal and the ghost go together, and a menu that Escape left
            // half-latched would come back pinned the next time the cursor
            // crossed its gauge. It is the same call the catcher and the
            // push-back make, which is the point: however the menu was opened,
            // it leaves by one door.
            //
            // AND ONLY WHILE THERE IS ONE, which is not made redundant by the
            // grab now checking the same thing. That decides when this item is
            // given the focus; this decides what it is entitled to answer while
            // it still has it, and the two are a frame apart at every handover.
            // An accepted key stops travelling, so a press answered here on
            // behalf of a closed layer is a press ShellWindow's fallback never
            // sees, and hide() on a closed layer does nothing at all: the whole
            // exchange would be this item eating Escape for a tray, a notch or a
            // page that is on screen and waiting for it.
            if (event.key === Qt.Key_Escape && root.open) {
                root.hide();
                event.accepted = true;
            }
        }
    }
}
