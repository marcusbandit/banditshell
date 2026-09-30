pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import "vt.js" as Vt

Item {
    id: root

    required property var term

    required property int revision
    required property bool focused

    signal send(string bytes)
    signal resized(int cols, int rows)

    readonly property real cellWidth: metrics.advanceWidth
    readonly property real cellHeight: Math.round(Appearance.sizes.filesText * 4 / 3)

    readonly property int cols: Math.max(1, Math.floor(width / Math.max(1, cellWidth)))
    readonly property int rows: Math.max(1, Math.floor(height / Math.max(1, cellHeight)))

    property int scrollOffset: 0

    readonly property var lines: {
        void root.revision;
        return root.term ? root.term.view(root.scrollOffset) : [];
    }

    readonly property string face: Appearance.sizes.filesTerminalFont

    TextMetrics {
        id: metrics

        font.family: root.face
        font.pixelSize: Appearance.sizes.filesText
        text: "0"
    }

    readonly property bool measurable: root.visible && root.height >= root.cellHeight && root.width >= root.cellWidth

    onColsChanged: if (root.measurable)
        root.resized(root.cols, root.rows)

    onRowsChanged: if (root.measurable)
        root.resized(root.cols, root.rows)

    onMeasurableChanged: if (root.measurable)
        root.resized(root.cols, root.rows)

    Column {
        id: grid

        anchors.left: parent.left
        anchors.top: parent.top
        width: parent.width

        Repeater {
            model: root.lines

            delegate: Item {
                id: row

                required property int index
                required property var modelData

                width: grid.width
                height: root.cellHeight

                Repeater {
                    model: row.modelData.runs

                    delegate: Rectangle {
                        required property var modelData

                        x: modelData.x * root.cellWidth
                        width: modelData.len * root.cellWidth
                        height: row.height
                        color: modelData.colour
                    }
                }

                StyledText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter

                    font.family: root.face
                    font.pixelSize: Appearance.sizes.filesText

                    renderType: Text.QtRendering

                    text: row.modelData.markup
                    textFormat: Text.StyledText

                    wrapMode: Text.NoWrap
                }
            }
        }
    }

    Rectangle {
        visible: root.focused && root.term && root.term.cursorVisible && root.scrollOffset === 0

        x: root.term ? root.term.screen.x * root.cellWidth : 0
        y: root.term ? (root.term.screen.y + Math.min(root.scrollOffset, root.term.scrollback.length)) * root.cellHeight : 0
        width: root.cellWidth
        height: root.cellHeight

        color: Appearance.colour.accent
        opacity: 0.55
    }

    function cellAt(x: real, y: real): var {
        return {
            col: Math.max(0, Math.min(root.cols - 1, Math.floor(x / Math.max(1, root.cellWidth)))),
            row: Math.max(0, Math.min(root.rows - 1, Math.floor(y / Math.max(1, root.cellHeight))))
        };
    }

    function mods(modifiers: int): var {
        return {
            shift: (modifiers & Qt.ShiftModifier) !== 0,
            alt: (modifiers & Qt.AltModifier) !== 0,
            ctrl: (modifiers & Qt.ControlModifier) !== 0
        };
    }

    function buttonOf(button: int): int {
        if (button === Qt.RightButton)
            return 2;
        if (button === Qt.MiddleButton)
            return 1;
        return 0;
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.term && root.term.mouse !== 0
        visible: enabled
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        hoverEnabled: root.term && root.term.mouse === 1003

        onPressed: mouse => {
            const at = root.cellAt(mouse.x, mouse.y);
            root.send(root.term.mouseSequence(root.buttonOf(mouse.button), at.col, at.row, true, root.mods(mouse.modifiers), false));
        }

        onReleased: mouse => {
            const at = root.cellAt(mouse.x, mouse.y);
            root.send(root.term.mouseSequence(root.buttonOf(mouse.button), at.col, at.row, false, root.mods(mouse.modifiers), false));
        }

        onPositionChanged: mouse => {
            const at = root.cellAt(mouse.x, mouse.y);

            if (at.col === root.lastCol && at.row === root.lastRow)
                return;
            root.lastCol = at.col;
            root.lastRow = at.row;
            root.send(root.term.mouseSequence(mouse.buttons === Qt.NoButton ? -1 : root.buttonOf(mouse.buttons), at.col, at.row, true, root.mods(mouse.modifiers), true));
        }
    }

    property int lastCol: -1
    property int lastRow: -1

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

        onWheel: event => {
            if (!root.term)
                return;

            const notches = event.pixelDelta.y !== 0 ? event.pixelDelta.y / root.cellHeight : event.angleDelta.y / 40;
            const step = Math.round(notches);
            if (step === 0)
                return;

            if (root.term.mouse) {
                const at = root.cellAt(event.x, event.y);
                for (let i = 0; i < Math.abs(step); i++)
                    root.send(root.term.wheelSequence(step > 0, at.col, at.row, root.mods(event.modifiers)));
                return;
            }

            if (root.term.altActive) {
                const key = step > 0 ? "up" : "down";
                for (let i = 0; i < Math.abs(step) * 3; i++)
                    root.send(Vt.keySequence(key, false, false, false, root.term.appCursor));
                return;
            }

            root.scrollOffset = Math.max(0, Math.min(root.term.scrollback.length, root.scrollOffset + step));
        }
    }

    onRevisionChanged: root.scrollOffset = 0

    readonly property var keyNames: ({
            [Qt.Key_Up]: "up",
            [Qt.Key_Down]: "down",
            [Qt.Key_Left]: "left",
            [Qt.Key_Right]: "right",
            [Qt.Key_Home]: "home",
            [Qt.Key_End]: "end",
            [Qt.Key_PageUp]: "pageup",
            [Qt.Key_PageDown]: "pagedown",
            [Qt.Key_Insert]: "insert",
            [Qt.Key_Delete]: "delete",
            [Qt.Key_Return]: "return",
            [Qt.Key_Enter]: "enter",
            [Qt.Key_Backspace]: "backspace",
            [Qt.Key_Tab]: "tab",
            [Qt.Key_Backtab]: "tab",
            [Qt.Key_Escape]: "escape",
            [Qt.Key_F1]: "f1",
            [Qt.Key_F2]: "f2",
            [Qt.Key_F3]: "f3",
            [Qt.Key_F4]: "f4",
            [Qt.Key_F5]: "f5",
            [Qt.Key_F6]: "f6",
            [Qt.Key_F7]: "f7",
            [Qt.Key_F8]: "f8",
            [Qt.Key_F9]: "f9",
            [Qt.Key_F10]: "f10",
            [Qt.Key_F11]: "f11",
            [Qt.Key_F12]: "f12"
        })

    function key(event: var): void {
        if (!root.term)
            return;

        const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
        const alt = (event.modifiers & Qt.AltModifier) !== 0;
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;

        const name = root.keyNames[event.key];
        if (name) {
            const bytes = Vt.keySequence(name, event.key === Qt.Key_Backtab || shift, alt, ctrl, root.term.appCursor);
            if (bytes) {
                root.send(bytes);
                event.accepted = true;
            }
            return;
        }

        if (!event.text || event.text.length === 0)
            return;

        const already = event.text.charCodeAt(0) < 0x20;
        root.send(already ? (alt ? `\x1b${event.text}` : event.text) : Vt.textSequence(event.text, alt, ctrl));
        event.accepted = true;
    }

    function paste(text: string): void {
        if (root.term)
            root.send(Vt.pasteSequence(text, root.term.bracketedPaste));
    }
}
