import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.services
import qs.modules.settings
import "../boards.js" as Boards
import "../../../services/keyboards.js" as KeyboardsJs

Item {
    id: root

    property var row: ({})

    readonly property bool wanted: SettingsState.v("sheetBoard")
    readonly property bool custom: SettingsState.v("sheetKeyboard") === "file"
    readonly property bool imported: Keyboards.stored !== "" && !!Keyboards.board
    property string choosing: ""

    property var said: null
    property string saidFor: ""

    width: parent ? parent.width : 0
    implicitHeight: layer.implicitHeight

    onCustomChanged: if (!root.custom)
        root.choosing = ""

    function choose(which: string): void {
        root.choosing = root.choosing === which ? "" : which;
        if (root.choosing === "layout")
            layoutPicker.look();
        else if (root.choosing === "keymap")
            keymapPicker.look();
    }

    function take(which: string, path: string): void {
        root.choosing = "";
        root.saidFor = which;
        if (which === "keymap")
            Keyboards.useKeymap(path);
        else
            Keyboards.use(path);
    }

    function trySample(): void {
        const wanted = JSON.stringify(Boards.SAMPLE_VIA);
        if (sample.text() === wanted) {
            root.saidFor = "layout";
            Keyboards.use(sample.path);
        } else {
            sample.setText(wanted);
        }
    }

    function openFile(name: string): void {
        Quickshell.execDetached(["xdg-open", `${Keyboards.dir}/${name}`]);
    }

    function hear(which: string): var {
        return root.said && root.saidFor === which ? root.said : null;
    }

    function layoutSummary(text: string): var {
        const parsed = KeyboardsJs.parseVia(text);
        if (parsed.error)
            return null;
        const board = KeyboardsJs.alignBoard(parsed);
        return [parsed.name, `${board.sections[0].keys.length} keys`, board.variant].filter(s => s).join(" · ");
    }

    function keymapSummary(text: string): var {
        const parsed = KeyboardsJs.parseKeymap(text);
        if (parsed.error || !Keyboards.definition || KeyboardsJs.keymapLegends(Keyboards.definition, parsed).error)
            return null;
        return [parsed.name, "layer 0"].filter(s => s).join(" · ");
    }

    Connections {
        target: Keyboards

        function onErrorChanged(): void {
            if (Keyboards.error)
                SettingsView.drop(Keyboards.error, "error");
        }

        function onVerdictChanged(): void {
            const v = Keyboards.verdict;
            if (!v)
                return;
            root.said = v;
            quiet.restart();
            SettingsView.drop(v.text, v.ok ? "keyboard" : "error");
        }
    }

    Timer {
        id: quiet

        interval: 9000
        onTriggered: root.said = null
    }

    FileView {
        id: sample

        path: `${Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"}/banditshell-sample-board.json`
        printErrors: false
        onSaved: {
            root.saidFor = "layout";
            Keyboards.use(sample.path);
        }
    }

    MenuLayer {
        id: layer

        width: root.width
        open: root.wanted

        SettingsRowFrame {
            readonly property var heard: root.hear("layout")

            width: parent.width
            interactive: false
            off: !root.custom
            icon: "upload_file"
            label: "VIA layout"
            detail: heard ? heard.text : root.imported ? `${Keyboards.board.name || Keyboards.stored.replace(/\.json$/, "")} · ${Keyboards.keyCount} keys · ${Keyboards.variant}` : "nothing imported"
            detailColour: heard ? (heard.ok ? Appearance.colour.accent : Appearance.colour.alarm) : Appearance.colour.textFaint
            flashing: !!heard && heard.ok
            onPointed: SettingsView.hovered = root.row

            SettingsTool {
                anchors.verticalCenter: parent.verticalCenter
                visible: Keyboards.stored !== ""
                icon: "edit_document"
                tip: "open the file"
                onClicked: root.openFile(Keyboards.stored)
            }

            SettingsTool {
                anchors.verticalCenter: parent.verticalCenter
                visible: Keyboards.stored !== ""
                icon: "close"
                tip: "forget it"
                onClicked: {
                    SettingsState.boardWanted = true;
                    Keyboards.clear();
                }
            }

            SettingsTool {
                anchors.verticalCenter: parent.verticalCenter
                visible: Keyboards.stored === ""
                icon: "science"
                tip: "try a sample board"
                onClicked: root.trySample()
            }

            Button {
                anchors.verticalCenter: parent.verticalCenter
                size: 0
                text: root.choosing === "layout" ? "Close" : "Import"
                onClicked: root.choose("layout")
            }
        }

        MenuLayer {
            width: parent.width
            open: root.choosing === "layout"

            SettingsFilePicker {
                id: layoutPicker

                row: root.row
                title: "VIA layout"
                kind: "VIA layouts"
                check: text => root.layoutSummary(text)
                onPicked: path => root.take("layout", path)
            }
        }

        SettingsRowFrame {
            readonly property var heard: root.hear("keymap")

            width: parent.width
            interactive: false
            off: !root.custom || !root.imported
            icon: "keyboard_alt"
            label: "VIA keymap"
            detail: heard ? heard.text : Keyboards.storedKeymap ? `${Keyboards.storedKeymap.replace(/\.keymap\.json$/, "")} · layer 0` : "nothing imported"
            detailColour: heard ? (heard.ok ? Appearance.colour.accent : Appearance.colour.alarm) : Appearance.colour.textFaint
            flashing: !!heard && heard.ok
            onPointed: SettingsView.hovered = root.row

            SettingsTool {
                anchors.verticalCenter: parent.verticalCenter
                visible: Keyboards.storedKeymap !== ""
                icon: "edit_document"
                tip: "open the file"
                onClicked: root.openFile(Keyboards.storedKeymap)
            }

            SettingsTool {
                anchors.verticalCenter: parent.verticalCenter
                visible: Keyboards.storedKeymap !== ""
                icon: "close"
                tip: "forget it"
                onClicked: Keyboards.clearKeymap()
            }

            Button {
                anchors.verticalCenter: parent.verticalCenter
                size: 0
                text: root.choosing === "keymap" ? "Close" : "Import"
                onClicked: root.choose("keymap")
            }
        }

        MenuLayer {
            width: parent.width
            open: root.choosing === "keymap"

            SettingsFilePicker {
                id: keymapPicker

                row: root.row
                title: "VIA keymap"
                kind: "keymaps for this board"
                check: text => root.keymapSummary(text)
                onPicked: path => root.take("keymap", path)
            }
        }
    }
}
