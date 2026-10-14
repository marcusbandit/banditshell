import QtQuick
import Quickshell.Io
import qs.config
import qs.components
import qs.services
import qs.modules.settings
import "../boards.js" as Boards

Item {
    id: root

    readonly property real stageHeight: 240
    readonly property string shape: SettingsState.v("sheetKeyboard")
    property var imported: null

    readonly property var keys: root.shape === "file" && root.imported ? Boards.withLegends(root.imported.keys, Keyboards.legends) : Boards.board(root.shape === "file" ? Keyboards.shape : root.shape)

    readonly property var hot: {
        const out = {};
        const sets = SettingsView.current === "shortcuts" ? SettingsKeys.shell.concat(SettingsKeys.files) : SettingsKeys.shell;
        for (const k of sets)
            for (const part of k.combo.split(" "))
                if (part) {
                    out[part] = true;
                    out[part === "return" ? "enter" : part === "page_up" ? "pgup" : part] = true;
                }
        return out;
    }

    FileView {
        path: Keyboards.path
        printErrors: false
        onLoaded: {
            try {
                root.imported = Boards.readVia(text());
            } catch (e) {
                root.imported = null;
            }
        }
        onLoadFailed: root.imported = null
    }

    KeyboardBoard {
        x: 16
        y: 20
        width: parent.width - 32
        height: parent.height - 20 - 48
        keys: root.keys
        hot: root.hot
    }

    SceneCaption {
        text: root.shape === "file" && root.imported ? `${root.imported.name} · ${root.keys.length} keys` : `${root.shape === "file" ? `no file yet · ${Keyboards.shape}` : `${root.shape} board`} · lit keys are bound`
    }
}
