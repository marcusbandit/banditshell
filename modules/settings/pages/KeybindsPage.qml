pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland._ShortcutsInhibitor
import qs.config
import qs.components
import qs.services
import qs.modules.settings
import "../../../services/hyprgen.js" as HyprGen

// KEYBINDS: every bind the Hyprland config makes, and the ones banditshell may
// edit.
//
// THE ROW IS TWO THINGS. The chord is a row of plates -- one per key, SUPER
// SHIFT A -- and the plates are the record button: click one and the page
// takes the keyboard over, presses whatever keys the new chord is, and lets
// go. The line under the plates is the command the bind actually runs,
// verbatim, and nothing else: no sentence invented for it, no file and line
// decorated onto it. What you can run is what you can read; the file it came
// from is the heading of the section it sits in.
//
// RECORDING. While a row records, the page holds the compositor's shortcut
// inhibitor (keyboard-shortcuts-inhibit-v1), so Hyprland's own binds stand
// down and every key -- Super+Q included -- arrives here instead of doing
// what it would do on the desktop. The recording ends the way a chord does:
// press and hold the chord, and the moment nothing is held any more it is
// set. Escape alone cancels; Escape inside a chord records. Only a chord the
// config can name commits -- a key with no name says so and keeps waiting
// rather than writing a bind the compositor cannot parse.
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

    onEditingChanged: {
        if (root.editing !== "")
            Prompts.request(root);
        else
            Prompts.release(root);
    }

    Component.onDestruction: Prompts.release(root)

    // THE SEARCH. Live, over everything the scan read: the chord -- typed the
    // way you would say it, "super a", no plus -- and the command and the
    // expression and any description the config itself carries. While it
    // holds text the page is one list of matches across every file -- the
    // files are the filing, and a search ignores the filing.
    property string filter: ""

    // Chords compare with every separator stripped from both sides, so the
    // query "super a" finds "SUPER + A" and "super+a" finds it too. The rest
    // of the row matches verbatim: a command is a command, and "exec" should
    // find the execs.
    function bare(s: string): string {
        return s.toLowerCase().replace(/[^a-z0-9]/g, "");
    }

    function matches(b: var): bool {
        const f = root.filter.toLowerCase();
        if (!f)
            return true;
        const fb = root.bare(f);
        return root.bare(b.chord).includes(fb)
            || b.description.toLowerCase().includes(f)
            || (b.cmd ?? "").toLowerCase().includes(f)
            || b.action.toLowerCase().includes(f)
            || b.expr.toLowerCase().includes(f);
    }

    // ------------------------------------------------------------ recording

    // Which bind is recording, by id; "" for none. Recording is ONE at a
    // time and the whole page's business, not a row's: the keyboard it
    // takes over is the window's.
    property string recording: ""

    // The chord as it stands, mid-recording: the mods held right now, and
    // the one non-modifier key the chord has come down to.
    property var held: ({})
    property var capMods: []
    property string capKey: ""

    // A key this editor has no name for. The recording keeps waiting -- a
    // second key may still be the chord -- but the row says what happened
    // rather than silently ignoring the press.
    property bool unnamed: false

    readonly property bool recordArmed: grab.active

    readonly property var draftMods: root.capMods
    readonly property string draftKey: root.capKey

    function startRecord(id: string): void {
        root.held = {};
        root.capMods = [];
        root.capKey = "";
        root.unnamed = false;
        root.recording = id;
        capture.forceActiveFocus();
    }

    function cancelRecord(): void {
        root.recording = "";
        root.held = {};
        root.capMods = [];
        root.capKey = "";
        root.unnamed = false;
        root.face?.forceActiveFocus();
    }

    function commitRecord(): void {
        const id = root.recording;
        const chord = [...root.capMods, root.capKey].join(" + ");
        root.cancelRecord();
        if (!HyprGen.parseChord(chord).key)
            return console.warn(`HyprConfig: "${chord}" is not a chord; nothing was written.`);
        const b = HyprConfig.binds.find(x => x.id === id);
        if (!b || b.dynamic)
            return;
        HyprConfig.updateBind(id, {
            chord,
            expr: b.expr,
            locked: b.locked,
            repeating: b.repeating,
            description: b.description
        });
    }

    // The page's Escape walks up to the face; recording hands the keyboard
    // back there when it ends, so Escape closes the page from the next
    // press rather than dying on an item that no longer holds focus.
    readonly property Item face: {
        let p = root.parent;
        while (p && p.railFoot === undefined)
            p = p.parent;
        return p;
    }

    function modsFrom(m: int): var {
        const out = [];
        if (m & Qt.MetaModifier)
            out.push("SUPER");
        if (m & Qt.ControlModifier)
            out.push("CTRL");
        if (m & Qt.AltModifier)
            out.push("ALT");
        if (m & Qt.ShiftModifier)
            out.push("SHIFT");
        return out;
    }

    function isModKey(key: int): bool {
        return key === Qt.Key_Meta || key === Qt.Key_Control || key === Qt.Key_Alt
            || key === Qt.Key_Shift || key === Qt.Key_AltGr || key === Qt.Key_CapsLock
            || key === Qt.Key_NumLock || key === Qt.Key_Super_L || key === Qt.Key_Super_R
            || key === Qt.Key_Hyper_L || key === Qt.Key_Hyper_R;
    }

    // A Qt key as the config names it: the vocabulary binds.lua already
    // speaks, then the xkb keysym words for the punctuation row, then the
    // character itself. Empty means this editor has no name for the key.
    function keyName(key: int, text: string): string {
        const named = {
            [Qt.Key_Return]: "RETURN",
            [Qt.Key_Enter]: "KPENTER",
            [Qt.Key_Space]: "SPACE",
            [Qt.Key_Escape]: "ESCAPE",
            [Qt.Key_Tab]: "tab",
            [Qt.Key_Backtab]: "tab",
            [Qt.Key_QuoteLeft]: "grave",
            [Qt.Key_Left]: "LEFT",
            [Qt.Key_Right]: "RIGHT",
            [Qt.Key_Up]: "UP",
            [Qt.Key_Down]: "DOWN",
            [Qt.Key_Backspace]: "BACKSPACE",
            [Qt.Key_Delete]: "DELETE",
            [Qt.Key_Home]: "HOME",
            [Qt.Key_End]: "END",
            [Qt.Key_PageUp]: "PGUP",
            [Qt.Key_PageDown]: "PGDN",
            [Qt.Key_Insert]: "INSERT",
            [Qt.Key_Print]: "PRINT",
            [Qt.Key_Pause]: "PAUSE",
            [Qt.Key_Minus]: "minus",
            [Qt.Key_Equal]: "equal",
            [Qt.Key_Comma]: "comma",
            [Qt.Key_Period]: "period",
            [Qt.Key_Slash]: "slash",
            [Qt.Key_Backslash]: "backslash",
            [Qt.Key_Semicolon]: "semicolon",
            [Qt.Key_Apostrophe]: "apostrophe",
            [Qt.Key_BracketLeft]: "bracketleft",
            [Qt.Key_BracketRight]: "bracketright",
            [Qt.Key_CapsLock]: "CAPSLOCK",
            [Qt.Key_MediaPlay]: "XF86AudioPlay",
            [Qt.Key_MediaStop]: "XF86AudioStop",
            [Qt.Key_MediaPrevious]: "XF86AudioPrev",
            [Qt.Key_MediaNext]: "XF86AudioNext",
            [Qt.Key_VolumeUp]: "XF86AudioRaiseVolume",
            [Qt.Key_VolumeDown]: "XF86AudioLowerVolume",
            [Qt.Key_VolumeMute]: "XF86AudioMute",
            [Qt.Key_MonBrightnessUp]: "XF86MonBrightnessUp",
            [Qt.Key_MonBrightnessDown]: "XF86MonBrightnessDown"
        };
        if (named[key] !== undefined)
            return named[key];
        if (key >= Qt.Key_F1 && key <= Qt.Key_F35)
            return `F${key - Qt.Key_F1 + 1}`;
        if (text && text.length === 1 && text >= " " && text !== "\x7f")
            return text.toUpperCase();
        return "";
    }

    // THE TAKEOVER. Enabled while a row records; the compositor then hands
    // this window every key instead of acting on its own binds. `active` is
    // the compositor's own answer -- a grab it has not granted is not
    // assumed, and keys are only captured once it says so.
    ShortcutInhibitor {
        id: grab

        window: QsWindow.window
        enabled: root.recording !== ""
        onCancelled: root.cancelRecord()
    }

    // Not armed within a beat of asking: the compositor refused the
    // inhibitor (or the window never got focus). Give up rather than sit
    // recording nothing -- the keys are going to the desktop either way.
    Timer {
        interval: 2000
        running: root.recording !== "" && !grab.active
        onTriggered: {
            console.warn("Keybinds: the compositor never granted the keyboard; recording cancelled.");
            root.cancelRecord();
        }
    }

    // THE CAPTURE ITEM. Focus lands here while a row records, and every key
    // the window receives is answered here and accepted here, so nothing
    // walks up to the face's Escape and closes the page mid-chord. The
    // chord is read off the PRESS state: mods and key as they come down, and
    // the moment everything is back up with a key captured, it is set.
    Item {
        id: capture

        Keys.onPressed: event => {
            if (root.recording === "" || !root.recordArmed)
                return;
            event.accepted = true;
            const mods = root.modsFrom(event.modifiers);
            if (event.key === Qt.Key_Escape && mods.length === 0) {
                root.cancelRecord();
                return;
            }
            root.unnamed = false;
            root.held[event.key] = true;
            root.capMods = mods;
            if (!root.isModKey(event.key)) {
                const name = root.keyName(event.key, event.text);
                if (name !== "")
                    root.capKey = name;
                else
                    root.unnamed = true;
            }
        }

        Keys.onReleased: event => {
            if (root.recording === "" || !root.recordArmed)
                return;
            event.accepted = true;
            delete root.held[event.key];
            if (Object.keys(root.held).length > 0)
                return;
            // Everything is up. A chord with a key in it is set; letting go
            // of a modifier alone is not a chord, so the recording keeps
            // waiting for one.
            if (root.capKey !== "")
                root.commitRecord();
            else {
                root.capMods = [];
            }
        }
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
                placeholder: "super a -- no plus needed"
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

                delegate: Column {
                    id: matchWrap

                    required property var modelData

                    width: parent ? parent.width : 0

                    BindRow {
                        modelData: matchWrap.modelData
                    }

                    Loader {
                        active: root.editing === matchWrap.modelData.id
                        sourceComponent: BindEditor {
                            bind: matchWrap.modelData
                            file: matchWrap.modelData.file
                        }
                    }
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

                    delegate: Column {
                        id: bindWrap

                        required property var modelData

                        width: parent ? parent.width : 0

                        BindRow {
                            modelData: bindWrap.modelData
                        }

                        Loader {
                            active: root.editing === bindWrap.modelData.id
                            sourceComponent: BindEditor {
                                bind: bindWrap.modelData
                                file: bindWrap.modelData.file
                            }
                        }
                    }
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

            Loader {
                active: root.editing.startsWith("add:")
                sourceComponent: BindEditor {
                    bind: null
                    file: root.editing.slice(4)
                }
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

    // THE ROW. The chord as plates -- one per key, and the plates are the
    // record button -- with the command the bind runs, verbatim, under
    // them. The rest of the row is the editor's way in.
    component BindRow: Item {
        id: row

        required property var modelData

        // Direct clicks (the Clear row) that are not a bind at all.
        signal clicked

        property string icon: modelData?.dynamic ? "auto_awesome" : "keyboard"
        property string chord: modelData?.chord || "(no chord)"
        // THE COMMAND, and nothing else: what an exec runs, or the Lua call
        // any other bind makes, and for a dynamic bind the source line that
        // generates it. The sentence dictionary and the file:line decoration
        // are gone -- this line is what the machine does.
        property string sub: !modelData ? "" : modelData.dynamic ? modelData.raw : (modelData.cmd || modelData.expr)
        readonly property bool editable: !!modelData && !modelData.dynamic

        // Recording THIS row: the plates become the chord as it stands, live.
        readonly property bool recordingThis: root.recording === row.modelData?.id

        readonly property var plateTokens: {
            if (!row.recordingThis)
                return String(row.chord).split(" + ");
            const toks = [...root.draftMods];
            toks.push(root.draftKey !== "" ? root.draftKey : "…");
            return toks;
        }

        readonly property string status: {
            if (!row.recordingThis)
                return row.sub;
            if (!root.recordArmed)
                return "asking the compositor for the keys…";
            if (root.unnamed)
                return "that key has no name here -- try another, escape cancels";
            if (root.draftKey !== "")
                return "let go of everything to set it";
            if (root.draftMods.length > 0)
                return "now a key -- escape cancels";
            return "press the new chord -- escape cancels";
        }

        readonly property real plateH: Appearance.sizes.minTarget
        readonly property real lineH: Appearance.font.size.small * 4 / 3
        readonly property real blockH: row.plateH + Appearance.font.stem + row.lineH

        width: parent ? parent.width : 0
        height: blockH + Appearance.padding.normal * 2

        // The plate, always drawn: a button is a thing you can see before
        // you hover it. Hover and press turn the light up, never on.
        G2Rect {
            anchors.fill: parent
            radius: Appearance.rounding.small
            color: row.recordingThis || rowTap.containsMouse ? Appearance.colour.fillStrong : Appearance.colour.fill
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
            spacing: Appearance.font.stem

            // THE CHORD AS PLATES, one per key -- clickable, and clicking one
            // is how the row is re-recorded. A dynamic bind's chord is source
            // text, not a chord, and a direct row (clear, new) is prose: both
            // stay plain text.
            Row {
                spacing: Appearance.padding.small

                Repeater {
                    model: row.editable || row.recordingThis ? row.plateTokens : []

                    delegate: Item {
                        id: plate

                        required property string modelData

                        width: plateText.implicitWidth + Appearance.padding.normal * 2
                        height: row.plateH

                        G2Rect {
                            anchors.fill: parent
                            radius: Appearance.rounding.small
                            color: row.recordingThis ? Appearance.colour.accentFill : plateTap.containsMouse ? Appearance.colour.fillStrong : Appearance.colour.fill
                            stroke: row.recordingThis ? Appearance.colour.accent : "transparent"
                            strokeWidth: row.recordingThis ? Appearance.font.stem : 0
                        }

                        StyledText {
                            id: plateText

                            anchors.centerIn: parent
                            text: plate.modelData
                            color: row.recordingThis ? Appearance.colour.text : Appearance.colour.textDim
                        }

                        MouseArea {
                            id: plateTap

                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: row.editable && !row.recordingThis
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.startRecord(row.modelData.id)
                        }
                    }
                }

                // The prose rows and the dynamic ones keep their chord as text.
                StyledText {
                    visible: !(row.editable || row.recordingThis)
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.chord
                    color: Appearance.colour.text
                }
            }

            StyledText {
                width: parent.width
                elide: Text.ElideRight
                text: row.status
                color: row.recordingThis ? Appearance.colour.textDim : Appearance.colour.textFaint
            }
        }

        MouseArea {
            id: rowTap

            anchors.fill: parent
            hoverEnabled: true
            enabled: !row.recordingThis
            cursorShape: row.editable || !row.modelData ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
                if (!row.modelData)
                    return row.clicked();
                if (row.editable)
                    root.editing = row.modelData.id;
            }
        }
    }

    // THE EDITOR. Opened under the row that was clicked -- for real, where
    // the user can find it. One column of fields in the row's place; Save
    // splices the line, Remove deletes it, Escape or Cancel touch nothing.
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
                label: "chord -- or click a row's keys above to record one"
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
