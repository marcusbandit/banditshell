import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.services
import qs.modules.wallpaper

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

    readonly property string frozen: win.state.frozenByScreen[win.screen?.name ?? ""] ?? ""

    Loader {
        anchors.fill: parent
        active: win.visible
        sourceComponent: win.frozen !== "" ? stillGlass : liveGlass
    }

    Component {
        id: liveGlass

        ScreenBackdrop {
            output: win.screen?.name ?? ""
            screenOrigin: Qt.point(win.screen?.x ?? 0, win.screen?.y ?? 0)
            live: true
        }
    }

    Component {
        id: stillGlass

        GlassSource {
            id: still

            readonly property var host: still.QsWindow.window ?? null

            source: win.frozen

            onHostChanged: still.host ? Backdrops.offer(still.host, still) : Backdrops.withdraw(still)
            Component.onCompleted: Backdrops.offer(still.host, still)
            Component.onDestruction: Backdrops.withdraw(still)
        }
    }

    Picker {
        anchors.fill: parent
        state: win.state
        screen: win.screen
    }
}
