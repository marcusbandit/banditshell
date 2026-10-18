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

    property string busy: ""
    property string busyName: ""
    property var heldVerdict: null

    width: parent ? parent.width : 0
    implicitHeight: layer.implicitHeight

    onCustomChanged: if (!root.custom) {
        root.choosing = "";
        root.said = null;
    }

    function choose(which: string): void {
        root.choosing = root.choosing === which ? "" : which;
        if (root.choosing === "layout")
            layoutPicker.look();
        else if (root.choosing === "keymap")
            keymapPicker.look();
    }

    function check(which: string, name: string): void {
        root.choosing = "";
        root.said = null;
        root.heldVerdict = null;
        root.saidFor = which;
        root.busy = which;
        root.busyName = name;
        hold.restart();
        patience.restart();
    }

    function reveal(): void {
        const v = root.heldVerdict;
        root.heldVerdict = null;
        root.busy = "";
        patience.stop();
        root.said = v;
        if (v.ok)
            quiet.restart();
        else
            quiet.stop();
        SettingsView.drop(v.text, v.ok ? "keyboard" : "error");
    }

    function take(which: string, path: string): void {
        root.check(which, path.slice(path.lastIndexOf("/") + 1));
        if (which === "keymap")
            Keyboards.useKeymap(path);
        else
            Keyboards.use(path);
    }

    function trySample(): void {
        root.check("layout", "the sample board");
        const wanted = JSON.stringify(Boards.SAMPLE_VIA);
        if (sample.text() === wanted)
            Keyboards.use(sample.path);
        else
            sample.setText(wanted);
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
            if (!Keyboards.verdict)
                return;
            root.heldVerdict = Keyboards.verdict;
            if (!hold.running)
                root.reveal();
        }
    }

    Timer {
        id: hold

        interval: 1100
        onTriggered: if (root.heldVerdict)
            root.reveal()
    }

    Timer {
        id: patience

        interval: 10000
        onTriggered: {
            root.heldVerdict = {
                ok: false,
                detail: `${root.busyName} took too long to read`,
                text: `this is not it · ${root.busyName} took too long to read`
            };
            root.reveal();
        }
    }

    Timer {
        id: quiet

        interval: 15000
        onTriggered: root.said = null
    }

    Component {
        id: spinner

        ProgressRing {
            value: 0.28

            RotationAnimator on rotation {
                from: 0
                to: 360
                duration: 900
                loops: Animation.Infinite
                running: !Appearance.lessMotion
            }
        }
    }

    FileView {
        id: sample

        path: `${Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"}/banditshell-sample-board.json`
        printErrors: false
        onSaved: Keyboards.use(sample.path)
    }

    MenuLayer {
        id: layer

        width: root.width
        open: root.wanted

        SettingsRowFrame {
            readonly property bool checking: root.busy === "layout"

            width: parent.width
            interactive: false
            off: !root.custom
            icon: "upload_file"
            lead: checking ? spinner : null
            label: "VIA layout"
            detail: checking ? `checking ${root.busyName}…` : root.imported ? `${Keyboards.board.name || Keyboards.stored.replace(/\.json$/, "")} · ${Keyboards.keyCount} keys · ${Keyboards.variant.toUpperCase()}` : "nothing imported"
            detailColour: checking ? Appearance.colour.accent : Appearance.colour.textFaint
            detailLines: 2
            flashing: !!root.hear("layout")?.ok
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
                onClicked: if (!root.busy)
                    root.trySample()
            }

            Button {
                anchors.verticalCenter: parent.verticalCenter
                size: 0
                text: root.choosing === "layout" ? "Close" : "Import"
                interactive: !root.busy
                onClicked: root.choose("layout")
            }
        }

        Verdict {
            which: "layout"
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
            readonly property bool checking: root.busy === "keymap"

            width: parent.width
            interactive: false
            off: !root.custom || !root.imported
            icon: "keyboard_alt"
            lead: checking ? spinner : null
            label: "VIA keymap"
            detail: checking ? `checking ${root.busyName}…` : Keyboards.storedKeymap ? `${Keyboards.storedKeymap.replace(/\.keymap\.json$/, "")} · layer 0` : "nothing imported"
            detailColour: checking ? Appearance.colour.accent : Appearance.colour.textFaint
            detailLines: 2
            flashing: !!root.hear("keymap")?.ok
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
                interactive: !root.busy
                onClicked: root.choose("keymap")
            }
        }

        Verdict {
            which: "keymap"
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

    component Verdict: MenuLayer {
        id: verdict

        property string which: ""
        readonly property var heard: root.hear(verdict.which)

        property var shown: null

        width: parent.width
        open: !!verdict.heard

        onHeardChanged: if (verdict.heard)
            verdict.shown = verdict.heard

        SettingsRowFrame {
            width: parent.width
            interactive: false
            notice: !!verdict.shown?.ok
            icon: verdict.shown?.ok ? "check_circle" : "error"
            iconFill: 1
            iconColour: Appearance.colour.alarm
            label: verdict.shown?.ok ? "This is it" : "This is not it"
            detail: verdict.shown?.detail ?? ""
            detailColour: verdict.shown?.ok ? Appearance.colour.textDim : Appearance.colour.alarm
            detailLines: 4
            onPointed: SettingsView.hovered = root.row
        }
    }
}
