pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

// THE BROWSER'S OWN SETTINGS, inside the browser.
//
// Not a page in the shell's settings: this window is an application, its
// preferences belong to it, and a person looking for "how do I open the preview"
// looks in the window they are standing in rather than in a different one. The
// values all land in the same config.json as everything else - it is the same
// storage, reached from where it is being used.
//
// THE KEYS ARE THE POINT. Everything else here is a switch that could have been
// found by right-clicking, but a chord that is not written down anywhere is a
// chord that does not exist: it was possible to have the preview panel bound to
// Ctrl+4 and no way at all to discover that. So the keymaps are listed in full,
// every row rebindable by pressing the chord you would rather have.
Item {
    id: root

    property bool up: false

    signal dismissed

    function show(): void {
        root.up = true;
        root.opacity = 1;
        Qt.callLater(root.forceActiveFocus);
    }

    function close(): void {
        root.rebinding = "";
        root.up = false;
        root.opacity = 0;
        root.dismissed();
    }

    visible: root.up || root.opacity > 0
    opacity: 0
    focus: root.up

    // WHICH ROW IS WAITING FOR A CHORD, as "map:key", or "" when none is. One at
    // a time: two rows both listening would both take the next keystroke.
    property string rebinding: ""

    // ---- what a chord is called, both ways round ------------------------

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
            [Qt.Key_Plus]: "+",
            [Qt.Key_Equal]: "=",
            [Qt.Key_Minus]: "-",
            [Qt.Key_Underscore]: "_",
            [Qt.Key_Slash]: "/",
            [Qt.Key_Period]: ".",
            [Qt.Key_F1]: "F1",
            [Qt.Key_F2]: "F2",
            [Qt.Key_F3]: "F3",
            [Qt.Key_F4]: "F4",
            [Qt.Key_F5]: "F5",
            [Qt.Key_F6]: "F6"
        })

    function chordOf(event: var): string {
        const parts = [];
        if (event.modifiers & Qt.ControlModifier)
            parts.push("Ctrl");
        if (event.modifiers & Qt.AltModifier)
            parts.push("Alt");
        if (event.modifiers & Qt.ShiftModifier)
            parts.push("Shift");

        let label = root.keyNames[event.key];
        if (!label && (event.key >= Qt.Key_A && event.key <= Qt.Key_Z || event.key >= Qt.Key_0 && event.key <= Qt.Key_9))
            label = String.fromCharCode(event.key);
        // A bare printable character, which is what the grid's vim layer is made
        // of: `j`, `/`, `.`. Taken from the text rather than the key, because
        // that is the thing the keymap is written in.
        if (!label && parts.length === 0 && event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 0x20)
            label = event.text;
        if (!label)
            return "";

        parts.push(label);
        return parts.join("+");
    }

    // What each action is called, for a person. An action with no entry falls
    // back to its own name, so a binding added by hand still reads.
    readonly property var labels: ({
            terminal: "Show or hide the terminal",
            preview: "Show or hide the preview panel",
            sidebar: "Show or hide the sidebar",
            hidden: "Show or hide hidden files",
            back: "Back",
            forward: "Forward",
            parent: "Go to the parent folder",
            home: "Go home",
            "focus:grid": "Put the keyboard on the files",
            "focus:preview": "Put the keyboard on the preview",
            "focus:terminal": "Put the keyboard on the terminal",
            left: "Move left",
            right: "Move right",
            up: "Move up",
            down: "Move down",
            first: "First file",
            last: "Last file",
            open: "Open",
            search: "Search in this folder",
            copypath: "Copy the path",
            all: "Select everything",
            copy: "Copy",
            cut: "Cut",
            paste: "Paste",
            newfolder: "New folder",
            newfile: "New file",
            rename: "Rename",
            trash: "Move to trash",
            destroy: "Delete permanently",
            properties: "Properties",
            path: "Type a path",
            view: "Switch between icons and list",
            zoomin: "Bigger",
            zoomout: "Smaller",
            zoomreset: "Reset the size",
            settings: "These settings"
        })

    function rowsOf(map: var): var {
        const out = [];
        for (const chord in map)
            out.push({chord: chord, action: map[chord]});
        // Sorted by what they DO rather than by which key does it: you come here
        // looking for an action and wanting to know its chord, not the reverse.
        return out.sort((a, b) => (root.labels[a.action] ?? a.action).localeCompare(root.labels[b.action] ?? b.action));
    }

    // Rebinding is one write: the old spelling out, the new one in. Done on the
    // whole map rather than key by key, because Config.set takes a value and a
    // map with one key removed is a different value.
    function rebind(which: string, from: string, to: string): void {
        if (!to || to === from)
            return;

        const map = which === "keys" ? Files.chords : Files.gridKeys;
        const next = {};
        for (const chord in map)
            if (chord !== from && chord !== to)
                next[chord] = map[chord];
        next[to] = map[from];
        Config.set(`files.${which}`, next);
    }

    Keys.onPressed: event => {
        if (root.rebinding) {
            // A modifier on its own is not a chord, it is the start of one.
            if (event.key === Qt.Key_Control || event.key === Qt.Key_Alt || event.key === Qt.Key_Shift || event.key === Qt.Key_Meta)
                return;
            event.accepted = true;

            if (event.key === Qt.Key_Escape) {
                root.rebinding = "";
                return;
            }

            const cut = root.rebinding.indexOf(":");
            root.rebind(root.rebinding.slice(0, cut), root.rebinding.slice(cut + 1), root.chordOf(event));
            root.rebinding = "";
            return;
        }

        if (event.key === Qt.Key_Escape) {
            root.close();
            event.accepted = true;
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Appearance.anim.fast
            easing.type: Easing.OutQuad
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Appearance.colour.scrim

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    G2Rect {
        anchors.centerIn: parent

        implicitWidth: Math.min(root.width - Appearance.padding.huge * 2, 640)
        implicitHeight: Math.min(root.height - Appearance.padding.huge * 2, 720)

        radius: Appearance.rounding.large
        color: Appearance.colour.surfaceSolid
        stroke: Appearance.colour.separator
        strokeWidth: Appearance.font.stem

        Row {
            id: header

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Appearance.padding.large

            spacing: Appearance.padding.normal

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "settings"
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter

                text: "File browser settings"
                font.pixelSize: Appearance.font.size.normal
            }
        }

        Separator {
            id: headRule

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: header.bottom
            anchors.topMargin: Appearance.padding.normal
        }

        Flickable {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: headRule.bottom
            anchors.bottom: parent.bottom
            anchors.margins: Appearance.padding.large

            clip: true
            contentHeight: body.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: body

                width: parent.width
                spacing: Appearance.padding.large

                // ---- the switches ---------------------------------------

                Setting {
                    width: body.width
                    label: "View"
                    detail: "How the files are laid out"

                    Segments {
                        width: 220
                        options: ["Icons", "List"]
                        current: Files.view === "list" ? 1 : 0
                        onPicked: index => Config.set("files.view", index === 1 ? "list" : "icons")
                    }
                }

                Setting {
                    width: body.width
                    label: "Size"
                    detail: `${Math.round(Appearance.sizes.filesZoom * 100)}% · text ${Appearance.sizes.filesText}px`

                    Segments {
                        width: 300
                        options: ["Smaller", "Reset", "Bigger"]
                        current: 1
                        onPicked: index => Files.zoom(index === 0 ? -0.1 : index === 2 ? 0.1 : 0)
                    }
                }

                Setting {
                    width: body.width
                    label: "Hidden files"
                    detail: "Names beginning with a dot"

                    Toggle {
                        checked: Files.showHidden
                        onToggled: Config.set("files.hidden", !Files.showHidden)
                    }
                }

                Setting {
                    width: body.width
                    label: "Sort by"
                    detail: "Folders always come first"

                    Segments {
                        width: 300
                        options: ["Name", "Size", "Changed", "Kind"]
                        current: ["name", "size", "mtime", "kind"].indexOf(Files.sort)
                        onPicked: index => Config.set("files.sort", ["name", "size", "mtime", "kind"][index])
                    }
                }

                Setting {
                    width: body.width
                    label: "Markdown"
                    detail: "How .md files open in the preview"

                    Segments {
                        width: 220
                        options: ["Rendered", "Raw"]
                        current: Files.markdownRendered ? 0 : 1
                        onPicked: index => Config.set("files.markdown", index === 1 ? "raw" : "rendered")
                    }
                }

                // ---- the keys -------------------------------------------

                Repeater {
                    model: [
                        {
                            which: "keys",
                            title: "Keys, anywhere in the window",
                            note: "Read whatever has focus. Anything not listed here goes to the panel you are typing in, which is what leaves Ctrl+C to the shell."
                        },
                        {
                            which: "grid",
                            title: "Keys, while the files have focus",
                            note: "Only when the keyboard is on the grid, so the terminal keeps them."
                        }
                    ]

                    delegate: Column {
                        id: group

                        required property var modelData

                        width: body.width
                        spacing: Appearance.padding.small

                        StyledText {
                            text: group.modelData.title
                            font.pixelSize: Appearance.font.size.normal
                        }

                        StyledText {
                            width: group.width
                            text: group.modelData.note
                            font.pixelSize: Appearance.sizes.filesText
                            color: Appearance.colour.textFaint
                            wrapMode: Text.Wrap
                            bottomPadding: Appearance.padding.small
                        }

                        Repeater {
                            model: root.rowsOf(group.modelData.which === "keys" ? Files.chords : Files.gridKeys)

                            delegate: Item {
                                id: binding

                                required property var modelData

                                readonly property string id: `${group.modelData.which}:${binding.modelData.chord}`
                                readonly property bool waiting: root.rebinding === binding.id

                                width: group.width
                                height: Appearance.sizes.filesRow * 1.2

                                G2Rect {
                                    anchors.fill: parent

                                    radius: Appearance.rounding.small
                                    color: binding.waiting ? Appearance.colour.accentFill : press.containsMouse ? Appearance.colour.fill : "transparent"
                                    stroke: binding.waiting ? Appearance.colour.accent : "transparent"
                                    strokeWidth: binding.waiting ? Appearance.font.stem : 0
                                }

                                StyledText {
                                    anchors.left: parent.left
                                    anchors.leftMargin: Appearance.padding.normal
                                    anchors.right: chord.left
                                    anchors.rightMargin: Appearance.padding.normal
                                    anchors.verticalCenter: parent.verticalCenter

                                    text: root.labels[binding.modelData.action] ?? binding.modelData.action
                                    font.pixelSize: Appearance.sizes.filesText
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    id: chord

                                    anchors.right: parent.right
                                    anchors.rightMargin: Appearance.padding.normal
                                    anchors.verticalCenter: parent.verticalCenter

                                    text: binding.waiting ? "press a key…" : binding.modelData.chord
                                    font.pixelSize: Appearance.sizes.filesText
                                    color: binding.waiting ? Appearance.colour.accent : Appearance.colour.textDim
                                }

                                MouseArea {
                                    id: press

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: {
                                        root.rebinding = binding.waiting ? "" : binding.id;
                                        root.forceActiveFocus();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
