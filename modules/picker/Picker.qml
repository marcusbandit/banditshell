pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components.blob
import qs.components
import qs.services

MouseArea {
    id: root

    required property PickerState state
    required property ShellScreen screen

    property bool onWindow: false

    property real pressX: 0
    property real pressY: 0

    property bool dragged: false

    property real sx: 0
    property real sy: 0
    property real ex: 0
    property real ey: 0

    readonly property real rx: Math.min(sx, ex)
    readonly property real ry: Math.min(sy, ey)
    readonly property real rw: Math.abs(sx - ex)
    readonly property real rh: Math.abs(sy - ey)

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

    function commit(): void {
        root.state.capture(root.screen, Math.round(root.rx), Math.round(root.ry), Math.round(root.rw), Math.round(root.rh));
    }

    onEntered: root.snapTo(root.mouseX, root.mouseY)

    Component.onCompleted: {
        if (root.containsMouse)
            root.snapTo(root.mouseX, root.mouseY);
    }

    onPressed: event => {

        root.snapTo(event.x, event.y);

        root.pressX = event.x;
        root.pressY = event.y;

        root.dragged = false;
    }

    onPositionChanged: event => {
        if (!root.pressed)
            return root.snapTo(event.x, event.y);

        if (Math.abs(event.x - root.pressX) + Math.abs(event.y - root.pressY) < Appearance.sizes.dragThreshold)
            return;

        root.dragged = true;
        root.onWindow = false;
        root.sx = root.pressX;
        root.sy = root.pressY;
        root.ex = event.x;
        root.ey = event.y;
    }

    onReleased: {

        if (root.dragged) {
            if (root.rw < 2 || root.rh < 2)
                return root.state.close();
            return root.commit();
        }

        if (root.onWindow)
            return root.commit();

        root.state.close();
    }

    Image {
        id: frozen

        readonly property string path: root.state.frozenByScreen[root.screen.name] ?? ""

        anchors.fill: parent
        visible: frozen.path !== ""
        source: frozen.path ? `file://${frozen.path}` : ""
        fillMode: Image.Stretch
        cache: false
    }

    BlobField {
        anchors.fill: parent

        colour: Appearance.colour.scrim
        content: Qt.vector4d(root.rx, root.ry, root.rw, root.rh)
        baseRadius: Qt.vector4d(root.radius, root.radius, root.radius, root.radius)
        gap: 0
        band: 0
        frameOn: 0
        smoothing: 0

        outlineWidth: Appearance.sizes.pickerOutline
        outlineColour: Appearance.colour.accent
    }

    Item {
        id: readout

        x: Math.min(root.width - width, Math.max(0, root.rx + root.rw / 2 - width / 2))

        y: root.ry + root.rh + Appearance.padding.normal > root.height - readout.height ? root.ry - height - Appearance.padding.normal : root.ry + root.rh + Appearance.padding.normal

        implicitWidth: hint.implicitWidth + Appearance.padding.large * 2

        implicitHeight: Math.max(Appearance.sizes.minTarget, hint.implicitHeight + Appearance.padding.normal * 2)
        width: implicitWidth
        height: implicitHeight

        SquircleRect {
            anchors.fill: parent
            radius: Appearance.rounding.normal

            color: cancel.containsMouse ? Appearance.colour.fill : Appearance.colour.surface

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }

        StyledText {
            id: hint

            anchors.centerIn: parent
            text: `${root.rw} x ${root.rh}   ${root.onWindow ? "window" : "region"}   ${root.state.clipboardOnly ? "to clipboard" : "to editor"}   tap here or esc to cancel`
            font.pixelSize: Appearance.font.size.small
            color: Appearance.colour.textDim
        }

        MouseArea {
            id: cancel

            anchors.fill: parent
            hoverEnabled: true

            cursorShape: Qt.PointingHandCursor
            onClicked: root.state.close()
        }
    }
}
