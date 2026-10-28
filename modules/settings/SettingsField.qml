import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root

    property string text: ""
    property string placeholder: ""
    property bool mono: false
    property bool masked: false
    property bool alarm: false
    property bool steps: false
    property string pick: ""

    signal committed(string text)
    signal stepped(int by)

    readonly property alias editing: input.activeFocus
    readonly property string draft: input.text

    function clear(): void {
        input.text = "";
        input.text = Qt.binding(() => root.text);
    }

    implicitWidth: 200
    implicitHeight: 32

    function choose(chosen: string): void {
        input.text = chosen;
        root.committed(chosen);
        input.text = Qt.binding(() => root.text);
        input.focus = false;
    }

    function take(): void {
        input.forceActiveFocus();
        input.selectAll();
    }

    SquircleRect {
        anchors.fill: parent
        radius: Appearance.rounding.small
        color: Appearance.colour.fillStrong
        stroke: root.alarm ? Appearance.colour.alarm : input.activeFocus ? Appearance.colour.accent : "transparent"
        strokeWidth: root.alarm || input.activeFocus ? Appearance.stroke.ring : 0
    }

    TextInput {
        id: input

        anchors.fill: parent
        anchors.leftMargin: Appearance.padding.normal
        anchors.rightMargin: Appearance.padding.normal
        verticalAlignment: TextInput.AlignVCenter
        clip: true

        text: root.text
        font.family: root.mono ? Appearance.sizes.filesTerminalFont : Appearance.font.family
        font.pixelSize: Appearance.font.size.small
        renderType: Text.NativeRendering
        color: Appearance.colour.text
        selectionColor: Appearance.colour.accent
        selectedTextColor: Appearance.colour.accentText
        echoMode: root.masked ? TextInput.Password : TextInput.Normal

        onActiveFocusChanged: {
            if (activeFocus)
                Prompts.request(root);
            else {
                Prompts.release(root);
                if (input.text !== root.text)
                    root.committed(input.text);
            }
        }

        onAccepted: root.choose(root.pick || input.text)

        Keys.onUpPressed: event => {
            event.accepted = root.steps;
            if (root.steps)
                root.stepped(-1);
        }

        Keys.onDownPressed: event => {
            event.accepted = root.steps;
            if (root.steps)
                root.stepped(1);
        }

        Keys.onEscapePressed: event => {
            input.text = Qt.binding(() => root.text);
            input.focus = false;
            event.accepted = true;
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            visible: !input.text
            text: root.placeholder
            color: Appearance.colour.textFaint
            elide: Text.ElideRight
            width: parent.width
        }
    }

    Component.onDestruction: Prompts.release(root)
}
