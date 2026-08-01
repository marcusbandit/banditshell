pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.components.blob
import qs.components
import qs.services

// Area selection, over one screen.
//
// Two gestures, and hovering is the first of them: with nothing pressed the
// selection SNAPS to whatever window is under the cursor, so the common case
// (capture that window) is a hover and a click rather than a careful drag along
// four edges. Press and drag for a free region. This is caelestia's model, and
// it is the right one.
//
// The dim outside the selection reuses the chassis's own field, so the selection
// gets the compositor's corner curve for free and matches the window it is
// snapped to instead of approximating it.
MouseArea {
    id: root

    required property PickerState state
    required property ShellScreen screen

    // True while the selection is locked to a window rather than freely dragged.
    property bool onWindow: false

    property real pressX: 0
    property real pressY: 0

    property real sx: 0
    property real sy: 0
    property real ex: 0
    property real ey: 0

    readonly property real rx: Math.min(sx, ex)
    readonly property real ry: Math.min(sy, ey)
    readonly property real rw: Math.abs(sx - ex)
    readonly property real rh: Math.abs(sy - ey)

    // A window's own corner when snapped to one, square when free: a free region
    // is a crop, and a crop with rounded corners would be a lie about what the
    // file will contain.
    readonly property real radius: onWindow ? Appearance.sizes.windowRadius : 0

    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.CrossCursor
    focus: true

    Keys.onEscapePressed: root.state.close()

    function snapTo(x: real, y: real): void {
        for (const client of Hypr.clientsOn(root.screen)) {
            const at = client.lastIpcObject.at;
            const size = client.lastIpcObject.size;
            const cx = at[0] - root.screen.x;
            const cy = at[1] - root.screen.y;
            if (x >= cx && y >= cy && x <= cx + size[0] && y <= cy + size[1]) {
                root.onWindow = true;
                root.sx = cx;
                root.sy = cy;
                root.ex = cx + size[0];
                root.ey = cy + size[1];
                return;
            }
        }
    }

    Component.onCompleted: {
        // Start on whatever is under the cursor, so the first thing you see is
        // the answer you probably wanted.
        snapTo(mouseX, mouseY);
        if (!onWindow) {
            sx = width / 2 - 100;
            sy = height / 2 - 100;
            ex = width / 2 + 100;
            ey = height / 2 + 100;
        }
    }

    onPressed: event => {
        root.pressX = event.x;
        root.pressY = event.y;
    }

    onPositionChanged: event => {
        if (!pressed)
            return root.snapTo(event.x, event.y);

        // Past the drag threshold this stops being a click on a window and
        // becomes a free region.
        if (Math.abs(event.x - root.pressX) + Math.abs(event.y - root.pressY) < Appearance.sizes.dragThreshold)
            return;

        root.onWindow = false;
        root.sx = root.pressX;
        root.sy = root.pressY;
        root.ex = event.x;
        root.ey = event.y;
    }

    onReleased: {
        if (root.rw < 2 || root.rh < 2)
            return root.state.close();
        root.state.capture(root.screen, Math.round(root.rx), Math.round(root.ry), Math.round(root.rw), Math.round(root.rh));
    }

    // The frozen frame, when the picker was opened in freeze mode. Underneath
    // everything, so the dim and the selection sit on top of it exactly as they
    // would over the live screen.
    Image {
        anchors.fill: parent
        visible: root.state.frozenPath !== ""
        source: root.state.frozenPath ? `file://${root.state.frozenPath}` : ""
        fillMode: Image.Stretch
        cache: false
    }

    // Everything except the selection, dimmed. The chassis's own field: give it
    // the selection as its content area and no band, and what it draws is the
    // hole's complement with the right corner curve.
    BlobField {
        anchors.fill: parent

        colour: Appearance.colour.scrim
        content: Qt.vector4d(root.rx, root.ry, root.rw, root.rh)
        baseRadius: Qt.vector4d(root.radius, root.radius, root.radius, root.radius)
        gap: 0
        band: 0
        frameOn: false
        smoothing: 0
        // The selection is a hard edge, not a melt: it has to say exactly where
        // the crop will be.
        outlineWidth: Appearance.sizes.pickerOutline
        outlineColour: Appearance.colour.accent
    }

    // What it will do, where you are looking. Follows the selection rather than
    // sitting in a corner, because a hint you have to go and find is not a hint.
    Item {
        x: Math.min(root.width - width, Math.max(0, root.rx + root.rw / 2 - width / 2))
        y: root.ry + root.rh + Appearance.padding.normal > root.height - hint.height ? root.ry - height - Appearance.padding.normal : root.ry + root.rh + Appearance.padding.normal

        implicitWidth: hint.implicitWidth + Appearance.padding.large * 2
        implicitHeight: hint.implicitHeight + Appearance.padding.normal * 2
        width: implicitWidth
        height: implicitHeight

        G2Rect {
            anchors.fill: parent
            radius: Appearance.rounding.normal
            color: Appearance.colour.surface
        }

        StyledText {
            id: hint

            anchors.centerIn: parent
            text: `${root.rw} x ${root.rh}   ${root.onWindow ? "window" : "region"}   ${root.state.clipboardOnly ? "to clipboard" : "to editor"}   esc cancels`
            font.pixelSize: Appearance.font.size.small
            color: Appearance.colour.textDim
        }
    }
}
