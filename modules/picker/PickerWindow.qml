import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

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

    WlrLayershell.keyboardFocus: win.visible && win.holdsKeyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property bool holdsKeyboard: false

    readonly property bool up: win.state.open
    onUpChanged: win.holdsKeyboard = win.up && win.wouldHoldKeyboard()

    function wouldHoldKeyboard(): bool {
        const mine = win.screen?.name ?? "";
        const focused = Hypr.focusedScreen;
        const known = !!focused && Quickshell.screens.some(s => s.name === focused);
        return known ? focused === mine : Quickshell.screens[0]?.name === mine;
    }

    visible: win.state.open && !win.state.hiding

    Picker {
        anchors.fill: parent
        state: win.state
        screen: win.screen
    }
}
