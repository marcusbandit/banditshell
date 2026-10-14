import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.modules.settings

Column {
    id: root

    readonly property string pinId: SettingsView.pin?.id ?? ""
    readonly property bool shell: root.pinId.startsWith("shell:")
    readonly property var key: SettingsKeys.find(root.pinId)
    property bool listening: false

    spacing: Appearance.padding.card

    onPinIdChanged: root.listening = false

    readonly property var named: ({
            [Qt.Key_Space]: "space",
            [Qt.Key_Return]: "return",
            [Qt.Key_Enter]: "return",
            [Qt.Key_Tab]: "tab",
            [Qt.Key_Backspace]: "backspace",
            [Qt.Key_Delete]: "delete",
            [Qt.Key_Left]: "left",
            [Qt.Key_Right]: "right",
            [Qt.Key_Up]: "up",
            [Qt.Key_Down]: "down",
            [Qt.Key_Home]: "home",
            [Qt.Key_End]: "end",
            [Qt.Key_PageUp]: "page_up",
            [Qt.Key_PageDown]: "page_down",
            [Qt.Key_Print]: "print",
            [Qt.Key_Insert]: "insert",
            [Qt.Key_Slash]: "/",
            [Qt.Key_Comma]: ",",
            [Qt.Key_Period]: ".",
            [Qt.Key_Minus]: "-",
            [Qt.Key_Equal]: "=",
            [Qt.Key_QuoteLeft]: "`"
        })

    function nameOf(event: var): string {
        const k = event.key;
        if (k >= Qt.Key_A && k <= Qt.Key_Z)
            return String.fromCharCode(97 + k - Qt.Key_A);
        if (k >= Qt.Key_0 && k <= Qt.Key_9)
            return String.fromCharCode(48 + k - Qt.Key_0);
        if (k >= Qt.Key_F1 && k <= Qt.Key_F24)
            return `f${k - Qt.Key_F1 + 1}`;
        if (root.named[k])
            return root.named[k];
        return (event.text || "").toLowerCase().trim();
    }

    function take(event: var): void {
        const k = event.key;
        if (k === Qt.Key_Control || k === Qt.Key_Shift || k === Qt.Key_Alt || k === Qt.Key_Meta || k === Qt.Key_Super_L || k === Qt.Key_Super_R)
            return;
        event.accepted = true;
        root.listening = false;
        if (k === Qt.Key_Escape)
            return;
        const name = root.nameOf(event);
        if (!name)
            return;
        const m = event.modifiers;
        const combo = [m & Qt.MetaModifier ? "super" : "", m & Qt.ControlModifier ? "ctrl" : "", m & Qt.AltModifier ? "alt" : "", m & Qt.ShiftModifier ? "shift" : "", name].filter(Boolean).join(" ");
        const said = SettingsKeys.rebind(root.pinId, combo);
        if (said)
            SettingsView.drop(said, "swap_horiz");
    }

    ShortcutInhibitor {
        window: root.QsWindow.window
        enabled: root.listening
    }

    Item {
        width: parent.width
        height: 200

        SquircleRect {
            anchors.fill: parent
            radius: Appearance.rounding.large
            color: Appearance.colour.fill
        }

        KeyCaps {
            anchors.centerIn: parent
            scale: 1.4
            combo: root.key?.combo ?? ""
            listening: root.listening
        }

        Item {
            id: listener

            focus: root.listening
            Keys.onPressed: event => root.take(event)
            onActiveFocusChanged: if (!activeFocus)
                root.listening = false
        }
    }

    StyledText {
        width: parent.width
        text: `${root.shell ? "Written to the shell’s own include in Hyprland." : "Only works while Files has focus."} If another action already uses the keys, it moves here.`
        color: Appearance.colour.textDim
        wrapMode: Text.WordWrap
    }

    StyledText {
        width: parent.width
        visible: !root.shell
        textFormat: Text.StyledText
        text: `config <font color="${Appearance.colour.textDim}">files.keys</font>`
        color: Appearance.colour.textFaint
    }

    Button {
        size: 0
        style: "filled"
        text: root.listening ? "Listening" : "Change"
        interactive: !root.listening
        onClicked: {
            root.listening = true;
            listener.forceActiveFocus();
        }
    }
}
