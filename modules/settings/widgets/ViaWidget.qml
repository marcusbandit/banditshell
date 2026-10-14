import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.services
import qs.modules.settings
import "../boards.js" as Boards

Item {
    id: root

    property var row: ({})

    readonly property bool wanted: SettingsState.v("sheetBoard") && (Keyboards.stored !== "" || SettingsState.boardWanted)
    readonly property bool imported: Keyboards.stored !== "" && !!Keyboards.board
    property bool asking: false

    width: parent ? parent.width : 0
    implicitHeight: layer.implicitHeight

    Connections {
        target: Keyboards

        function onErrorChanged(): void {
            if (Keyboards.error)
                SettingsView.drop(Keyboards.error, "error");
        }

        function onStoredChanged(): void {
            if (Keyboards.stored) {
                SettingsState.boardWanted = false;
                SettingsView.drop(`drawing ${Keyboards.stored.replace(/\.json$/, "")}`, "keyboard");
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
            width: parent.width
            interactive: false
            icon: "upload_file"
            label: "VIA layout"
            detail: root.imported ? `${Keyboards.stored.replace(/\.json$/, "")} · ${Keyboards.board?.keys?.length ?? Keyboards.board?.cells?.length ?? 0} keys` : "nothing imported · drawing ansi"
            onPointed: SettingsView.hovered = root.row

            SettingsTool {
                anchors.verticalCenter: parent.verticalCenter
                icon: "info"
                tip: "a VIA definition: the .json your board's maker ships for usevia.app. its layouts.keymap is read; legends come from the shell's binds."
            }

            SettingsTool {
                anchors.verticalCenter: parent.verticalCenter
                visible: Keyboards.stored !== ""
                icon: "close"
                tip: "forget it"
                onClicked: Keyboards.clear()
            }

            SettingsTool {
                anchors.verticalCenter: parent.verticalCenter
                visible: Keyboards.stored === ""
                icon: "science"
                tip: "try a sample board"
                onClicked: sample.setText(JSON.stringify(Boards.SAMPLE_VIA))
            }

            Button {
                anchors.verticalCenter: parent.verticalCenter
                visible: !root.asking
                size: 0
                text: "Import"
                onClicked: {
                    root.asking = true;
                    Qt.callLater(file.take);
                }
            }

            SettingsField {
                id: file

                anchors.verticalCenter: parent.verticalCenter
                visible: root.asking
                placeholder: "~/Downloads/board.json"
                onCommitted: t => {
                    root.asking = false;
                    if (t.trim())
                        Keyboards.use(t.trim());
                }
                onEditingChanged: if (!editing)
                    root.asking = false
            }
        }
    }
}
