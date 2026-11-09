import QtQuick
import qs.config
import qs.components

Item {
    id: root

    property var argument: null
    property string text: ""
    property string completion: ""
    property bool missing: false
    readonly property alias input: input
    readonly property bool focused: input.activeFocus

    signal edited(string text)
    signal pressed(var event)

    implicitWidth: Math.max(placeholder.implicitWidth, input.contentWidth + ghost.implicitWidth) + Appearance.padding.normal * 2
    implicitHeight: input.implicitHeight + Appearance.padding.small * 2

    function focusEnd(): void {
        input.forceActiveFocus();
        input.cursorPosition = input.text.length;
    }

    SquircleRect {
        anchors.fill: parent
        radius: Appearance.rounding.small
        color: root.focused ? Appearance.colour.fillStrong : Appearance.colour.fill
        strokeWidth: root.missing || root.focused ? 1 : 0
        stroke: root.missing ? Appearance.colour.alarm : Appearance.colour.accent
    }

    TextInput {
        id: input

        x: Appearance.padding.normal
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(1, contentWidth)
        text: root.text
        font.family: Appearance.font.family
        font.pixelSize: Appearance.font.size.normal
        renderType: Text.NativeRendering
        color: Appearance.colour.text
        selectionColor: Appearance.colour.accent
        selectedTextColor: Appearance.colour.accentText
        cursorVisible: activeFocus

        onTextEdited: root.edited(input.text)
        Keys.onPressed: event => root.pressed(event)
    }

    StyledText {
        id: ghost

        anchors.left: input.right
        anchors.verticalCenter: parent.verticalCenter
        visible: input.activeFocus && text !== ""
        text: root.completion
        font.pixelSize: Appearance.font.size.normal
        color: Appearance.colour.textFaint
    }

    StyledText {
        id: placeholder

        x: Appearance.padding.normal
        anchors.verticalCenter: parent.verticalCenter
        visible: !input.text
        text: root.argument?.placeholder ?? ""
        font.pixelSize: Appearance.font.size.normal
        color: Appearance.colour.textFaint
        rightPadding: Appearance.padding.normal
    }
}
