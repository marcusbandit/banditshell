pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import qs.config
import qs.components
import qs.services

Item {
    id: root

    focus: true

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

            [Qt.Key_Plus]: "+",
            [Qt.Key_Equal]: "=",
            [Qt.Key_Minus]: "-",
            [Qt.Key_Underscore]: "_",

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

    function isChord(event: var): bool {
        return (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) !== 0;
    }

    Keys.onReleased: event => {
        if (event.key === Qt.Key_Control || event.key === Qt.Key_Alt || event.key === Qt.Key_Meta)
            hints.held = "";
    }

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

        if (settings.up || prompt.up)
            return;

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

        const chord = root.isChord(event) ? root.chordOf(event) : "";
        if (chord && Files.chords[chord] !== undefined) {

            event.accepted = root.act(Files.chords[chord]);
            if (event.accepted)
                return;
        }

        if (Files.focus === "terminal" && Files.terminalOpen) {
            terminal.view.key(event);
            return;
        }

        root.gridKey(event);
    }

    function gridKey(event: var): void {
        const shift = (event.modifiers & Qt.ShiftModifier) !== 0;

        const chord = root.chordOf(event);
        if (chord && Files.gridKeys[chord] !== undefined) {
            event.accepted = root.act(Files.gridKeys[chord]);
            if (event.accepted)
                return;
        }

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
                Files.setSearch("");
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
            Files.setSearching(true);
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

        const dot = entry.name.lastIndexOf(".");
        prompt.ask(`Rename ${entry.name}`, entry.name, dot > 0 ? dot : 0, name => Files.renameTo(path, name));
    }

    function confirmDelete(): void {
        const paths = Files.pickedPaths;
        if (paths.length === 0)
            return;

        prompt.ask(`Delete ${root.counted} permanently? Type "delete" to confirm`, "", 0, answer => {
            if (answer.toLowerCase() === "delete")
                Files.deleteForever(paths);
        });
    }

    ActionSheet {
        id: sheet

        anchors.fill: parent
        z: 200

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

                if (!Files.isPicked(Files.visible[index].name))
                    Files.setCursor(index);
                root.dragging = true;
                root.exported = false;

                root.placed = false;
            }
            onDragged: position => {
                const at = root.mapFromItem(grid, position.x, position.y);

                const slack = Appearance.sizes.filesTile * 4;
                if (at.x < -slack || at.y < -slack || at.x > root.width + slack || at.y > root.height + slack)
                    return;

                root.dragAt = at;

                if (!root.placed) {

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

    property bool dragging: false
    property point dragAt: Qt.point(0, 0)

    property bool exported: false

    property bool placed: false

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

        exporter.Drag.mimeData = {
            "text/uri-list": `file://${Files.currentPath}`,
            "text/plain": Files.currentPath
        };
        exporter.Drag.active = true;
    }

    Item {
        id: exporter

        Drag.dragType: Drag.Automatic
        Drag.supportedActions: Qt.CopyAction | Qt.MoveAction
        Drag.proposedAction: Qt.CopyAction

        Drag.onDragFinished: exporter.Drag.active = false
    }

    function drop(position: point): void {
        root.dragging = false;

        const moving = Files.pickedPaths;
        if (moving.length === 0)
            return;

        const crumb = path.pathAt(path.mapFromItem(root, position.x, position.y));
        if (crumb) {
            Files.moveInto(moving, crumb);
            return;
        }

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

        if (!target || target.kind !== "dir" || !target.open || Files.isPicked(target.name))
            return;

        Files.moveInto(moving, Files.join(Files.cwd, target.name));
    }

    Follow {
        id: followX

        target: root.dragAt.x

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

    ChordHints {
        id: hints

        anchors.fill: parent
    }
}
