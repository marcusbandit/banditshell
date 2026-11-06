import QtQuick
import qs.config
import qs.components
import qs.services

Column {
    id: root

    readonly property var kinds: ["open", "wpa", "sae"]

    property int kind: 1

    readonly property bool needsPassword: root.kinds[root.kind] !== "open"

    property bool busy: false
    property string joining: ""
    property string trouble: ""
    property bool capsLock: false

    property string sentName: ""

    signal submitted(string name, string security, string password)
    signal finished
    signal cancelled
    signal capsAsked

    spacing: Appearance.padding.small

    function submit(typed: string): void {
        if (root.busy || !name.text.trim())
            return;
        root.sentName = name.text.trim();
        root.submitted(root.sentName, root.kinds[root.kind], root.needsPassword ? typed || secret.value : "");
    }

    function settled(joined: string, ok: bool): void {
        if (ok && root.sentName && joined === root.sentName) {
            root.sentName = "";
            root.finished();
        }
    }

    function claim(): void {
        if (root.visible) {
            Prompts.request(name);
            name.forceActiveFocus();
        } else {
            Prompts.release(name);
        }
    }

    onVisibleChanged: root.claim()
    Component.onCompleted: root.claim()
    Component.onDestruction: Prompts.release(name)

    StyledText {
        width: parent.width
        leftPadding: Appearance.padding.normal
        text: "Join a hidden network"
        color: Appearance.colour.textDim
        font.pixelSize: Appearance.font.size.small
    }

    Item {
        id: box

        width: parent.width
        implicitHeight: name.implicitHeight + Appearance.padding.normal * 2 + Appearance.padding.small * 2

        SquircleRect {
            anchors.fill: parent
            anchors.topMargin: Appearance.padding.small
            anchors.bottomMargin: Appearance.padding.small
            radius: Appearance.rounding.small
            color: Appearance.colour.fillStrong
            opacity: root.busy ? Appearance.opacity.disabled : 1
        }

        TextInput {
            id: name

            readonly property bool typable: true

            anchors.fill: parent
            anchors.leftMargin: Appearance.padding.normal
            anchors.rightMargin: Appearance.padding.normal

            enabled: !root.busy
            verticalAlignment: TextInput.AlignVCenter
            clip: true
            maximumLength: 32
            activeFocusOnTab: true

            font.family: Appearance.font.family
            font.pixelSize: Appearance.font.size.small
            renderType: Text.NativeRendering
            color: Appearance.colour.text
            selectionColor: Appearance.colour.accent
            selectedTextColor: Appearance.colour.accentText

            onAccepted: {
                if (root.needsPassword)
                    secret.forceActiveFocus();
                else
                    root.submit("");
            }

            Keys.onEscapePressed: root.cancelled()

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                visible: !name.text && !name.activeFocus
                text: "network name"
                color: Appearance.colour.textFaint
                font.pixelSize: Appearance.font.size.small
            }
        }
    }

    Segments {
        width: parent.width
        options: ["Open", "WPA", "WPA3"]
        current: root.kind
        onPicked: i => root.kind = i
    }

    SecretField {
        id: secret

        width: parent.width
        visible: root.needsPassword
        busy: root.busy
        placeholder: "password"
        alarm: !!root.trouble
        capsLock: root.capsLock
        onCapsAsked: root.capsAsked()
        onAccepted: typed => root.submit(typed)
        onCancelled: root.cancelled()
    }

    StyledText {
        width: parent.width
        leftPadding: Appearance.padding.normal
        visible: !!root.trouble || root.busy
        text: root.busy ? `joining ${root.joining}` : root.trouble
        color: root.trouble && !root.busy ? Appearance.colour.alarm : Appearance.colour.textFaint
        font.pixelSize: Appearance.font.size.small
        wrapMode: Text.WordWrap
    }

    Row {
        spacing: Appearance.padding.small
        leftPadding: Appearance.padding.normal

        Button {
            size: 0
            style: "accent"
            text: root.busy ? "Joining" : "Join"
            interactive: !root.busy && name.text.trim().length > 0
            onClicked: root.submit("")
        }

        Button {
            size: 0
            text: "Cancel"
            onClicked: root.cancelled()
        }
    }
}
