pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components.blob
import qs.components
import qs.services
import "picker-place.js" as Place

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
        if (!hit)
            return null;
        const r = Place.clampRect(hit.at[0] - root.screen.x, hit.at[1] - root.screen.y, hit.size[0], hit.size[1], root.width, root.height);
        return Qt.rect(r.x, r.y, r.width, r.height);
    }

    function hover(x: real, y: real): void {
        const win = root.windowAt(x, y);
        root.onWindow = win !== null;
        root.selection = win ?? Qt.rect(x, y, 0, 0);
    }

    function span(x: real, y: real): void {
        root.onWindow = false;
        const r = Place.span(root.origin.x, root.origin.y, x, y, root.width, root.height);
        root.selection = Qt.rect(r.x, r.y, r.width, r.height);
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

    Follow {
        id: dim

        target: root.rw > 0 && root.rh > 0 ? 1 : 0
        speed: Appearance.animation.revealSpeed
    }

    BlobField {
        anchors.fill: parent

        colour: Appearance.withAlpha(Appearance.colour.scrim, Appearance.colour.scrim.a * dim.value)
        content: Qt.vector4d(root.rx, root.ry, root.rw, root.rh)
        baseRadius: Qt.vector4d(root.radius, root.radius, root.radius, root.radius)
        gap: 0
        band: 0
        frameOn: 0
        smoothing: 0

        outlineWidth: Appearance.sizes.pickerOutline
        outlineColour: Appearance.withAlpha(Appearance.colour.chosen, dim.value)
    }

    GlassPanel {
        id: readout

        readonly property var at: Place.readoutAt(root.selection, readout.width, readout.height, root.width, root.height, Appearance.padding.normal)

        x: readout.at.x
        y: readout.at.y
        width: facts.implicitWidth + Appearance.padding.large * 2
        height: Math.max(Appearance.sizes.minTarget, facts.implicitHeight + Appearance.padding.normal * 2)
        pill: "object"
        opacity: dim.value
        visible: readout.opacity > 0

        SquircleRect {
            anchors.fill: parent
            pill: "object"
            color: Appearance.colour.chosen
            opacity: pressedLook.value
        }

        Follow {
            id: pressedLook

            target: cancel.containsMouse ? 1 : 0
            speed: Appearance.animation.revealSpeed
        }

        Row {
            id: facts

            anchors.centerIn: parent
            spacing: Appearance.padding.normal

            StyledText {
                text: `${Math.round(root.rw)} x ${Math.round(root.rh)}`
                font.pixelSize: Appearance.font.size.small
                color: Appearance.blend(Appearance.colour.text, Appearance.colour.onChosen, pressedLook.value)
            }

            StyledText {
                text: root.onWindow ? "window" : "region"
                font.pixelSize: Appearance.font.size.small
                color: Appearance.blend(Appearance.colour.textDim, Appearance.colour.onChosen, pressedLook.value)
            }

            StyledText {
                text: root.state.clipboardOnly ? "to clipboard" : "to editor"
                font.pixelSize: Appearance.font.size.small
                color: Appearance.blend(Appearance.colour.textDim, Appearance.colour.onChosen, pressedLook.value)
            }
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
