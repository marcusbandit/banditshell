import QtQuick
import qs.config

// A password entry that appears under the row that needs it.
//
// It grabs focus when it becomes visible, because it only ever appears in answer
// to a press and having to click it again would be silly. Escape cancels, Enter
// accepts; a field you cannot get out of without using the mouse is the reason
// people dislike inline entry.
//
// While it is up it also REGISTERS itself, because window-local focus is not the
// keyboard: the surface it is drawn on gets no key events at all until its
// window asks the compositor for them, and the field is the only thing that
// knows one is wanted. Saying it here rather than in whatever menu holds the
// field means no menu has to remember to. See Prompts.
//
// It says only THAT it wants one, and never which surface it is on. There is a
// shell surface per screen and exactly one of them may take the keyboard, so the
// claim has to be answerable per window; Prompts asks the item where it is drawn
// rather than being told, precisely so that a field can go on knowing nothing
// about any of this. See Prompts.activeIn.
Item {
    id: root

    property string placeholder: ""

    signal accepted(string secret)
    signal cancelled

    implicitHeight: visible ? field.implicitHeight + Appearance.padding.normal * 2 : 0

    // Asking for the keyboard and having it are a round trip apart: the window
    // only asks once this field has said it wants one, and the compositor hands
    // it over a frame or more later. Focus taken before that lands is focus in a
    // surface with no keys to give, so it is taken again when the surface
    // actually becomes active. NOT through claim(), which empties the field:
    // activation can also come back mid-word.
    readonly property bool surfaceActive: root.Window.active
    onSurfaceActiveChanged: if (root.surfaceActive && root.visible)
        field.forceActiveFocus()

    function claim(): void {
        field.text = "";
        if (root.visible) {
            Prompts.request(root);
            field.forceActiveFocus();
        } else {
            Prompts.release(root);
        }
    }

    // Both: onVisibleChanged does not fire for an item CREATED already visible,
    // which is exactly how this one appears when its row rebuilds.
    onVisibleChanged: root.claim()
    Component.onCompleted: root.claim()

    // A menu closing destroys its rows outright, without them ever passing
    // through invisible, so the claim has to be given back here as well.
    Component.onDestruction: Prompts.release(root)

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
        font.pixelSize: Appearance.font.size.small
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
