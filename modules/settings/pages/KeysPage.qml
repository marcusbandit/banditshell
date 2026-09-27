pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services
import qs.modules.settings
import "../../../services/hyprgen.js" as HyprGen

// KEYS: every bind the Hyprland config makes, where it lives, and the ones
// banditshell may edit.
//
// THE ROW IS A BUTTON. Each bind is its own plate -- its own fill, its own
// corners, a gap between plates -- and not a line in a shared list, so where
// one key ends and the next begins is answered by the drawing and not by the
// hairline. The anatomy is two lines and nothing more: the chord, and a
// SINGLE smaller-reading line under it (the action), elided when it will not
// fit. The mark on the left is the height of the two lines COMBINED and
// centred on them, which is why it reads as belonging to both.
//
// ("Smaller-reading": Monocraft's grid has no step between 9 and 18, so the
// second line's hierarchy is the colour's job -- textFaint under text -- the
// same way the type-scale rule carries hierarchy everywhere else in this
// shell.)
//
// EDITABLE means a literal bind: a plain chord, a plain expression, options
// this file speaks. Anything else -- binds born in a loop or a submap
// function, chords built by concatenation -- is shown where it stands and
// read-only, because an editor that half-understands a line must never write
// it. The compositor still runs every one of them; the hotkey sheet shows
// the resolved truth.
Item {
    id: root

    implicitHeight: list.implicitHeight

    // The bind being edited, by id; "" for none; "add:<file>" opens the
    // editor in ADD mode for that file.
    property string editing: ""
    readonly property bool adding: root.editing.startsWith("add:")

    onEditingChanged: {
        if (root.editing !== "")
            Prompts.request(root);
        else
            Prompts.release(root);
    }

    Component.onDestruction: Prompts.release(root)

    // THE SEARCH. Live, over everything the scan read: chord, description,
    // command, action, the expression itself. While it holds text the page
    // is one list of matches across every file -- the files are the filing,
    // and a search ignores the filing.
    property string filter: ""

    function matches(b: var): bool {
        const f = root.filter.toLowerCase();
        if (!f)
            return true;
        return b.chord.toLowerCase().includes(f)
            || b.description.toLowerCase().includes(f)
            || (b.cmd ?? "").toLowerCase().includes(f)
            || b.action.toLowerCase().includes(f)
            || b.expr.toLowerCase().includes(f);
    }

    // One section of the page: a heading, and the buttons under it. The
    // shell-wide SettingsGroup carries the anatomy; this alias only keeps the
    // page's own name for it.
    component Section: SettingsGroup {}

    Column {
        id: list

        width: parent.width
        spacing: Appearance.padding.huge

        // ------------------------------------------------------------- search

        Section {
            heading: "Search"

            EditorField {
                id: searchField

                width: parent.width
                label: "find a key"
                placeholder: "a chord, a command, a word it does"
                initial: ""

                onCommitted: value => root.filter = value
                onChanged: value => root.filter = value
            }

            BindRow {
                visible: root.filter !== ""
                modelData: null
                icon: "cancel"
                chord: "Clear"
                sub: "back to every file"
                onClicked: {
                    root.filter = "";
                    searchField.clear();
                    searchField.take();
                }
            }
        }

        // ------------------------------------------------------------ matches

        Section {
            visible: root.filter !== ""
            heading: `${HyprConfig.binds.filter(root.matches).length} binds matching`

            Repeater {
                model: HyprConfig.binds.filter(root.matches)

                delegate: BindRow {
                    showFile: true
                }
            }
        }

        // -------------------------------------------------------------- files

        Repeater {
            visible: root.filter === ""

            model: HyprConfig.files

            delegate: Section {
                required property var modelData

                heading: modelData.name
                visible: modelData.binds.length > 0

                Repeater {
                    model: modelData.binds

                    delegate: BindRow {}
                }
            }
        }

        // ---------------------------------------------------------- add a bind

        Section {
            visible: root.filter === ""
            heading: "Add a bind"

            BindRow {
                modelData: null
                icon: "add"
                chord: "New bind"
                sub: "appended to the end of binds.lua"
                onClicked: root.editing = "add:lua/binds.lua"
            }

            BindRow {
                modelData: null
                icon: "keyboard"
                chord: "See them live, on the keys"
                sub: "the hotkey sheet: every bind there is, resolved"
                onClicked: Shell.forScreen(Settings.screenName)?.hotkeys.show()
            }
        }
    }

    // THE BUTTON. Two lines -- the chord, and the one line under it -- a mark
    // as tall as the pair, centred on it, and a fill that says where the
    // button is before you hover it.
    component BindRow: Item {
        id: row

        required property var modelData
        property bool showFile: false

        // Direct clicks (the Clear row) that are not a bind at all.
        signal clicked

        property string icon: modelData?.dynamic ? "auto_awesome" : "keyboard"
        property string chord: modelData?.chord || "(no chord)"
        property string sub: {
            if (!modelData)
                return "";
            if (modelData.dynamic)
                return `generated by the source · ${modelData.file}:${modelData.startLine} · read-only`;
            const said = modelData.description || modelData.action || modelData.expr;
            return showFile ? `${said} -- ${modelData.file}:${modelData.startLine}` : said;
        }
        readonly property bool editable: !!modelData && !modelData.dynamic

        readonly property real lineH: Appearance.font.size.small * 4 / 3
        readonly property real blockH: lineH * 2 + Appearance.font.stem * 2

        width: parent ? parent.width : 0
        height: blockH + Appearance.padding.normal * 2

        // The plate, always drawn: a button is a thing you can see before
        // you hover it. Hover and press turn the light up, never on.
        G2Rect {
            anchors.fill: parent
            radius: Appearance.rounding.small
            color: rowTap.containsMouse ? Appearance.colour.fillStrong : Appearance.colour.fill
        }

        // THE MARK: the height of the two lines COMBINED, centred on them.
        Icon {
            x: Appearance.padding.normal
            anchors.verticalCenter: parent.verticalCenter
            width: row.blockH
            height: row.blockH
            size: row.blockH
            name: row.icon
            color: row.editable ? Appearance.colour.textDim : Appearance.colour.textFaint
        }

        Column {
            x: Appearance.padding.normal + row.blockH + Appearance.padding.normal
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - Appearance.padding.normal
            spacing: Appearance.font.stem * 2

            StyledText {
                text: row.chord
                color: Appearance.colour.text
            }

            StyledText {
                width: parent.width
                elide: Text.ElideRight
                text: row.sub
                color: Appearance.colour.textFaint
            }
        }

        MouseArea {
            id: rowTap

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: row.editable || !row.modelData ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
                if (!row.modelData)
                    return row.clicked();
                if (row.editable)
                    root.editing = row.modelData.id;
            }
        }
    }

    // THE FORM. One column of fields in the row's place; Save splices the
    // line, Remove deletes it, Escape or Cancel touch nothing. Fields commit
    // into each other -- chord, action, description, save -- so a small
    // edit can be typed straight through.
    component BindEditor: Item {
        id: editor

        // The bind, as a COPY and not a reference: an edit abandoned
        // halfway leaves nothing behind, and Save is the only way back.
        property var bind: null
        property string file: ""

        readonly property bool isAdd: bind === null

        // The COMMAND field is the inner string of an exec; a non-exec
        // expression edits as raw Lua, verbatim, so what is saved is what
        // was seen.
        readonly property bool isExec: !isAdd && /^hl\.dsp\.exec_cmd\(/.test(bind.expr)

        implicitHeight: column.implicitHeight

        function save(): void {
            const fields = {
                chord: chordInput.text.trim(),
                // The action goes back in the shape it came from: an exec's
                // command re-quoted, anything else written as the Lua it is.
                expr: isExec ? `hl.dsp.exec_cmd("${HyprGen.luaString(actionInput.text)}")` : actionInput.text,
                locked: lockedToggle.checked,
                repeating: repeatToggle.checked,
                description: descriptionInput.text
            };

            if (isAdd) {
                HyprConfig.addBind(file, fields);
            } else if (HyprGen.parseChord(fields.chord).key === "") {
                console.warn(`HyprConfig: "${fields.chord}" is not a chord; the edit was not written.`);
                return root.editing = "";
            } else {
                HyprConfig.updateBind(bind.id, fields);
            }
            root.editing = "";
        }

        function remove(): void {
            if (!isAdd)
                HyprConfig.removeBind(bind.id);
            root.editing = "";
        }

        Column {
            id: column

            width: parent.width
            spacing: Appearance.padding.normal

            EditorField {
                id: chordInput

                width: parent.width
                label: "chord"
                placeholder: "SUPER + F1"
                initial: editor.isAdd ? "" : editor.bind.chord

                onCommitted: actionInput.take()
            }

            EditorField {
                id: actionInput

                width: parent.width
                label: editor.isExec ? "command" : "expression"
                initial: editor.isAdd ? "" : (editor.bind.cmd !== "" ? editor.bind.cmd : editor.bind.expr)

                onCommitted: descriptionInput.take()
            }

            EditorField {
                id: descriptionInput

                width: parent.width
                label: "description"
                initial: editor.isAdd ? "" : editor.bind.description
                placeholder: "what the sheet prints beside the chord"

                onCommitted: editor.save()
            }

            Row {
                spacing: Appearance.padding.small

                Toggle {
                    id: repeatToggle

                    checked: !editor.isAdd && editor.bind.repeating
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "repeats while held"
                    color: Appearance.colour.textDim
                }
            }

            Row {
                spacing: Appearance.padding.small

                Toggle {
                    id: lockedToggle

                    checked: !editor.isAdd && editor.bind.locked
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "works when the session is locked"
                    color: Appearance.colour.textDim
                }
            }

            Row {
                spacing: Appearance.padding.small

                Button {
                    text: "Save"
                    onClicked: editor.save()
                }

                Button {
                    visible: !editor.isAdd
                    text: "Remove"
                    onClicked: editor.remove()
                }

                Button {
                    text: "Cancel"
                    onClicked: root.editing = ""
                }
            }
        }

        // Created only when opened (the Loader), so creation IS the opening:
        // the first field takes the keyboard.
        Component.onCompleted: chordInput.take()
    }

    // THE FIELD, PathField's shape without the row: a labelled line of
    // text. Committing hands focus to the next field, and the last one
    // saves. (A page-level component: QML does not nest inline components,
    // which is the error the first draft died of.)
    component EditorField: Item {
        id: fieldRoot

        property string label: ""
        property string placeholder: ""
        property string initial: ""
        signal committed(string value)
        signal changed(string value)

        function take(): void {
            Qt.callLater(input.forceActiveFocus);
        }

        function clear(): void {
            input.text = "";
        }

        width: parent ? parent.width : 0
        height: fieldLabel.implicitHeight + Appearance.font.stem + Appearance.sizes.rowHeight

        StyledText {
            id: fieldLabel

            text: fieldRoot.label
            color: Appearance.colour.textFaint
        }

        G2Rect {
            anchors.top: fieldLabel.bottom
            anchors.topMargin: Appearance.font.stem
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            radius: Appearance.rounding.small
            color: Appearance.colour.fillStrong
        }

        TextInput {
            id: input

            anchors.fill: parent
            anchors.topMargin: fieldLabel.implicitHeight + Appearance.font.stem
            anchors.leftMargin: Appearance.padding.normal
            anchors.rightMargin: Appearance.padding.normal

            verticalAlignment: TextInput.AlignVCenter
            clip: true
            text: fieldRoot.initial
            font.family: Appearance.font.family
            font.pixelSize: Appearance.font.size.small
            renderType: Text.NativeRendering
            color: Appearance.colour.text
            selectionColor: Appearance.colour.accent
            selectedTextColor: Appearance.colour.accentText

            onAccepted: fieldRoot.committed(text)
            onTextChanged: fieldRoot.changed(text)
            Keys.onEscapePressed: root.editing = ""

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                visible: !input.text
                text: fieldRoot.placeholder
                color: Appearance.colour.textFaint
            }
        }
    }
}
