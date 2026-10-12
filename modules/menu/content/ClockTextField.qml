import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root

    property string placeholder: ""

    property bool autoFocus: true

    property string seed: ""

    readonly property string value: input.text

    signal accepted(string text)
    signal committed(string text)
    signal cancelled

    implicitHeight: input.implicitHeight + Appearance.padding.small * 2
    height: implicitHeight

    function claim(): void {
        if (root.visible && root.autoFocus) {
            input.text = root.seed;
            Prompts.request(root);
            input.forceActiveFocus();
        } else if (!root.visible) {
            Prompts.release(root);
        }
    }

    function cancel(): void {
        input.text = root.seed;
        input.focus = false;
        Prompts.release(root);
        root.cancelled();
    }

    readonly property bool surfaceActive: root.Window.active
    onSurfaceActiveChanged: if (root.surfaceActive && root.visible && root.autoFocus)
        input.forceActiveFocus()

    onVisibleChanged: root.claim()
    Component.onCompleted: {
        input.text = root.seed;
        root.claim();
    }
    Component.onDestruction: Prompts.release(root)

    onSeedChanged: if (!input.activeFocus)
        input.text = root.seed

    SquircleRect {
        anchors.fill: parent
        anchors.topMargin: Appearance.padding.small
        anchors.bottomMargin: Appearance.padding.small
        radius: Appearance.rounding.small
        color: Appearance.colour.fillStrong
    }

    TextInput {
        id: input

        anchors.fill: parent
        anchors.leftMargin: Appearance.padding.normal
        anchors.rightMargin: Appearance.padding.normal

        verticalAlignment: TextInput.AlignVCenter
        clip: true

        font.family: Appearance.font.family
        font.pixelSize: Appearance.font.size.small
        renderType: Text.NativeRendering
        color: Appearance.colour.text
        selectionColor: Appearance.colour.accent
        selectedTextColor: Appearance.colour.accentText

        onAccepted: root.accepted(input.text)
        onEditingFinished: if (input.text !== root.seed)
            root.committed(input.text)

        Keys.onEscapePressed: root.cancel()

        onActiveFocusChanged: {
            if (input.activeFocus)
                Prompts.request(root);
            else if (!root.autoFocus)
                Prompts.release(root);
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter

            visible: !input.text && !input.activeFocus
            text: root.placeholder
            color: Appearance.colour.textFaint
            font.pixelSize: Appearance.font.size.small
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: !root.autoFocus
        cursorShape: Qt.IBeamCursor
        onClicked: {
            Prompts.request(root);
            input.forceActiveFocus();
        }
    }
}
