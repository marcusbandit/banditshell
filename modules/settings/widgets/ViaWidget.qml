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
    property bool askingKeymap: false

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

        function onStoredKeymapChanged(): void {
            if (Keyboards.storedKeymap)
                SettingsView.drop("the keys you bind will light up", "keyboard");
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
            detail: root.imported ? `${Keyboards.stored.replace(/\.json$/, "")} · ${Keyboards.board?.keys?.length ?? Keyboards.board?.cells?.length ?? 0} keys` : `nothing imported · drawing ${Keyboards.shape}`
            onPointed: SettingsView.hovered = root.row

            SettingsTool {
                anchors.verticalCenter: parent.verticalCenter
                icon: "info"
                tip: "a VIA definition: the .json your board's maker ships for usevia.app. its layouts.keymap is read. keys are named by where they sit, unless you also import a keymap below."
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

        SettingsRowFrame {
            width: parent.width
            interactive: false
            visible: root.imported
            icon: "keyboard_alt"
            label: "VIA keymap"
            detail: Keyboards.storedKeymap ? `${Keyboards.storedKeymap.replace(/\.keymap\.json$/, "")} · layer 0` : "optional · lights the keys you bind"
            onPointed: SettingsView.hovered = root.row

            SettingsTool {
                anchors.verticalCenter: parent.verticalCenter
                icon: "info"
                tip: "a keymap saved from VIA (Save + Load, Save). it says what each key does, so the keys you bind can light up. layer 0 is read, and it has to come from the same board as the layout."
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
                visible: !root.askingKeymap
                size: 0
                text: "Import"
                onClicked: {
                    root.askingKeymap = true;
                    Qt.callLater(keymapFile.take);
                }
            }

            SettingsField {
                id: keymapFile

                anchors.verticalCenter: parent.verticalCenter
                visible: root.askingKeymap
                placeholder: "~/Downloads/board.layout.json"
                onCommitted: t => {
                    root.askingKeymap = false;
                    if (t.trim())
                        Keyboards.useKeymap(t.trim());
                }
                onEditingChanged: if (!editing)
                    root.askingKeymap = false
            }
        }
    }
}
