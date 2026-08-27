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
            [Qt.Key_Escape]: "Escape",
            [Qt.Key_F1]: "F1",
            [Qt.Key_F2]: "F2",
            [Qt.Key_F3]: "F3",
            [Qt.Key_F4]: "F4",
            [Qt.Key_F5]: "F5",
            [Qt.Key_F6]: "F6",
            // The zoom chords. `+` and `=` are the same key with and without
            // shift, and both are spelled out so that either reaches the same
            // action without the keymap needing to know about shift.
            [Qt.Key_Plus]: "+",
            [Qt.Key_Equal]: "=",
            [Qt.Key_Minus]: "-",
            [Qt.Key_Underscore]: "_",
            // Punctuation a chord can be built on. Without these `chordOf`
            // returns nothing for them and the binding can never be found, which
            // is a keymap entry that silently does not exist.
            [Qt.Key_Comma]: ",",
            [Qt.Key_Period]: ".",
            [Qt.Key_Slash]: "/",
            [Qt.Key_Semicolon]: ";",
            [Qt.Key_Apostrophe]: "'",
            [Qt.Key_BracketLeft]: "[",
            [Qt.Key_BracketRight]: "]"
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

        const label = root.keyLabel(event.key);
        if (!label)
            return "";
        parts.push(label);
        return parts.join("+");
    }

    // The window's keymap only ever answers to a MODIFIED chord; the grid's
    // answers to bare F2 and Delete as well, which is why the spelling function
    // above no longer refuses an unmodified key and this test lives out here.
    function isChord(event: var): bool {
        return (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) !== 0;
    }

    // THE MODIFIER, WATCHED. Held on its own it is a question ("what does Ctrl
    // do here"); held as part of a chord it is not, so the first real key takes
    // the hints back down.
    Keys.onReleased: event => {
        if (event.key === Qt.Key_Control || event.key === Qt.Key_Alt || event.key === Qt.Key_Meta)
            hints.held = "";
    }

    // TAKING THE KEYBOARD BACK.
    //
    // The search field is the one thing in this window that holds Qt's own focus
    // (it has to: a field that routed through the handler below would need the
    // handler to reimplement editing, selection and the cursor). When it lets go,
    // focus does not come back here on its own - it goes NOWHERE, and the window
    // stops answering keys entirely. Which is what happened: search once, and the
    // grid was dead until you clicked something.
    //
    // Watched on the service rather than fixed in the field, because "which panel
    // has the keyboard" is the service's fact and this is the same statement in
    // Qt's terms.
    Connections {
        target: Files

        function onSearchingChanged(): void {
            if (!Files.searching)
                root.forceActiveFocus();
        }

        function onFocusChanged(): void {
            if (!Files.searching)
                root.forceActiveFocus();
        }
    }

    Keys.onPressed: event => {
        // A PANEL THAT IS UP TAKES EVERYTHING. Both of these hold Qt's focus
        // themselves while they are open, but a key that arrived here first
        // would still act on the grid behind them.
        if (settings.up || prompt.up)
            return;

        // A MENU THAT IS UP TAKES EVERYTHING. Arrow through it, Return runs the
        // entry, Escape puts it away, and every other key is swallowed rather
        // than acted on: a keystroke that reached the grid from under an open
        // menu would act on a selection the menu is describing.
        if (sheet.open) {
            switch (event.key) {
            case Qt.Key_Up:
                sheet.move(-1);
                break;
            case Qt.Key_Down:
                sheet.move(1);
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
                sheet.activate(sheet.selected);
                break;
            case Qt.Key_Escape:
                sheet.close();
                break;
            }
            event.accepted = true;
            return;
        }

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
        const chord = root.isChord(event) ? root.chordOf(event) : "";
        if (chord && Files.chords[chord] !== undefined) {
            // THROUGH THE FACE'S DISPATCHER, not the service's. Half the
            // vocabulary is the service's (navigate, toggle a panel) and half is
            // this file's (open the settings, rename, type a path), and a chord
            // that named one of the second half used to resolve, dispatch to the
            // service, be refused, and fall through to the grid's keymap where
            // it was not either. `act` below tries this file first and hands the
            // rest to the service, so both keymaps speak the same language.
            event.accepted = root.act(Files.chords[chord]);
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
    //
    // THE EDITING CHORDS LIVE HERE, not in the window's keymap, and that is the
    // whole reason they can exist at all. Ctrl+C, Ctrl+X and Ctrl+V are a
    // shell's interrupt, its kill-line and its literal-next; a window-level bind
    // would take them away from the terminal permanently. Read here, they are
    // only ever seen when there is no shell waiting for them.
    function gridKey(event: var): void {
        const shift = (event.modifiers & Qt.ShiftModifier) !== 0;

        // THE KEYMAP FIRST, chords included. `files.grid` in config holds both
        // spellings - a bare character like "j" and a chord like "Ctrl+C" - so
        // everything the grid does is in one table the user owns, rather than
        // vim's half being configurable and the editing half being buried in
        // this file.
        const chord = root.chordOf(event);
        if (chord && Files.gridKeys[chord] !== undefined) {
            event.accepted = root.act(Files.gridKeys[chord]);
            if (event.accepted)
                return;
        }

        // The arrows and Return are handled as themselves rather than through
        // the keymap, so a map emptied out still leaves the grid navigable.
        switch (event.key) {
        case Qt.Key_Left:
            root.move(-1, shift);
            event.accepted = true;
            return;
        case Qt.Key_Right:
            root.move(1, shift);
            event.accepted = true;
            return;
        case Qt.Key_Up:
            root.move(-grid.columns, shift);
            event.accepted = true;
            return;
        case Qt.Key_Down:
            root.move(grid.columns, shift);
            event.accepted = true;
            return;
        case Qt.Key_PageUp:
            root.move(-grid.columns * 3, shift);
            event.accepted = true;
            return;
        case Qt.Key_PageDown:
            root.move(grid.columns * 3, shift);
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
            if (properties.visible) {
                properties.close();
            } else if (Files.search) {
                Files.search = "";
            } else if (Files.picked.length > 0) {
                Files.clearPicked();
            } else {
                return;
            }
            event.accepted = true;
            return;
        }

        const action = Files.gridKeys[event.text];
        if (action)
            event.accepted = root.act(action);
    }

    // THE WHOLE VOCABULARY, in one place. Both keymaps and the context menus
    // dispatch through here: an action means the same thing however it was
    // reached, and there is one list of what the words are.
    function act(action: string): bool {
        switch (action) {
        case "left":
            root.move(-1, false);
            return true;
        case "right":
            root.move(1, false);
            return true;
        case "up":
            root.move(-grid.columns, false);
            return true;
        case "down":
            root.move(grid.columns, false);
            return true;
        case "first":
            root.select(0, false);
            return true;
        case "last":
            root.select(Files.visible.length - 1, false);
            return true;
        case "open":
            Files.open(Files.current);
            return true;
        case "search":
            Files.searching = true;
            return true;
        case "copypath":
            if (Files.pickedPaths.length > 0)
                Files.copyText(Files.pickedPaths.join("\n"));
            return true;
        case "all":
            Files.pickAll();
            return true;
        case "copy":
            Files.clip(Files.pickedPaths, false);
            return true;
        case "cut":
            Files.clip(Files.pickedPaths, true);
            return true;
        case "paste":
            Files.paste();
            return true;
        case "newfolder":
            root.newThing(false);
            return true;
        case "newfile":
            root.newThing(true);
            return true;
        case "rename":
            root.renameCurrent();
            return true;
        case "trash":
            Files.trash(Files.pickedPaths);
            return true;
        case "destroy":
            root.confirmDelete();
            return true;
        case "properties":
            if (Files.currentPath)
                properties.show(Files.currentPath);
            return true;
        case "path":
            path.edit();
            return true;
        case "settings":
            settings.show();
            return true;
        case "view":
            Files.toggleView();
            return true;
        case "zoomin":
            Files.zoom(0.1);
            return true;
        case "zoomout":
            Files.zoom(-0.1);
            return true;
        case "zoomreset":
            Files.zoom(0);
            return true;
        }

        // Anything left is a window action rather than a grid one, and the
        // service owns those: the same names have to mean the same things
        // whether they were reached by a chord or by a bare key.
        return Files.act(action);
    }

    function select(index: int, extend: bool): void {
        if (Files.visible.length === 0)
            return;
        const to = Math.max(0, Math.min(index, Files.visible.length - 1));
        if (extend)
            Files.extendTo(to);
        else
            Files.setCursor(to);
        grid.reveal(to);
    }

    function move(delta: int, extend: bool): void {
        root.select(Math.max(0, Files.cursor) + delta, extend ?? false);
    }

    // ---------------------------------------------------------- the menus

    // WHAT CAN BE DONE, as data, so the sheet has no idea what a file is.
    // components/ActionSheet.qml takes { icon, label, run } and draws it; the
    // same component is what the clipboard and the launcher open on a row.

    readonly property int count: Files.picks.length
    readonly property string counted: root.count === 1 ? Files.picks[0].name : `${root.count} items`

    function fileActions(): var {
        const picks = Files.picks;
        if (picks.length === 0)
            return [];

        const paths = Files.pickedPaths;
        const one = picks.length === 1 ? picks[0] : null;
        const acts = [];

        if (one)
            acts.push({
                icon: one.kind === "dir" ? "folder_open" : "open_in_new",
                label: one.kind === "dir" ? "Open" : "Open with…",
                run: () => Files.open(one)
            });

        acts.push({
            icon: "content_copy",
            label: "Copy",
            run: () => Files.clip(paths, false)
        }, {
            icon: "content_cut",
            label: "Cut",
            run: () => Files.clip(paths, true)
        });

        if (one)
            acts.push({
                icon: "edit",
                label: "Rename…",
                run: () => root.renameCurrent()
            });

        acts.push({
            icon: "link",
            label: paths.length === 1 ? "Copy path" : "Copy paths",
            run: () => Files.copyText(paths.join("\n"))
        }, {
            icon: "delete",
            label: "Move to trash",
            run: () => Files.trash(paths)
        }, {
            icon: "delete_forever",
            label: "Delete permanently…",
            run: () => root.confirmDelete()
        });

        if (one)
            acts.push({
                icon: "info",
                label: "Properties",
                run: () => properties.show(Files.join(Files.cwd, one.name))
            });

        return acts;
    }

    function folderActions(): var {
        const acts = [
            {
                icon: "create_new_folder",
                label: "New folder…",
                run: () => root.newThing(false)
            },
            {
                icon: "note_add",
                label: "New file…",
                run: () => root.newThing(true)
            }
        ];

        // Paste is only offered when there is something to paste, and says which
        // way it will go: a cut that is about to move five files should not be
        // spelled the same as a copy that is about to duplicate them.
        if (Files.clipboard.length > 0)
            acts.push({
                icon: "content_paste",
                label: `${Files.clipboardCut ? "Move" : "Paste"} ${Files.clipboard.length} here`,
                run: () => Files.paste()
            });

        acts.push({
            icon: Files.view === "list" ? "grid_view" : "view_list",
            label: Files.view === "list" ? "Icon view" : "List view",
            run: () => Files.toggleView()
        }, {
            icon: "select_all",
            label: "Select all",
            run: () => Files.pickAll()
        }, {
            icon: Files.showHidden ? "visibility_off" : "visibility",
            label: Files.showHidden ? "Hide hidden files" : "Show hidden files",
            run: () => Config.set("files.hidden", !Files.showHidden)
        }, {
            icon: "terminal",
            label: Files.terminalOpen ? "Hide terminal" : "Terminal here",
            run: () => Files.act("terminal")
        }, {
            icon: "link",
            label: "Copy this path",
            run: () => Files.copyText(Files.cwd)
        }, {
            icon: "refresh",
            label: "Refresh",
            run: () => Files.refresh()
        }, {
            icon: "settings",
            label: "Settings…",
            run: () => settings.show()
        });

        return acts;
    }

    // The three things that need a word typed or a mind made up.

    function newThing(file: bool): void {
        prompt.ask(file ? "New file" : "New folder", file ? "untitled" : "untitled folder", 0, name => {
            if (file)
                Files.makeFile(name);
            else
                Files.makeFolder(name);
        });
    }

    function renameCurrent(): void {
        const entry = Files.current;
        if (!entry)
            return;
        const path = Files.join(Files.cwd, entry.name);
        // Select the stem and not the extension: renaming "photo.jpg" is almost
        // always renaming "photo".
        const dot = entry.name.lastIndexOf(".");
        prompt.ask(`Rename ${entry.name}`, entry.name, dot > 0 ? dot : 0, name => Files.renameTo(path, name));
    }

    function confirmDelete(): void {
        const paths = Files.pickedPaths;
        if (paths.length === 0)
            return;
        // TYPED OUT, not a yes/no button. Permanent deletion is the one thing
        // here that cannot be undone by reading the history and running the
        // opposite command, so it costs a word.
        prompt.ask(`Delete ${root.counted} permanently? Type "delete" to confirm`, "", 0, answer => {
            if (answer.toLowerCase() === "delete")
                Files.deleteForever(paths);
        });
    }

    ActionSheet {
        id: sheet

        anchors.fill: parent
        z: 200

        // A grid that scrolls takes the tile out from under the sheet, and a
        // menu pointing at nothing is worse than no menu.
        Connections {
            target: Files

            function onCwdChanged(): void {
                sheet.close();
            }
        }

        onClosed: if (!Files.searching)
            Qt.callLater(root.forceActiveFocus)
    }

    NamePrompt {
        id: prompt

        anchors.fill: parent
        // ABOVE THE PANELS, whatever the declaration order is. These three are
        // declared with the menus, which read better next to the actions that
        // open them, and the layout is declared after - so without a z they were
        // drawn UNDER the grid and the scrim only dimmed the parts of the window
        // nothing else was covering.
        z: 200

        onDismissed: Qt.callLater(root.forceActiveFocus)
    }

    Properties {
        id: properties

        anchors.fill: parent
        z: 200
    }

    FilesSettings {
        id: settings

        anchors.fill: parent
        z: 200

        onDismissed: Qt.callLater(root.forceActiveFocus)
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
    // THE SIDEBAR, and the line you drag to widen it. Both live to the left of
    // everything else and neither is inside `middle`, because the sidebar is a
    // fixture of the window rather than a third panel sharing the grid's space.
    Sidebar {
        id: sidebar

        anchors.left: parent.left
        anchors.top: rule.bottom
        anchors.bottom: terminal.top

        width: Files.sidebarOpen ? Files.sidebarWidth : 0
        visible: width > 0
        clip: true

        receiving: root.dragging ? sidebar.pathAt(sidebar.mapFromItem(root, root.dragAt.x, root.dragAt.y)) : ""
    }

    SplitHandle {
        id: sidebarEdge

        anchors.left: sidebar.right
        anchors.top: rule.bottom
        anchors.bottom: terminal.top

        visible: Files.sidebarOpen

        onMoved: delta => Files.sidebarWidth = Math.max(120, Math.min(root.width * 0.4, sidebarEdge.from + delta))
        onCommitted: Files.commitWidths()

        // Where the width was when the drag began. Read at the START rather than
        // accumulated, for the reason the terminal's own handle documents: an
        // integer derived from a running sum of fractional pixels drifts away
        // from the pointer.
        property int from: 0

        Connections {
            target: sidebarEdge

            function onActiveChanged(): void {
                if (sidebarEdge.active)
                    sidebarEdge.from = Files.sidebarWidth;
            }
        }
    }

    Item {
        id: middle

        anchors.left: Files.sidebarOpen ? sidebarEdge.right : parent.left
        anchors.right: parent.right
        anchors.top: rule.bottom
        anchors.bottom: terminal.top

        readonly property bool roomForBoth: width > Files.previewWidth * 1.8

        FileGrid {
            id: grid

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: preview.visible ? previewEdge.left : parent.right
            anchors.margins: Appearance.padding.small

            entries: Files.visible
            dragging: root.dragging
            dragPoint: root.dragging ? grid.mapFromItem(root, root.dragAt.x, root.dragAt.y) : Qt.point(-1, -1)

            onPicked: (index, modifiers) => {
                Files.focus = "grid";
                // Three different requests, told apart by what was held down:
                // add one, take a range, or start over with this one.
                if (modifiers & Qt.ControlModifier)
                    Files.togglePick(index);
                else if (modifiers & Qt.ShiftModifier)
                    Files.extendTo(index);
                else
                    Files.setCursor(index);
            }
            onActivated: index => Files.open(Files.visible[index])
            onMenuFor: (index, position) => {
                Files.focus = "grid";
                // A menu opened on something that is not in the selection is
                // about THAT thing: right-clicking a file you had not selected
                // and getting a menu that would delete five others is the worst
                // possible reading of the gesture.
                if (!Files.isPicked(Files.visible[index].name))
                    Files.setCursor(index);
                const at = grid.mapToItem(root, position.x, position.y);
                sheet.popup(at.x, at.y, root.fileActions());
            }
            onMenuForEmpty: position => {
                Files.focus = "grid";
                Files.clearPicked();
                const at = grid.mapToItem(root, position.x, position.y);
                sheet.popup(at.x, at.y, root.folderActions());
            }
            onLifted: index => {
                // A DRAG CARRIES THE WHOLE SELECTION, unless it started on
                // something outside it - in which case the gesture is about that
                // one thing and the selection was not what you meant.
                if (!Files.isPicked(Files.visible[index].name))
                    Files.setCursor(index);
                root.dragging = true;
                root.exported = false;
                // NOT POSITIONED YET, deliberately. The centroid at the instant
                // a DragHandler activates is not a position anybody has been at:
                // it arrives as (0, 0), which is off the top-left corner of the
                // window, which is outside it - and the edge test below read
                // that as "the pointer has left" and handed the whole gesture to
                // the compositor before it had begun. The ghost appeared for one
                // frame and the drag was over.
                //
                // So the first real sample is what places it, and until then
                // there is nothing to place.
                root.placed = false;
            }
            onDragged: position => {
                const at = root.mapFromItem(grid, position.x, position.y);

                // NOISE, DISCARDED. Some pointer moves arrive with a position of
                // exactly (0, 0): the handler's translation then comes out as
                // minus the window's own screen position, which is a point some
                // thousands of pixels off the top-left corner. One of those is
                // enough to throw the ghost across the screen and - before the
                // dwell below existed - to hand the file to another application
                // mid-gesture.
                //
                // A generous margin rather than the window's exact rect,
                // because a drag that really has left the window reports
                // coordinates just outside it, and those are the ones the
                // handover is FOR. The bogus samples miss by a thousand.
                const slack = Appearance.sizes.filesTile * 4;
                if (at.x < -slack || at.y < -slack || at.x > root.width + slack || at.y > root.height + slack)
                    return;

                root.dragAt = at;

                if (!root.placed) {
                    // Land the ghost under the pointer rather than gliding to it
                    // from wherever it was left last time.
                    followX.snap();
                    followY.snap();
                    root.placed = true;
                    return;
                }

                root.outside = at.x < 0 || at.y < 0 || at.x > root.width || at.y > root.height;
            }
            onDropped: position => root.drop(root.mapFromItem(grid, position.x, position.y))
        }

        SplitHandle {
            id: previewEdge

            anchors.right: preview.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            visible: preview.visible

            // Dragged LEFT makes the preview wider, so the delta is negated: the
            // handle is on the panel's left edge and the panel grows toward the
            // pointer.
            onMoved: delta => Files.previewWidth = Math.max(200, Math.min(middle.width * 0.7, previewEdge.from - delta))
            onCommitted: Files.commitWidths()

            property int from: 0

            Connections {
                target: previewEdge

                function onActiveChanged(): void {
                    if (previewEdge.active)
                        previewEdge.from = Files.previewWidth;
                }
            }
        }

        PreviewPane {
            id: preview

            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: Appearance.padding.normal

            width: Files.previewWidth
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

    // WHETHER THE DRAG HAS LEFT THE BUILDING.
    //
    // A drag inside this window and a drag out of it are two different
    // mechanisms and only one of them can hold the pointer. Ours is a ghost
    // following the cursor, which the window draws and can cancel; a drag to
    // another application is a compositor-level operation that Qt runs, and once
    // it starts it owns the gesture.
    //
    // So the handover happens at the WINDOW'S EDGE, which is also where it means
    // something: while the pointer is inside, the drop targets are the folders
    // and the crumbs, and the moment it leaves there are no targets here and the
    // only thing the gesture can mean is "into whatever is out there". One
    // gesture, no modifier to remember, and the direction you move decides.
    property bool exported: false

    // Whether the ghost has had a real pointer position yet. See onLifted.
    property bool placed: false

    // Whether the pointer is currently off the window, and for how long.
    //
    // THE HANDOVER IS A DWELL, not an instant. Leaving by a pixel on the way to
    // somewhere else inside the window is not a request to give the file to
    // another application, and neither is a single stray sample. Holding it
    // outside for a moment is.
    property bool outside: false

    Timer {
        id: leaving

        interval: Appearance.anim.settle
        running: root.dragging && root.outside

        onTriggered: root.exportDrag()
    }

    function exportDrag(): void {
        if (root.exported || !Files.currentPath)
            return;
        root.exported = true;
        root.dragging = false;
        // text/uri-list is what every file manager, browser and toolkit reads,
        // and text/plain beside it because a terminal or an editor dropped on
        // wants the path rather than a URL.
        exporter.Drag.mimeData = {
            "text/uri-list": `file://${Files.currentPath}`,
            "text/plain": Files.currentPath
        };
        exporter.Drag.active = true;
    }

    Item {
        id: exporter

        // Automatic, so setting `active` hands the gesture to the compositor
        // rather than to QML's own DropArea machinery, which nothing outside
        // this window can see.
        Drag.dragType: Drag.Automatic
        Drag.supportedActions: Qt.CopyAction | Qt.MoveAction
        Drag.proposedAction: Qt.CopyAction

        // Qt runs the drag and tells us when it is over. Taking `active` back down
        // here rather than assuming it: a second drag started while the first
        // was still notionally active does nothing at all.
        Drag.onDragFinished: exporter.Drag.active = false
    }

    function drop(position: point): void {
        root.dragging = false;

        const moving = Files.pickedPaths;
        if (moving.length === 0)
            return;

        // A crumb first, because the path bar sits over the grid's top edge and
        // aiming at a parent directory should not be able to hit a file behind
        // it.
        const crumb = path.pathAt(path.mapFromItem(root, position.x, position.y));
        if (crumb) {
            Files.moveInto(moving, crumb);
            return;
        }

        // Then the sidebar, which is a column of directories and so a column of
        // drop targets: dragging a download onto Documents is the gesture the
        // sidebar exists to make possible.
        if (Files.sidebarOpen) {
            const place = sidebar.pathAt(sidebar.mapFromItem(root, position.x, position.y));
            if (place) {
                Files.moveInto(moving, place);
                return;
            }
        }

        const local = grid.mapFromItem(root, position.x, position.y);
        const index = grid.dropIndexAt(local);
        if (index < 0)
            return;

        const target = Files.visible[index];
        // Not onto itself, and not onto anything that is coming along for the
        // ride: dropping a selection onto one of its own members is a request
        // that cannot be honoured.
        if (!target || target.kind !== "dir" || !target.open || Files.isPicked(target.name))
            return;

        Files.moveInto(moving, Files.join(Files.cwd, target.name));
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
        visible: root.dragging && root.placed

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
