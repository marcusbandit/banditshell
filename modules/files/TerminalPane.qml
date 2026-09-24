pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

// THE SHELL, along the bottom.
//
// It is a panel with a real terminal in it, and the two things it adds to the
// view (components/TerminalView.qml) are the two things a panel has to do: be
// the right size, and say whether the keyboard is pointed at it.
//
// THE HEIGHT IS IN ROWS. A terminal's size is a character grid; a pixel height
// that did not divide by the line height would leave a strip of dead material
// under the last row and would make the shell's idea of the window and ours
// disagree by a fraction of a line. So the drag handle moves a ROW COUNT, and
// the pixels follow from it.
Item {
    id: root

    readonly property alias view: view
    readonly property bool focused: Files.focus === "terminal"

    // How tall, in rows. Starts at the configured height and is the thing the
    // handle actually changes.
    property int rows: Appearance.sizes.filesTerminalRows

    readonly property real chrome: handle.height + Appearance.padding.small * 2
    readonly property real bodyHeight: root.rows * view.cellHeight

    visible: Files.terminalOpen
    implicitHeight: visible ? root.bodyHeight + root.chrome : 0
    height: implicitHeight

    // NO ANIMATION ON THE HEIGHT. Ctrl+J is a key you press when you want to
    // type: the terminal has to be there, focused, on the frame you asked for
    // it, not a fifth of a second later while the panel is still growing under
    // the cursor.

    // THE TOP EDGE IS THE HANDLE, which is the same idea as every other edge in
    // this shell: the boundary between two things is what you grab to change how
    // much of each there is. Drawn as a hairline until it is hovered, so it is a
    // separator that turns out to be a control rather than a control sitting on
    // a separator.
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
                // Rows, from pixels, at the moment of the drag rather than by
                // accumulating: an integer row count derived from a running sum
                // of fractional pixels drifts, and the panel ends up a row away
                // from where the pointer is.
                const moved = Math.round(-resize.translation.y / view.cellHeight);
                root.rows = Math.max(2, Math.min(60, resize.startRows + moved));
            }
        }
    }

    // The focus ring. One hairline of the accent, on the panel that will receive
    // the next keystroke - which is the definition of state worth a colour.
    G2Rect {
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

    // A press anywhere in the panel points the keyboard at it. Not a focus
    // scope: the window routes every key itself (see FilesFace), so "focused"
    // here is a fact about where keys are being sent, not about Qt's focus
    // chain.
    TapHandler {
        onTapped: {
            Files.ensureTerminal();
            Files.focus = "terminal";
        }
    }
}
