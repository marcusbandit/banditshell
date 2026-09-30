pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root

    readonly property alias view: view
    readonly property bool focused: Files.focus === "terminal"

    property int rows: Appearance.sizes.filesTerminalRows

    readonly property real chrome: handle.height + Appearance.padding.small * 2
    readonly property real bodyHeight: root.rows * view.cellHeight

    visible: Files.terminalOpen
    implicitHeight: visible ? root.bodyHeight + root.chrome : 0
    height: implicitHeight

    Item {
        id: handle

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top

        height: Appearance.sizes.minTarget

        Rectangle {
            anchors.centerIn: parent

            width: grip.hovered || resize.active ? parent.width * 0.08 : parent.width
            height: Appearance.font.stem
            radius: height / 2
            color: grip.hovered || resize.active ? Appearance.colour.text : Appearance.colour.separator

            Behavior on width {
                NumberAnimation {
                    duration: Appearance.anim.fast
                    easing.type: Easing.OutQuad
                }
            }
        }

        HoverHandler {
            id: grip

            cursorShape: Qt.SizeVerCursor
        }

        DragHandler {
            id: resize

            target: null
            yAxis.enabled: true
            xAxis.enabled: false

            property int startRows: 0

            onActiveChanged: if (active)
                resize.startRows = root.rows

            onTranslationChanged: {
                if (!active)
                    return;

                const moved = Math.round(-resize.translation.y / view.cellHeight);
                root.rows = Math.max(2, Math.min(60, resize.startRows + moved));
            }
        }
    }

    SquircleRect {
        anchors.fill: parent
        anchors.topMargin: handle.height

        radius: Appearance.rounding.small
        stroke: root.focused ? Appearance.colour.accent : "transparent"
        strokeWidth: root.focused ? Appearance.font.stem : 0

    }

    TerminalView {
        id: view

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: handle.bottom
        anchors.bottom: parent.bottom
        anchors.margins: Appearance.padding.small

        clip: true

        term: Files.term
        revision: Files.revision
        focused: root.focused

        onSend: bytes => Files.send(bytes)
        onResized: (cols, rows) => Files.resizeTerminal(cols, rows)
    }

    TapHandler {
        onTapped: {
            Files.ensureTerminal();
            Files.focus = "terminal";
        }
    }
}
