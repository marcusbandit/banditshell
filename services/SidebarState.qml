pragma Singleton

import QtQuick
import Quickshell
import qs.config

// Whether the sidebar is on a screen, and which screens say otherwise.
//
// ONE PRESENCE PER SCREEN, said the way the wallpaper says it (services/
// Wallpaper.qml): a default in config plus a map of the screens that disagree,
// rather than an answer per output.
//
//   sidebar.enabled    what a screen wears when nothing says otherwise
//   sidebar.perScreen  { "DP-1": false } for the screens that do
//
// So the answer to "is the sidebar on that monitor" is a function of a screen
// name and never a property, and every reader of the question asks it HERE:
// the chassis, whose field either contains the slab or does not; FrameExclusions,
// which reserves the left edge's room and hands the width back; ShellWindow,
// which lays the column's contents out or leaves them down; the lock face,
// which draws the same chassis the shell does; the CLI; and the monitors page's
// row. One fact, one place, so a screen whose sidebar went away is agreed on by
// everything that draws, reserves, or answers for it.
//
// NAMED SIDEBARSTATE AND NOT SIDEBAR, and that is load-bearing rather than
// shy of a clash. Three components are already called Sidebar - the column
// itself (modules/sidebar/Sidebar.qml), the file browser's (modules/files/
// Sidebar.qml), and this - and every file that imports qs.services unqualified
// would have all three in one scope. A composite singleton WINS that lookup
// and then cannot be created: measured as the whole shell failing its reload
// with "Composite Singleton Type Sidebar is not creatable" out of a file this
// feature never touched. Clock.qml's qualified import is the patch-up for one
// file; a name nothing else owns is the patch-up for all of them.
//
// WHY A SERVICE AND NOT A TOKEN ON Appearance: Appearance resolves design
// tokens and writes nothing; this is shell state with writers in two places
// (the CLI and the settings page), which is the shape Wallpaper.qml is.
Singleton {
    id: root

    // THE DEFAULT, which is what "the sidebar" means on a machine with one
    // screen or with every screen agreeing. An empty screen name asks about it,
    // which is what the harnesses (no output of their own) and a compositor
    // that has not yet named a monitor are asking.
    readonly property bool enabled: Config.values.sidebar.enabled

    // WHICH SCREENS DISAGREE, by output name. Raw off the config; `visibleOn`
    // is the reader.
    readonly property var perScreen: Config.values.sidebar.perScreen ?? ({})

    // WHETHER THE SIDEBAR IS ON, ON THAT SCREEN. The whole per-screen model is
    // this one function; everything else is a caller of it.
    //
    // An empty screen name answers with the default rather than with nothing,
    // because the callers that have no screen (a preview window, a harness, the
    // moment before the compositor has named the output) are asking what the
    // shell looks like, not what a particular monitor has decided.
    function visibleOn(screen: string): bool {
        if (!screen)
            return root.enabled;
        return root.perScreen[screen] ?? root.enabled;
    }

    // SET ONE SCREEN, or, with no screen, the default every screen follows.
    //
    // NO SCREEN MEANS ALL OF THEM, and only here. `visibleOn("")` reads the
    // default because a reader with no screen is asking what the sidebar IS; a
    // WRITER with no screen is asking to change it, and the only honest target
    // for that is the default. services/Wallpaper.setOn runs on the same rule
    // from the opposite end.
    function setOn(screen: string, on: bool): void {
        if (!screen) {
            root.setAll(on);
            return;
        }

        // AN ENTRY THAT AGREES WITH THE DEFAULT IS NOT KEPT, and this is not
        // tidiness. A map that holds agreement looks the same as one that
        // disagrees on every screen it names, and the failure lands later:
        // hide DP-1, hide the rest with `all`, and a stale "false" on DP-1
        // would go on holding it hidden the day `show all` moved the default
        // back. Deleting the agreement is what makes "the screens that
        // disagree" a sentence the file can be trusted to still mean.
        const next = Object.assign({}, root.perScreen);
        if (on === root.enabled)
            delete next[screen];
        else
            next[screen] = on;
        Config.set("sidebar.perScreen", next);
    }

    // EVERY SCREEN AT ONCE: the default moves and the map empties, together.
    // Two writes would notify in between and repaint the desk twice for one
    // decision; Config.setMany exists for exactly that, and for the same
    // reason Wallpaper.setAll is one.
    function setAll(on: bool): void {
        Config.setMany([["sidebar.perScreen", {}], ["sidebar.enabled", on]]);
    }
}
