import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.settings
import "../boards.js" as Boards
import "../../../services/keyboards.js" as KeyboardsJs

Item {
    id: root

    readonly property real stageHeight: 240
    readonly property string shape: SettingsState.v("sheetKeyboard")
    readonly property bool fromFile: root.shape === "file" && !!Keyboards.board

    readonly property var sections: root.fromFile ? Keyboards.board.sections : KeyboardsJs.templateSections(root.shape === "file" ? Keyboards.shape : KeyboardsJs.shapeNamed(root.shape)).filter(s => s.id !== "numpad")

    readonly property var keys: Boards.fromSheet(KeyboardsJs.flatten(root.sections))

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

    KeyboardBoard {
        x: 16
        y: 20
        width: parent.width - 32
        height: parent.height - 20 - 48
        keys: root.keys
        hot: root.hot
    }

    SceneCaption {
        text: root.fromFile ? `${Keyboards.board?.name || Keyboards.stored.replace(/\.json$/, "")} · ${Keyboards.keyCount} keys` : `${root.shape === "file" ? `no file yet · ${Keyboards.shape}` : `${root.shape} board`} · lit keys are bound`
    }
}
