import QtQuick
import qs.config

// A password entry that appears under the row that needs it.
//
// It grabs focus when it becomes visible, because it only ever appears in answer
// to a press and having to click it again would be silly. Escape cancels, Enter
// accepts; a field you cannot get out of without using the mouse is the reason
// people dislike inline entry.
Item {
    id: root

    property string placeholder: ""

    signal accepted(string secret)
    signal cancelled

    implicitHeight: visible ? field.implicitHeight + Appearance.padding.normal * 2 : 0

    onVisibleChanged: {
        field.text = "";
        if (visible)
            field.forceActiveFocus();
    }

    G2Rect {
        anchors.fill: parent
        anchors.topMargin: Appearance.padding.small
        anchors.bottomMargin: Appearance.padding.small
        radius: Appearance.rounding.small
        color: Appearance.colour.fillStrong
    }

    TextInput {
        id: field

        anchors.fill: parent
        anchors.leftMargin: Appearance.padding.normal
        anchors.rightMargin: Appearance.padding.normal

        verticalAlignment: TextInput.AlignVCenter
        echoMode: TextInput.Password
        clip: true

        font.family: Appearance.font.family
        font.pixelSize: Appearance.font.size.normal
        renderType: Text.NativeRendering
        color: Appearance.colour.text
        selectionColor: Appearance.colour.accent
        selectedTextColor: Appearance.colour.accentText

        onAccepted: if (text)
            root.accepted(text)

        Keys.onEscapePressed: root.cancelled()

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            visible: !field.text && !field.activeFocus
            text: root.placeholder
            color: Appearance.colour.textFaint
            font.pixelSize: Appearance.font.size.small
        }
    }
}
