pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland._ShortcutsInhibitor
import qs.config
import qs.components
import qs.services
import qs.modules.settings
import "../../../services/hyprgen.js" as HyprGen

Item {
    id: root

    implicitHeight: list.implicitHeight

    property string editing: ""

    onEditingChanged: {
        if (root.editing !== "")
            Prompts.request(root);
        else
            Prompts.release(root);
    }

    Component.onDestruction: Prompts.release(root)

    property string filter: ""

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

    property string recording: ""

    property var held: ({})
    property var capMods: []
    property string capKey: ""

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

    ShortcutInhibitor {
        id: grab

        window: QsWindow.window
        enabled: root.recording !== ""
        onCancelled: root.cancelRecord()
    }

    Timer {
        interval: 2000
        running: root.recording !== "" && !grab.active
        onTriggered: {
            console.warn("Keybinds: the compositor never granted the keyboard; recording cancelled.");
            root.cancelRecord();
        }
    }

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

            if (root.capKey !== "")
                root.commitRecord();
            else {
                root.capMods = [];
            }
        }
    }

    component Section: SettingsGroup {}

    Column {
        id: list

        width: parent.width
        spacing: Appearance.padding.huge

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

    component BindRow: Item {
        id: row

        required property var modelData

        signal clicked

        property string icon: modelData?.dynamic ? "auto_awesome" : "keyboard"
        property string chord: modelData?.chord || "(no chord)"

        property string sub: !modelData ? "" : modelData.dynamic ? modelData.raw : (modelData.cmd || modelData.expr)
        readonly property bool editable: !!modelData && !modelData.dynamic

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

        SquircleRect {
            anchors.fill: parent
            radius: Appearance.rounding.small
            color: row.recordingThis || rowTap.containsMouse ? Appearance.colour.fillStrong : Appearance.colour.fill
        }

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

            Row {
                spacing: Appearance.padding.small

                Repeater {
                    model: row.editable || row.recordingThis ? row.plateTokens : []

                    delegate: Item {
                        id: plate

                        required property string modelData

                        width: plateText.implicitWidth + Appearance.padding.normal * 2
                        height: row.plateH

                        SquircleRect {
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

    component BindEditor: Item {
        id: editor

        property var bind: null
        property string file: ""

        readonly property bool isAdd: bind === null

        readonly property bool isExec: !isAdd && /^hl\.dsp\.exec_cmd\(/.test(bind.expr)

        implicitHeight: column.implicitHeight

        function save(): void {
            const fields = {
                chord: chordInput.text.trim(),

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

        Component.onCompleted: chordInput.take()
    }

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

        SquircleRect {
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
