import QtQuick
import qs.config

Item {
    id: root

    property string placeholder: ""

    signal accepted(string identity, string password, string eap, string phase2)
    signal cancelled

    readonly property var methods: ["peap", "ttls"]
    readonly property var inner: ["mschapv2", "pap"]

    property int method: 0

    implicitHeight: visible ? stack.implicitHeight : 0

    function submit(): void {
        if (!identity.text)
            identity.input.forceActiveFocus();
        else if (!password.text)
            password.input.forceActiveFocus();
        else
            root.accepted(identity.text, password.text, root.methods[root.method], root.inner[root.method]);
    }

    readonly property bool surfaceActive: root.Window.active
    onSurfaceActiveChanged: if (root.surfaceActive && root.visible)
        identity.input.forceActiveFocus()

    function claim(): void {
        identity.text = "";
        password.text = "";
        if (root.visible) {
            Prompts.request(root);
            identity.input.forceActiveFocus();
        } else {
            Prompts.release(root);
        }
    }

    onVisibleChanged: root.claim()
    Component.onCompleted: root.claim()
    Component.onDestruction: Prompts.release(root)

    component Entry: Item {
        id: entry

        property alias input: box
        property alias text: box.text
        property string hint: ""
        property bool secret: false

        property Item next: null

        signal entered
        signal escaped

        implicitHeight: box.implicitHeight + Appearance.padding.normal * 2

        SquircleRect {
            anchors.fill: parent
            anchors.topMargin: Appearance.padding.small
            anchors.bottomMargin: Appearance.padding.small
            radius: Appearance.rounding.small
            color: Appearance.colour.fillStrong
        }

        TextInput {
            id: box

            anchors.fill: parent
            anchors.leftMargin: Appearance.padding.normal
            anchors.rightMargin: Appearance.padding.normal

            verticalAlignment: TextInput.AlignVCenter
            echoMode: entry.secret ? TextInput.Password : TextInput.Normal
            clip: true

            font.family: Appearance.font.family
            font.pixelSize: Appearance.font.size.small
            renderType: Text.NativeRendering
            color: Appearance.colour.text
            selectionColor: Appearance.colour.accent
            selectedTextColor: Appearance.colour.accentText

            KeyNavigation.tab: entry.next

            onAccepted: entry.entered()

            Keys.onEscapePressed: entry.escaped()

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                visible: !box.text && !box.activeFocus
                text: entry.hint
                color: Appearance.colour.textFaint
                font.pixelSize: Appearance.font.size.small
            }
        }
    }

    Column {
        id: stack

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        Entry {
            id: identity

            width: parent.width
            hint: root.placeholder ? `username for ${root.placeholder}` : "username"
            next: password.input

            onEntered: root.submit()
            onEscaped: root.cancelled()
        }

        Entry {
            id: password

            width: parent.width
            hint: "password"
            secret: true

            onEntered: root.submit()
            onEscaped: root.cancelled()
        }

        Item {
            width: parent.width
            implicitHeight: pick.implicitHeight + Appearance.padding.small * 2

            StyledText {
                anchors.left: parent.left
                anchors.leftMargin: Appearance.padding.normal
                anchors.verticalCenter: parent.verticalCenter

                text: "sign-in method"
                color: Appearance.colour.textFaint
            }

            Segments {
                id: pick

                anchors.right: parent.right
                anchors.rightMargin: Appearance.padding.normal
                anchors.verticalCenter: parent.verticalCenter

                options: root.methods
                current: root.method
                onPicked: i => root.method = i
            }
        }
    }
}
