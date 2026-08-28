pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import "vt.js" as Vt

// A terminal, drawn.
//
// The emulator next door (vt.js) has already turned the byte stream into rows;
// this is the part that puts them on screen and turns keys back into bytes. It
// knows nothing about files: hand it a terminal object and a way to send, and it
// is a terminal.
//
// ONE TEXT ITEM PER ROW, which is the same bargain CodeBlock makes and for the
// same reason. A cell-per-item grid is 80 x 40 = 3200 items rebuilt on every
// frame of output, and output arrives in bursts of dozens of frames; a row is
// one item and one layout, and a screenful is forty of them.
//
// The BACKGROUNDS are rectangles under the text rather than part of it, because
// Text.StyledText has no way to say a background at all. See vt.js's renderLine.
Item {
    id: root

    // The vt.js terminal being drawn.
    required property var term
    // Bumped by whoever feeds the terminal, because a JS object is not a QML
    // property and nothing here would otherwise know it had changed.
    required property int revision
    required property bool focused

    signal send(string bytes)
    signal resized(int cols, int rows)

    // HOW BIG A CHARACTER IS, measured rather than assumed. Everything else in
    // here is arithmetic on these two numbers: the grid size, the cursor's
    // position, where a background run starts. Monocraft is monospaced, so one
    // advance is every advance.
    readonly property real cellWidth: metrics.advanceWidth
    readonly property real cellHeight: Math.round(Appearance.font.size.small * 4 / 3)

    readonly property int cols: Math.max(1, Math.floor(width / Math.max(1, cellWidth)))
    readonly property int rows: Math.max(1, Math.floor(height / Math.max(1, cellHeight)))

    // HOW FAR BACK INTO HISTORY the view is looking, in rows. Zero is the live
    // screen, and any output snaps back to it: a terminal that stayed scrolled
    // up while a command was running would be a terminal that had stopped
    // showing you what you were doing.
    property int scrollOffset: 0

    // The rows currently on screen, recomputed when the terminal changes. Bound
    // to `revision` rather than watched, so one binding covers output, resize,
    // scrollback and the cursor moving.
    readonly property var lines: {
        void root.revision;
        return root.term ? root.term.view(root.scrollOffset) : [];
    }

    TextMetrics {
        id: metrics

        font.family: Appearance.font.family
        font.pixelSize: Appearance.font.size.small
        text: "0"
    }

    // ONLY WHILE THERE IS SOMETHING TO MEASURE. A hidden panel has no height, a
    // grid of no height is one row, and telling the shell it has one row is a
    // real instruction: anything it printed while the panel was shut would wrap
    // to a single line. The size is reported when the view can actually hold the
    // rows it is claiming.
    readonly property bool measurable: root.visible && root.height >= root.cellHeight && root.width >= root.cellWidth

    onColsChanged: if (root.measurable)
        root.resized(root.cols, root.rows)

    onRowsChanged: if (root.measurable)
        root.resized(root.cols, root.rows)

    // And once more when it becomes measurable again, because the change that
    // matters happened while nobody was allowed to report it.
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

                    text: row.modelData.markup
                    textFormat: Text.StyledText
                    // The terminal draws its own grid; the text must not try to
                    // help by breaking a long line somewhere else.
                    wrapMode: Text.NoWrap
                }
            }
        }
    }

    // THE CURSOR, and it is only drawn while this panel has the keyboard. A
    // block cursor sitting in an unfocused terminal claims the keystroke you are
    // about to type is going there, which is exactly the thing a multi-panel
    // window has to be honest about.
    Rectangle {
        visible: root.focused && root.term && root.term.cursorVisible && root.scrollOffset === 0

        x: root.term ? root.term.screen.x * root.cellWidth : 0
        y: root.term ? (root.term.screen.y + Math.min(root.scrollOffset, root.term.scrollback.length)) * root.cellHeight : 0
        width: root.cellWidth
        height: root.cellHeight

        color: Appearance.colour.accent
        opacity: 0.55
    }

    // WHICH CELL A POINT IS IN. Everything the mouse does is in cells; the
    // pixels stop here.
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

    // THE MOUSE, WHEN THE APPLICATION HAS ASKED FOR IT.
    //
    // Enabled only while a mouse mode is on, so a terminal showing a prompt does
    // not swallow presses that belong to the window around it - and so text
    // selection, when it exists, is not fighting an area that took the press
    // first.
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
            // A motion report every pixel is a report per pixel; the application
            // wants to know it entered a new CELL, and nothing finer exists as
            // far as it is concerned.
            if (at.col === root.lastCol && at.row === root.lastRow)
                return;
            root.lastCol = at.col;
            root.lastRow = at.row;
            root.send(root.term.mouseSequence(mouse.buttons === Qt.NoButton ? -1 : root.buttonOf(mouse.buttons), at.col, at.row, true, root.mods(mouse.modifiers), true));
        }
    }

    property int lastCol: -1
    property int lastRow: -1

    // Scrolling is by WHOLE ROWS, not by pixels, because a terminal is a grid
    // and half a row of it is not a thing you can look at. This is the one list
    // in the shell that does not glide (components/GlideList.qml): the content
    // under a smooth scroll would be redrawn from a different history offset
    // every frame, which is a repaint of every row to move the picture by two
    // pixels.
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

        onWheel: event => {
            if (!root.term)
                return;

            const notches = event.pixelDelta.y !== 0 ? event.pixelDelta.y / root.cellHeight : event.angleDelta.y / 40;
            const step = Math.round(notches);
            if (step === 0)
                return;

            // THREE ANSWERS, and picking the wrong one is why a wheel in a
            // terminal so often does nothing useful.
            //
            // An application that asked for the mouse gets the wheel as a mouse
            // button, which is what makes htop and tmux scroll.
            if (root.term.mouse) {
                const at = root.cellAt(event.x, event.y);
                for (let i = 0; i < Math.abs(step); i++)
                    root.send(root.term.wheelSequence(step > 0, at.col, at.row, root.mods(event.modifiers)));
                return;
            }

            // An application on the ALT SCREEN did not ask, but it is also not
            // showing history: there is nothing behind it to scroll back to. So
            // the wheel becomes arrow keys, which is the convention that makes
            // less, man and a pager built into anything scroll at all. Without
            // this the wheel moved OUR scrollback, which on the alt screen is
            // the shell's history from before the application started - the one
            // thing that is certainly not what was meant.
            if (root.term.altActive) {
                const key = step > 0 ? "up" : "down";
                for (let i = 0; i < Math.abs(step) * 3; i++)
                    root.send(Vt.keySequence(key, false, false, false, root.term.appCursor));
                return;
            }

            // And an ordinary prompt scrolls the history, which is ours.
            root.scrollOffset = Math.max(0, Math.min(root.term.scrollback.length, root.scrollOffset + step));
        }
    }

    // Any output brings the view back to the live screen.
    onRevisionChanged: root.scrollOffset = 0

    // ---------------------------------------------------------- the keyboard

    // Qt's key enum, as the names vt.js answers in. The enum stays on this side
    // because this is the file that has Qt in scope, and the vocabulary over
    // there stays readable; see the note over keySequence.
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

    // EVERY KEY GOES TO THE SHELL. That is the whole contract of this panel: no
    // interception, no exceptions, no "except Escape because it is convenient".
    // The window's own chords are taken before the event ever reaches here (see
    // modules/files/FilesFace.qml), and they are the only thing that is.
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

        // QT HAS USUALLY DONE CTRL ALREADY. `event.text` for Ctrl+C is the
        // control code itself, not "c", so running it through the control-code
        // rule a second time would turn ^C into something else entirely.
        // Anything already below 0x20 is passed through as it stands.
        const already = event.text.charCodeAt(0) < 0x20;
        root.send(already ? (alt ? `\x1b${event.text}` : event.text) : Vt.textSequence(event.text, alt, ctrl));
        event.accepted = true;
    }

    function paste(text: string): void {
        if (root.term)
            root.send(Vt.pasteSequence(text, root.term.bracketedPaste));
    }
}
