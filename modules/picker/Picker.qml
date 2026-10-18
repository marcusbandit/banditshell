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
    property bool dragged: false
    property point origin: Qt.point(0, 0)
    property rect selection: Qt.rect(0, 0, 0, 0)

    readonly property real rx: selection.x
    readonly property real ry: selection.y
    readonly property real rw: selection.width
    readonly property real rh: selection.height

    readonly property real radius: onWindow ? Appearance.sizes.windowRadius : 0

    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.CrossCursor
    focus: true

    Keys.onEscapePressed: root.state.close()

    function windowAt(x: real, y: real): var {
        const px = x + root.screen.x;
        const py = y + root.screen.y;
        const hit = Hypr.clientsOn(root.screen).map(client => client.lastIpcObject).find(o => {
            if (!o?.at || !o?.size)
                return false;
            const dx = px - o.at[0];
            const dy = py - o.at[1];
            return dx >= 0 && dy >= 0 && dx <= o.size[0] && dy <= o.size[1];
        });
        return hit ? Qt.rect(hit.at[0] - root.screen.x, hit.at[1] - root.screen.y, hit.size[0], hit.size[1]) : null;
    }

    function hover(x: real, y: real): void {
        const win = root.windowAt(x, y);
        root.onWindow = win !== null;
        root.selection = win ?? Qt.rect(x, y, 0, 0);
    }

    function span(x: real, y: real): void {
        root.onWindow = false;
        root.selection = Qt.rect(Math.min(root.origin.x, x), Math.min(root.origin.y, y), Math.abs(x - root.origin.x), Math.abs(y - root.origin.y));
    }

    function commit(): void {
        root.state.capture(root.screen, Math.round(root.rx), Math.round(root.ry), Math.round(root.rw), Math.round(root.rh));
    }

    onEntered: root.hover(root.mouseX, root.mouseY)

    Component.onCompleted: {
        if (root.containsMouse)
            root.hover(root.mouseX, root.mouseY);
    }

    onPressed: event => {
        root.hover(event.x, event.y);
        root.origin = Qt.point(event.x, event.y);
        root.dragged = false;
    }

    onPositionChanged: event => {
        if (!root.pressed)
            return root.hover(event.x, event.y);

        if (!root.dragged && Math.abs(event.x - root.origin.x) + Math.abs(event.y - root.origin.y) < Config.values.control.dragThreshold)
            return;

        root.dragged = true;
        root.span(event.x, event.y);
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

            color: tone.value

            FollowColour {
                id: tone

                target: cancel.containsMouse ? Appearance.colour.fill : Appearance.colour.surface
                speed: Appearance.animation.revealSpeed
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
