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
    readonly property Item maskItem: panel

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

    // True while the cursor is on the panel itself, which keeps it open.
    readonly property bool hovered: pointer.hovered

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
}
