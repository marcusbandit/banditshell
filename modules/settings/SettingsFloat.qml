pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services

// The settings page: the whole of it, in a real window.
//
// SHELL-WIDE, one of them, outside Variants. A window is not a per-screen
// surface; it is on whichever monitor it has been dragged to, and asking each
// screen to own one would mean two windows the first time a second monitor was
// plugged in.
//
// KEPT ALIVE, hidden, rather than destroyed between uses. The page is a page,
// not a dialog, and rebuilding it every time it was opened would throw away
// whatever state it had accumulated - which, once this has more in it than a
// button, is the entire point of it being a settings page.
//
// It is an ORDINARY WINDOW, and it is supposed to look like one: the compositor
// gives it the same border, corner and shadow it gives everything else on the
// desktop, and the page fills what is inside that. The shell asks for none of
// it back. A page that suppressed all of it and drew its own instead read as a
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
    // about who is in charge until then.
    implicitWidth: Settings.homeWidth
    implicitHeight: Settings.homeHeight

    visible: false

    Connections {
        target: Settings

        function onOpenChanged(): void {
            win.visible = Settings.open;
        }
    }

    // THE COMPOSITOR CAN CLOSE THIS, and when it does Qt takes `visible` down
    // itself rather than asking first. Which is a perfectly good way to put the
    // page away - it is a window, closing windows is what you do to them - so it
    // is treated as one rather than left as a page that is open, floating, and
    // nowhere.
    //
    // It is also why `visible` above is assigned rather than bound: a binding
    // that Qt overwrites is a binding that is gone, and the next open would
    // have opened nothing.
    //
    // AND THE KEYBOARD HAS TO BE ASKED FOR AGAIN ON EVERY OPEN, the way
    // FilesWindow asks. The window is hidden rather than destroyed between
    // uses, a hidden window's item loses active focus, and showing it again
    // does not hand it back; without this, Escape and the search field are
    // dead from the second open on.
    onVisibleChanged: {
        if (!win.visible && Settings.open) {
            Settings.hide();
            return;
        }

        if (win.visible)
            face.forceActiveFocus();
    }

    SettingsFace {
        id: face

        anchors.fill: parent
    }
}
