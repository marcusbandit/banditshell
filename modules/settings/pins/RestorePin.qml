pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.modules.settings
import "../restore.js" as Restore

Column {
    id: root

    readonly property string documents: `${Quickshell.env("HOME")}/Documents`

    property string target: ""
    property bool listing: true
    property bool loading: false
    property var result: null

    readonly property string fileName: root.target.slice(root.target.lastIndexOf("/") + 1)
    readonly property var changes: root.result?.changes ?? []
    readonly property var skipped: root.result?.skipped ?? []
    readonly property string why: root.result?.why ?? ""
    readonly property var rows: root.changes.map(c => SettingsRestore.describe(c))

    readonly property string status: {
        if (root.target === "")
            return root.listing ? "" : `no copy in ${root.documents.replace(Quickshell.env("HOME"), "~")} yet · type where yours is`;
        if (root.loading)
            return "reading it";
        if (root.why)
            return root.why;
        if (!root.result)
            return "";
        if (root.changes.length === 0)
            return "nothing would change · this copy matches what you have";
        return `${Restore.summary(root.changes, root.skipped)} · nothing is written until you press Apply`;
    }

    spacing: Appearance.padding.card

    function expand(path: string): string {
        return path.startsWith("~") ? `${Quickshell.env("HOME")}${path.slice(1)}` : path;
    }

    function apply(): void {
        const count = SettingsRestore.apply(root.changes);
        const name = root.fileName;
        SettingsView.unpin();
        SettingsView.drop(`${count} ${count === 1 ? "setting" : "settings"} restored from ${name}`, "download");
    }

    onTargetChanged: {
        root.result = null;
        root.loading = root.target !== "";
    }

    StyledText {
        width: parent.width
        text: "Pick a copy made with Export. It is read and compared first; Apply is what writes."
        color: Appearance.colour.textDim
        wrapMode: Text.WordWrap
    }

    SettingsPathEdit {
        width: parent.width
        path: root.target.replace(Quickshell.env("HOME"), "~")
        browseTip: "type a path"
        onCommitted: p => root.target = root.expand(p)
    }

    StyledText {
        width: parent.width
        visible: text !== ""
        text: root.status
        color: root.why ? Appearance.colour.alarm : Appearance.colour.textFaint
        wrapMode: Text.WordWrap
    }

    Column {
        width: parent.width
        visible: root.rows.length > 0

        Repeater {
            model: root.rows

            delegate: SettingsRowFrame {
                required property var modelData

                width: parent.width
                interactive: false
                icon: modelData.icon
                label: modelData.label
                detail: modelData.detail
            }
        }
    }

    Column {
        width: parent.width
        visible: root.skipped.length > 0
        spacing: Appearance.padding.small

        StyledText {
            width: parent.width
            text: "skipped"
            color: Appearance.colour.textDim
        }

        Repeater {
            model: root.skipped

            delegate: StyledText {
                required property var modelData

                width: parent.width
                text: `${modelData.key} · ${modelData.why}`
                color: Appearance.colour.textFaint
                wrapMode: Text.WordWrap
            }
        }
    }

    Flow {
        width: parent.width
        spacing: Appearance.padding.small

        Button {
            visible: root.changes.length > 0
            size: 0
            style: "filled"
            text: "Apply"
            onClicked: root.apply()
        }

        Button {
            size: 0
            text: "Cancel"
            onClicked: SettingsView.unpin()
        }
    }

    Process {
        id: lister

        running: true
        command: ["sh", "-c", 'ls -1 "$1" 2>/dev/null', "sh", root.documents]

        stdout: StdioCollector {
            onStreamFinished: {
                const name = Restore.newest(text.split("\n"));
                root.listing = false;
                if (name && root.target === "")
                    root.target = `${root.documents}/${name}`;
            }
        }
    }

    FileView {
        path: root.target
        printErrors: false

        onLoaded: {
            root.loading = false;
            root.result = SettingsRestore.examine(text());
        }

        onLoadFailed: err => {
            root.loading = false;
            root.result = {
                why: err === FileViewError.FileNotFound ? "there is no file at that path" : "could not read that file",
                changes: [],
                skipped: []
            };
        }
    }
}
