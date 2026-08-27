pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import qs.config
import qs.components
import qs.services

// THE WINDOW'S INSIDE: four panels, one keyboard, and the rules for who gets it.
//
// This file exists to be the ONE place that routes a keystroke, and that is
// worth saying plainly because the obvious alternative - each panel handling its
// own keys - is what makes multi-panel windows feel arbitrary. A key here is
// answered in exactly three steps, in order:
//
//   1. IS IT A BOUND CHORD? Those are read whatever has focus, and they are the
//      only thing in the window that can take a key away from a panel. Only
//      chords actually IN the map are taken, which is what leaves Ctrl+C,
//      Ctrl+R and Ctrl+D to the shell.
//   2. IS THE TERMINAL FOCUSED? Then it gets the key. All of it. No exceptions,
//      no "except Escape", no "except the arrows": a terminal that swallows
//      three keys for the convenience of the window around it is a terminal you
//      cannot trust with the fourth.
//   3. OTHERWISE IT IS THE GRID'S, where there is no shell waiting for it and
//      vim's vocabulary is free to mean what it means.
//
// The focus itself is drawn, once, as a hairline of the accent around whichever
// panel has it. That is state worth a colour by DESIGN.md's own test: it decides
// where the next thing you type is going.
Item {
    id: root

    focus: true

    // ---------------------------------------------------------- the chords

    // Qt's key enum as the words a keymap is written in. Letters and digits ARE
    // their key codes (Qt.Key_A is 0x41), so only the named keys need listing.
    readonly property var keyNames: ({
            [Qt.Key_Left]: "Left",
            [Qt.Key_Right]: "Right",
            [Qt.Key_Up]: "Up",
            [Qt.Key_Down]: "Down",
            [Qt.Key_Home]: "Home",
            [Qt.Key_End]: "End",
            [Qt.Key_PageUp]: "PageUp",
            [Qt.Key_PageDown]: "PageDown",
            [Qt.Key_Space]: "Space",
            [Qt.Key_Tab]: "Tab",
            [Qt.Key_Return]: "Return",
            [Qt.Key_Enter]: "Return",
            [Qt.Key_Backspace]: "Backspace",
            [Qt.Key_Delete]: "Delete",
            [Qt.Key_Escape]: "Escape"
        })

    function keyLabel(key: int): string {
        if (root.keyNames[key])
            return root.keyNames[key];
        if (key >= Qt.Key_A && key <= Qt.Key_Z || key >= Qt.Key_0 && key <= Qt.Key_9)
            return String.fromCharCode(key);
        return "";
    }

    // The chord as the string a keymap spells it with. Modifiers in a fixed
    // order, so "Ctrl+Alt+J" is one spelling rather than two that only one of
    // which is ever found.
    function chordOf(event: var): string {
        const parts = [];
        if (event.modifiers & Qt.ControlModifier)
            parts.push("Ctrl");
        if (event.modifiers & Qt.AltModifier)
            parts.push("Alt");
        if (event.modifiers & Qt.ShiftModifier)
            parts.push("Shift");
        if (parts.length === 0)
            return "";

        const label = root.keyLabel(event.key);
        if (!label)
            return "";
        parts.push(label);
        return parts.join("+");
    }

    // THE MODIFIER, WATCHED. Held on its own it is a question ("what does Ctrl
    // do here"); held as part of a chord it is not, so the first real key takes
    // the hints back down.
    Keys.onReleased: event => {
        if (event.key === Qt.Key_Control || event.key === Qt.Key_Alt || event.key === Qt.Key_Meta)
            hints.held = "";
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Control) {
            hints.held = "Ctrl";
            return;
        }
        if (event.key === Qt.Key_Alt) {
            hints.held = "Alt";
            return;
        }
        hints.held = "";

        // 1. The window's own.
        const chord = root.chordOf(event);
        if (chord && Files.chords[chord] !== undefined) {
            event.accepted = Files.act(Files.chords[chord]);
            if (event.accepted)
                return;
        }

        // 2. The shell's, if it is the one being typed at.
        if (Files.focus === "terminal" && Files.terminalOpen) {
            terminal.view.key(event);
            return;
        }

        // 3. The grid's.
        root.gridKey(event);
    }

    // The bare-key layer, live only while the grid has the keyboard.
    function gridKey(event: var): void {
        // The arrows and Return are handled as themselves rather than through
        // the keymap, so a map emptied out still leaves the grid navigable.
        switch (event.key) {
        case Qt.Key_Left:
            root.move(-1);
            event.accepted = true;
            return;
        case Qt.Key_Right:
            root.move(1);
            event.accepted = true;
            return;
        case Qt.Key_Up:
            root.move(-grid.columns);
            event.accepted = true;
            return;
        case Qt.Key_Down:
            root.move(grid.columns);
            event.accepted = true;
            return;
        case Qt.Key_PageUp:
            root.move(-grid.columns * 3);
            event.accepted = true;
            return;
        case Qt.Key_PageDown:
            root.move(grid.columns * 3);
            event.accepted = true;
            return;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            Files.open(Files.current);
            event.accepted = true;
            return;
        case Qt.Key_Backspace:
            Files.go(Files.parentOf(Files.cwd));
            event.accepted = true;
            return;
        case Qt.Key_Escape:
            if (Files.search) {
                Files.search = "";
                event.accepted = true;
            }
            return;
        }

        const action = Files.gridKeys[event.text];
        if (action)
            event.accepted = root.gridAct(action);
    }

    function gridAct(action: string): bool {
        switch (action) {
        case "left":
            root.move(-1);
            return true;
        case "right":
            root.move(1);
            return true;
        case "up":
            root.move(-grid.columns);
            return true;
        case "down":
            root.move(grid.columns);
            return true;
        case "first":
            root.select(0);
            return true;
        case "last":
            root.select(Files.visible.length - 1);
            return true;
        case "open":
            Files.open(Files.current);
            return true;
        case "search":
            Files.searching = true;
            return true;
        case "copy":
            if (Files.currentPath)
                copier.exec(["wl-copy", "--", Files.currentPath]);
            return true;
        }

        // Anything left is a window action rather than a grid one, and the
        // service owns those: the same names have to mean the same things
        // whether they were reached by a chord or by a bare key.
        return Files.act(action);
    }

    function select(index: int): void {
        if (Files.visible.length === 0)
            return;
        Files.selected = Math.max(0, Math.min(index, Files.visible.length - 1));
        grid.reveal(Files.selected);
    }

    function move(delta: int): void {
        root.select(Math.max(0, Files.selected) + delta);
    }

    Process {
        id: copier
    }

    // ---------------------------------------------------------- the layout

    PathBar {
        id: path

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Appearance.padding.normal

        receiving: root.dragging ? path.crumbAt(root.dragAt) : -1
    }

    Separator {
        id: rule

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: path.bottom
    }

    // THE GRID AND THE PREVIEW, side by side. The preview's width is the
    // configured one, except on a window too narrow to hold both, where the grid
    // wins: a grid squeezed to one column is not a grid, and a preview is the
    // half you can put away with a chord.
    Item {
        id: middle

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: rule.bottom
        anchors.bottom: terminal.top

        readonly property bool roomForBoth: width > Appearance.sizes.filesPreview * 2

        FileGrid {
            id: grid

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: preview.visible ? preview.left : parent.right
            anchors.margins: Appearance.padding.small

            entries: Files.visible
            selected: Files.selected
            dragging: root.dragging
            dragPoint: root.dragging ? grid.mapFromItem(root, root.dragAt.x, root.dragAt.y) : Qt.point(-1, -1)

            onPicked: index => {
                Files.selected = index;
                Files.focus = "grid";
            }
            onActivated: index => Files.open(Files.visible[index])
            onLifted: (index, position) => {
                Files.selected = index;
                root.dragging = true;
                root.dragAt = root.mapFromItem(null, position.x, position.y);
                followX.snap();
                followY.snap();
            }
            onDragged: position => root.dragAt = root.mapFromItem(null, position.x, position.y)
            onDropped: position => root.drop(root.mapFromItem(null, position.x, position.y))
        }

        PreviewPane {
            id: preview

            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: Appearance.padding.normal

            width: Appearance.sizes.filesPreview
            visible: Files.previewOpen && middle.roomForBoth && !!Files.current

            entry: Files.current
            path: Files.currentPath
        }
    }

    TerminalPane {
        id: terminal

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
    }

    // ---------------------------------------------------------- the drag

    // WHAT IS BEING DRAGGED AND WHERE THE POINTER IS. Held here rather than in
    // the grid because the drop targets are in two different panels - a folder
    // tile and a breadcrumb - and a drag that only one of them could see would
    // be a drag you could not take upwards.
    property bool dragging: false
    property point dragAt: Qt.point(0, 0)

    function drop(position: point): void {
        root.dragging = false;
        if (!Files.current)
            return;

        // A crumb first, because the path bar sits over the grid's top edge and
        // aiming at a parent directory should not be able to hit a file behind
        // it.
        const crumb = path.pathAt(path.mapFromItem(root, position.x, position.y));
        if (crumb) {
            Files.move(Files.currentPath, crumb);
            return;
        }

        const local = grid.mapFromItem(root, position.x, position.y);
        const index = grid.dropIndexAt(local);
        if (index < 0 || index === Files.selected)
            return;

        const target = Files.visible[index];
        if (target && target.kind === "dir" && target.open)
            Files.move(Files.currentPath, Files.join(Files.cwd, target.name));
    }

    // THE GHOST. It follows the pointer by exponential smoothing rather than
    // being pinned to it, so the thing you are dragging has weight
    // (~/.claude/rules/animation-smoothing.md): it trails slightly when you move
    // fast and settles under the cursor when you stop, which is what makes a
    // drop feel aimed rather than teleported.
    Follow {
        id: followX

        target: root.dragAt.x
        // Faster than the shell's own tracking rate. A menu chasing the icon
        // that opened it may take its time; a thing held in the hand may not,
        // and the trail is meant to read as weight rather than as lag.
        speed: Appearance.anim.trackSpeed * 2
    }

    Follow {
        id: followY

        target: root.dragAt.y
        speed: Appearance.anim.trackSpeed * 2
    }

    Item {
        visible: root.dragging

        x: followX.value - width / 2
        y: followY.value - height / 2
        width: Appearance.sizes.filesTile * 0.6
        height: width
        opacity: 0.85
        z: 100

        G2Rect {
            anchors.fill: parent

            radius: Appearance.rounding.normal
            color: Appearance.colour.fillStrong
        }

        FileMark {
            anchors.centerIn: parent

            fileClass: Files.current ? Files.current.class : "unknown"
            size: parent.width * 0.5
        }
    }

    // ---------------------------------------------------------- the hints

    ChordHints {
        id: hints

        anchors.fill: parent
    }
}
