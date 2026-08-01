pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

// The menu layer: at most one menu open at a time, hanging off the sidebar.
//
// It owns three things the panel itself should not care about:
//
//   WHICH is open, so opening a second closes the first without a flicker. The
//   panel never unmounts between menus; it slides to the new anchor and swaps
//   its title, which is why switching feels like one object moving rather than
//   two appearing.
//
//   WHERE it sits: the panel's centre follows the icon that asked for it, by
//   exponential smoothing, clamped so it never runs past the chassis.
//
//   WHETHER it stays: hover is a sloppy input. Leaving starts a short grace
//   timer instead of closing immediately, so crossing from the icon to the panel
//   or between icons does not dismiss anything.
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

    property string currentKey: ""
    property string currentTitle: ""

    // True while the cursor is on the panel itself, which keeps it open.
    readonly property bool hovered: pointer.containsMouse

    function show(key: string, title: string, centreY: real): void {
        // Asked BEFORE currentKey changes, and asked of the state rather than of
        // the animation's value: "is the reveal at zero" is a float test, and a
        // float test for closed is exactly the kind that works until it doesn't.
        const wasClosed = !root.open;

        grace.stop();
        root.currentKey = key;
        root.currentTitle = title;
        centre.target = root.clampCentre(centreY);
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
        onTriggered: if (!root.hovered)
            root.hide()
    }

    Follow {
        id: centre
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
        reveal: reveal.value

        x: root.originX
        y: centre.value - implicitHeight / 2

        MouseArea {
            id: pointer

            anchors.fill: parent
            hoverEnabled: true
            onExited: root.release()
        }
    }
}
