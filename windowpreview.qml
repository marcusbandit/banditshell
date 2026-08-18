import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.config
import qs.components
import qs.modules.windows
import qs.services

// Temporary: the window-edge gesture's held state, frozen.
//
// The gesture is touch-only and cannot be made with a mouse, so this is the only
// way to look at what it draws. It alternates between the two answers a hold
// offers: the finger down among the windows (rearrange) and the finger up at the
// top (send elsewhere). See modules/windows/.
ShellRoot {
    id: shell

    // The model only fills `lastIpcObject` when something asks it to, and in the
    // real shell an event does that every few seconds. A preview process has no
    // events, so it asks once.
    Component.onCompleted: Hyprland.refreshToplevels()

    PanelWindow {
        id: win

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
        WlrLayershell.namespace: "banditshell-windowpreview"

        mask: Region {
            width: 0
            height: 0
        }

        // The chassis's hole, spelled out here rather than imported: this is a
        // preview, not the shell.
        readonly property real band: Appearance.sizes.border
        readonly property real bar: band + Appearance.sizes.sidebarWidth
        readonly property real holeX: bar
        readonly property real holeY: band
        readonly property real holeWidth: win.width - bar - band
        readonly property real holeHeight: win.height - band * 2

        // Whichever window is furthest right stands in for the one in the hand.
        readonly property var carried: {
            let best = null;
            for (const c of Hypr.clientsOn(win.screen)) {
                const o = c.lastIpcObject;
                if (!o?.at || !o?.size)
                    continue;
                if (!best || o.at[0] > best.lastIpcObject.at[0])
                    best = c;
            }
            return best;
        }

        readonly property string carriedAddr: {
            const raw = win.carried?.lastIpcObject?.address ?? "";
            return raw.startsWith("0x") ? raw : `0x${raw}`;
        }

        readonly property real cardW: win.carried ? win.carried.lastIpcObject.size[0] * slots.mapScale : 400
        readonly property real cardH: win.carried ? win.carried.lastIpcObject.size[1] * slots.mapScale : 250

        // 0: the hand down among the windows. 1: the hand up at the top.
        property int phase: 0

        Timer {
            interval: 4000
            running: true
            repeat: true
            onTriggered: win.phase = 1 - win.phase
        }

        readonly property rect firstSlot: slots.windows.length > 0 ? slots.slotRect(0) : Qt.rect(0, 0, 0, 0)
        readonly property real fingerX: win.phase === 0 ? win.firstSlot.x + win.firstSlot.width / 2 : shelf.plateCentre(2).x
        readonly property real fingerY: win.phase === 0 ? win.firstSlot.y + win.firstSlot.height / 2 : shelf.plateCentre(2).y

        Rectangle {
            anchors.fill: parent
            color: Appearance.colour.surface
        }

        LayoutSlots {
            id: slots

            anchors.fill: parent

            screen: win.screen
            heldAddr: win.carriedAddr

            holeX: win.holeX
            holeY: win.holeY + shelf.dockedHeight
            holeWidth: win.holeWidth
            holeHeight: win.holeHeight - shelf.dockedHeight
            mode: "move"

            pointX: win.fingerX
            pointY: win.fingerY
            active: win.phase === 0
        }

        WorkspaceShelf {
            id: shelf

            anchors.fill: parent

            holeX: win.holeX
            holeY: win.holeY
            holeWidth: win.holeWidth
            holeHeight: win.holeHeight
            aspect: win.height / win.width

            pointX: win.fingerX
            pointY: win.fingerY
            active: true
        }

        // The card, at the size the lift ends at, hanging off the finger.
        G2Rect {
            id: card

            x: win.fingerX - width / 2
            y: win.fingerY - height
            width: win.cardW
            height: win.cardH

            radius: Appearance.sizes.windowRadius * slots.mapScale
            color: Appearance.colour.surface
            stroke: Appearance.colour.fillStronger
            strokeWidth: Appearance.font.stem

            WindowView {
                anchors.fill: parent

                window: win.carried
                radius: card.radius
                live: false
            }
        }
    }
}
