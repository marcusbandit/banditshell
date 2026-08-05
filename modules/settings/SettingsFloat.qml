pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// The other half of the settings page: the card, while a real window is holding
// it.
//
// SHELL-WIDE, one of them, outside Variants. A window is not a per-screen
// surface; it is on whichever monitor it has been dragged to, and asking each
// screen to own one would mean two windows the first time a second monitor was
// plugged in.
//
// KEPT ALIVE, hidden, rather than destroyed between uses. The page is a page,
// not a dialog, and rebuilding it every time it was pulled out would throw away
// whatever state it had accumulated - which, once this has more in it than a
// button, is the entire point of it being a settings page.
//
// It is an ORDINARY WINDOW, and it is supposed to look like one: the compositor
// gives it the same border, corner and shadow it gives everything else on the
// desktop, and the page fills what is inside that. The shell asks for none of it
// back. A page that suppressed all of it and drew its own instead read as a
// translucent hole in the desktop with the wallpaper coming through - the one
// window on screen that did not look like a window. See Settings.rules.
FloatingWindow {
    id: win

    title: Settings.windowTitle

    // Opaque, and the same colour the page fills itself with. Nothing behind a
    // window is meant to be seen through it, and a transparent window colour
    // showing at a rounding's edge is the only place it would be.
    color: Appearance.colour.surfaceSolid

    // A HINT, not a binding on `width`. The compositor is what actually decides
    // how big a window is, and the user is allowed to drag its corner; a binding
    // on the real size would be broken by the first resize and would be lying
    // about who is in charge until then. The exact size at birth is set by
    // Settings, in the compositor's own terms, where it belongs.
    implicitWidth: Settings.windowWidth
    implicitHeight: Settings.windowHeight

    visible: false

    Connections {
        target: Settings

        function onWindowOpenChanged(): void {
            win.visible = Settings.windowOpen;
        }
    }

    // THE COMPOSITOR CAN CLOSE THIS, and when it does Qt takes `visible` down
    // itself rather than asking first. Which is a perfectly good way to put the
    // page away - it is a window, closing windows is what you do to them - so it
    // is treated as one rather than left as a page that is open, floating, and
    // nowhere.
    //
    // It is also why `visible` above is assigned rather than bound: a binding
    // that Qt overwrites is a binding that is gone, and the next pull-out would
    // have opened nothing.
    onVisibleChanged: {
        if (!win.visible && Settings.windowOpen)
            Settings.hide();
    }

    // INVISIBLE UNTIL IT IS WHERE IT BELONGS.
    //
    // A new floating window lands wherever the compositor felt like putting it,
    // and that is never where the card was standing. The shell keeps drawing the
    // card until this has been moved onto it, so for those few milliseconds
    // there are two copies of the page and only one of them may be seen. This is
    // the one that may not, yet.
    //
    // Not a fade: opacity goes 0 to 1 in one step, on the frame the window
    // reaches the card's rect. There is nothing to ease, because from the
    // outside nothing happened.
    Item {
        anchors.fill: parent

        opacity: Settings.placed ? 1 : 0

        SettingsFace {
            anchors.fill: parent

            windowed: true
            onHandover: Settings.popIn()
        }
    }
}
