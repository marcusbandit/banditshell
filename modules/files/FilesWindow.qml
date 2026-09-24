pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services

// The file browser's body: a real window.
//
// SHELL-WIDE and outside Variants, for the reason SettingsFloat spells out at
// length: a window is not a per-screen surface, it is on whichever monitor it
// was dragged to, and asking each screen to own one would make two of them the
// first time a second monitor was plugged in.
//
// KEPT ALIVE, hidden, between uses - and here that is not a nicety, it is the
// whole point. Inside this window is a shell session with a directory, an
// environment and a history in it. Destroying the window would kill it, and a
// terminal that forgets everything each time you close the panel is not a
// terminal, it is a command box.
//
// It is an ORDINARY WINDOW and is supposed to look like one. The compositor
// gives it the border, corner and shadow it gives everything else on the
// desktop, and the browser fills what is inside that. See Settings.rules for why
// a page that suppressed all of it read as a hole in the desktop.
FloatingWindow {
    id: win

    title: Files.windowTitle

    // Opaque, and the same colour the shell's panels resolve to with nothing
    // behind them. A window is the one surface here that is not blurred by the
    // compositor, so translucency in it is not depth - it is the wallpaper
    // coming through the page.
    color: Appearance.colour.surfaceSolid

    // A HINT, not a binding. The compositor decides how big a window is and the
    // user is allowed to drag its corner; a binding on `width` would be broken
    // by the first resize and lying about who is in charge until then.
    implicitWidth: Appearance.sizes.filesWidth
    implicitHeight: Appearance.sizes.filesHeight

    visible: false

    Connections {
        target: Files

        function onWindowOpenChanged(): void {
            win.visible = Files.windowOpen;
        }
    }

    // THE COMPOSITOR CAN CLOSE THIS, and when it does Qt takes `visible` down
    // itself rather than asking first. Which is a perfectly good way to put the
    // browser away, so it is treated as one rather than left open, floating and
    // nowhere. It is also why `visible` above is assigned rather than bound: a
    // binding Qt overwrites is a binding that is gone.
    onVisibleChanged: {
        if (!win.visible && Files.windowOpen) {
            Files.hide();
            return;
        }

        // AND THE KEYBOARD HAS TO BE ASKED FOR AGAIN ON EVERY OPEN. The window
        // is hidden rather than destroyed between uses, and a hidden window's
        // item loses active focus; showing it again does not hand it back.
        if (win.visible)
            face.forceActiveFocus();
    }

    // THE HELPERS ARE BUILD OUTPUT and are not committed, so the first run after
    // a clone has none. An empty grid is a terrible way to say that, and it is
    // the one failure this window cannot recover from on its own.
    Loader {
        anchors.fill: parent

        active: Files.helpersMissing
        sourceComponent: HelpersMissing {}
    }

    Loader {
        id: face

        anchors.fill: parent

        // FOCUS: TRUE, AND IT IS LOAD-BEARING. A Loader is an item in the focus
        // chain like any other: the face inside it asks for focus, but a Loader
        // that has none has none to give, so not one keystroke reached the
        // window. Everything worked under the mouse and no chord did anything at
        // all - including Ctrl+J, which is the way in to the terminal.
        //
        // It never showed up in the preview harness because there the face is a
        // direct child of the window and there is no Loader between them.
        focus: true
        active: !Files.helpersMissing
        sourceComponent: FilesFace {}
    }

}
