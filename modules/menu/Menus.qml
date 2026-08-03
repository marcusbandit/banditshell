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
    onShellHoveredChanged: if (!root.shellHovered)
        root.release()

    function show(key: string, title: string, body: Component, centreY: real): void {
        // Asked BEFORE currentKey changes, and asked of the state rather than of
        // the animation's value: "is the reveal at zero" is a float test, and a
        // float test for closed is exactly the kind that works until it doesn't.
        const wasClosed = !root.open;

        grace.stop();
        root.currentKey = key;
        root.currentTitle = title;
        root.currentBody = body;
        root.requestedCentre = centreY;
        // Nothing to slide from when it was closed: place it, then grow.
        if (wasClosed)
            centre.snap();
        reveal.target = 1;
    }

    function hide(): void {
        grace.stop();
        root.currentKey = "";
        reveal.target = 0;
        // Nothing left to protect, and a ghost outliving its menu would be a
        // patch of screen that swallows clicks for no reason at all.
        root.held = Qt.rect(0, 0, 0, 0);
    }

    // Leaving anything hoverable asks to close; only the timer running out
    // actually closes it.
    function release(): void {
        if (root.open)
            grace.restart();
    }

    function clampCentre(y: real): real {
        const half = panel.implicitHeight / 2;
        return Math.max(root.inset + half, Math.min(y, root.height - root.inset - half));
    }

    Timer {
        id: grace
        interval: Appearance.anim.grace
        onTriggered: if (!root.hovered && !root.shellHovered)
            root.hide()
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
