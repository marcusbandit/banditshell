import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config

// The picker's surface, one per screen.
//
// OVERLAY layer and exclusive keyboard focus, which is the one place this shell
// takes over the whole screen. It has to be above everything, because the thing
// being captured is everything, and it has to have the keyboard, because Escape
// must cancel from anywhere.
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
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // Hidden, not destroyed, while a live capture is taken: grim must not find
    // the picker in the picture.
    visible: win.state.open && !win.state.hiding

    Picker {
        anchors.fill: parent
        state: win.state
        screen: win.screen
    }
}
