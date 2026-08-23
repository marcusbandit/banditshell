import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// The picker's surface, one per screen.
//
// OVERLAY layer and exclusive keyboard focus, which is the one place this shell
// takes over the whole screen. It has to be above everything, because the thing
// being captured is everything, and one of these windows has to have the
// keyboard, because Escape must cancel from anywhere. ONE of them: see
// holdsKeyboard for why the surface that takes it is picked rather than assumed.
//
// It is a separate window from the shell rather than part of it: the shell's own
// surface deliberately gives way to fullscreen windows, and a screenshot tool
// that vanishes when you point it at a fullscreen video is no use at all.
PanelWindow {
    id: win

    required property PickerState state

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    exclusiveZone: 0
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "banditshell-picker"
    // Only while it is actually up, and only on the ONE screen that latched it.
    // An unconditional exclusive grab on a surface that merely exists takes the
    // keyboard from the desktop, and a grab on every surface that is up takes it
    // from everybody including itself.
    WlrLayershell.keyboardFocus: win.visible && win.holdsKeyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // WHICH SCREEN OWNS THE KEYBOARD WHILE THE PICKER IS UP, and it is exactly
    // one of them.
    //
    // There is one of these windows per screen and all of them are up together,
    // so a grab conditioned on being visible is N grabs on N monitors, which is
    // the one arrangement where the keyboard reaches nobody at all: two layer
    // surfaces holding it exclusively is the "typing goes nowhere" failure
    // ShellWindow's own keyboardFocus is written around. Escape has to arrive
    // SOMEWHERE, not everywhere, and one surface answering it cancels the picker
    // for every screen at once, because the state it cancels is shell-wide.
    //
    // EVERY SCREEN STAYS VISIBLE. Only the keyboard is owned in one place: a
    // selection is a pointer dragged across a monitor, the pointer was never in
    // this fight, and a picker that only accepted a drag on the screen that
    // happened to be focused would be a worse tool than the one this replaces.
    property bool holdsKeyboard: false

    // The picker's life, mirrored so the latch has an edge to hang off.
    //
    // Deliberately NOT `visible`, which drops and returns every time a live
    // capture is taken (see below), and re-latching on that edge is the
    // mid-gesture handover this whole arrangement exists to prevent.
    readonly property bool up: win.state.open
    onUpChanged: win.holdsKeyboard = win.up && win.wouldHoldKeyboard()

    // THE SCREEN THAT WAS FOCUSED WHEN IT OPENED, latched there rather than
    // followed. Hypr.focusedScreen is what "the screen" means to anything
    // summoned by a keybind, which the picker always is; but it moves with the
    // pointer, and a grab that tracked it would be handed from one surface to
    // another the instant a drag crossed a monitor edge. A layer surface
    // dropping the keyboard hands it straight back to whatever is underneath, so
    // Escape after that would go to somebody's editor rather than to the
    // screenshot they were trying to abandon.
    //
    // Worked out identically in every window rather than decided once in the
    // shared state, which is what keeps this file out of PickerState: the
    // compositor names one monitor and the window whose screen carries that name
    // is the one that takes it. If it names a monitor this shell has no surface
    // on, or names nothing at all, the first screen takes it instead, and since
    // every window sorts the same list the same way, exactly one still does.
    //
    // A screen plugged in while the picker is already open never gets asked, and
    // that is right: the surface holding the keyboard goes on holding it.
    function wouldHoldKeyboard(): bool {
        const mine = win.screen?.name ?? "";
        const focused = Hypr.focusedScreen;
        const known = !!focused && Quickshell.screens.some(s => s.name === focused);
        return known ? focused === mine : Quickshell.screens[0]?.name === mine;
    }

    // Hidden, not destroyed, while a live capture is taken: grim must not find
    // the picker in the picture.
    visible: win.state.open && !win.state.hiding

    Picker {
        anchors.fill: parent
        state: win.state
        screen: win.screen
    }
}
