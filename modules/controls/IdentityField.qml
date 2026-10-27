pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import qs.config
import qs.components
import qs.services

Item {
    id: root

    property string placeholder: ""

    property var methods: ["peap", "ttls", "tls"]
    property string refusal: ""
    property string domain: ""
    property string note: ""
    property bool noteIsTrouble: false
    property string suggestion: ""
    property bool busy: false

    signal accepted(var form, string password)
    signal check(var form)
    signal cancelled

    property int method: 0
    property int trust: 0

    readonly property string methodName: root.methods[Math.min(root.method, root.methods.length - 1)] ?? ""
    readonly property bool tls: root.methodName === "tls"
    readonly property bool canCheck: root.methods.includes("peap")
    readonly property bool needsServer: !server.text.trim() && root.trust === 0

    property var found: []
    property Item target: authority

    implicitHeight: visible ? stack.implicitHeight : 0

    function form(): var {
        return {
            method: root.methodName,
            identity: identity.text,
            domain: server.text,
            authority: root.trust === 1 ? authority.text.trim() : "",
            certificate: root.tls ? certificate.text.trim() : "",
            key: root.tls ? (key.text.trim() || certificate.text.trim()) : "",
            locked: root.tls && !!password.text
        };
    }

    function submit(): void {
        if (root.refusal || root.busy)
            return;
        if (root.needsServer && root.canCheck && !root.tls)
            return root.check(root.form());
        if (!identity.text)
            identity.input.forceActiveFocus();
        else if (!root.tls && !password.text)
            password.input.forceActiveFocus();
        else if (root.tls && !certificate.text.trim())
            certificate.input.forceActiveFocus();
        else if (root.trust === 1 && !authority.text.trim())
            authority.input.forceActiveFocus();
        else if (root.needsServer)
            server.input.forceActiveFocus();
        else {
            const filled = root.form();
            const secret = password.text;
            password.text = "";
            root.accepted(filled, secret);
        }
    }

    readonly property bool surfaceActive: root.Window.active
    onSurfaceActiveChanged: if (root.surfaceActive && root.visible && !root.refusal)
        identity.input.forceActiveFocus()

    function claim(): void {
        identity.text = "";
        password.text = "";
        server.text = root.domain;
        if (root.visible && !root.refusal) {
            Prompts.request(root);
            identity.input.forceActiveFocus();
            files.running = true;
        } else {
            Prompts.release(root);
        }
    }

    onVisibleChanged: root.claim()
    Component.onCompleted: root.claim()
    Component.onDestruction: Prompts.release(root)

    Process {
        id: files

        command: ["sh", "-c", "find \"$HOME/Downloads\" \"$HOME/Documents\" -maxdepth 2 -type f \\( -iname '*.pem' -o -iname '*.crt' -o -iname '*.cer' -o -iname '*.der' -o -iname '*.p12' -o -iname '*.pfx' -o -iname '*.key' \\) -printf '%T@\\t%p\\n' 2>/dev/null | sort -rn | head -n 4 | cut -f2-; true"]

        stdout: StdioCollector {
            onStreamFinished: root.found = text.split("\n").filter(line => line.startsWith("/"))
        }
    }

    component Entry: Item {
        id: entry

        property alias input: box
        property alias text: box.text
        property string hint: ""
        property bool secret: false
        property bool file: false

        property Item next: null

        implicitHeight: visible ? box.implicitHeight + Appearance.padding.normal * 2 : 0

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

            onActiveFocusChanged: if (box.activeFocus && entry.file)
                root.target = entry

            onAccepted: root.submit()

            Keys.onEscapePressed: root.cancelled()

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                visible: !box.text && !box.activeFocus
                text: entry.hint
                color: Appearance.colour.textFaint
                font.pixelSize: Appearance.font.size.small
            }
        }
    }

    component Line: StyledText {
        width: parent.width
        leftPadding: Appearance.padding.normal
        rightPadding: Appearance.padding.normal
        topPadding: Appearance.padding.small
        bottomPadding: Appearance.padding.small
        wrapMode: Text.Wrap
        color: Appearance.colour.textFaint
        font.pixelSize: Appearance.font.size.small
    }

    component Choice: Item {
        id: choice

        property string label: ""
        property alias options: pick.options
        property alias current: pick.current

        signal picked(int index)

        implicitHeight: visible ? pick.implicitHeight + Appearance.padding.small * 2 : 0

        StyledText {
            anchors.left: parent.left
            anchors.leftMargin: Appearance.padding.normal
            anchors.verticalCenter: parent.verticalCenter

            text: choice.label
            color: Appearance.colour.textFaint
        }

        Segments {
            id: pick

            anchors.right: parent.right
            anchors.rightMargin: Appearance.padding.normal
            anchors.verticalCenter: parent.verticalCenter

            onPicked: i => choice.picked(i)
        }
    }

    Column {
        id: stack

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        Line {
            visible: !!root.refusal
            text: root.refusal
            color: Appearance.colour.textDim
        }

        Item {
            width: parent.width
            implicitHeight: fields.implicitHeight
            visible: !root.refusal

            Column {
                id: fields

                width: parent.width
                spacing: 0

                Line {
                    text: root.tls ? `${root.placeholder} lets you on with a certificate from your school or work.` : `${root.placeholder} lets you on with your school or work account.`
                }

                Entry {
                    id: identity

                    width: parent.width
                    hint: root.placeholder ? `username for ${root.placeholder}` : "username"
                    next: password.input
                }

                Entry {
                    id: password

                    width: parent.width
                    hint: root.tls ? "key password, if it has one" : "password"
                    secret: true
                    next: server.input
                }

                Entry {
                    id: certificate

                    width: parent.width
                    visible: root.tls
                    hint: "your certificate file"
                    file: true
                    next: key.input
                }

                Entry {
                    id: key

                    width: parent.width
                    visible: root.tls
                    hint: "its key file, if separate"
                    file: true
                    next: server.input
                }

                Entry {
                    id: server

                    width: parent.width
                    hint: "server name, such as school.edu"
                    next: identity.input
                }

                Line {
                    text: root.needsServer && root.canCheck && !root.tls ? "Not sure of the server name? Look it up first. Nothing secret is sent." : root.tls ? "Your certificate only goes to a server with this name." : "Your password only goes to a server with this name."
                }

                Choice {
                    width: parent.width
                    label: "trusted by"
                    options: ["system", "a file"]
                    current: root.trust
                    onPicked: i => {
                        root.trust = i;
                        if (i === 1) {
                            root.target = authority;
                            authority.input.forceActiveFocus();
                        }
                    }
                }

                Entry {
                    id: authority

                    width: parent.width
                    visible: root.trust === 1
                    hint: "the server's certificate file"
                    file: true
                }

                Flow {
                    width: parent.width
                    leftPadding: Appearance.padding.normal
                    rightPadding: Appearance.padding.normal
                    spacing: Appearance.padding.small
                    visible: (root.trust === 1 || root.tls) && root.found.length > 0

                    Repeater {
                        model: root.found

                        Button {
                            required property string modelData

                            size: 0
                            style: "bare"
                            icon: "description"
                            text: modelData.slice(modelData.lastIndexOf("/") + 1)
                            onClicked: root.target.text = modelData
                        }
                    }
                }

                Choice {
                    width: parent.width
                    visible: root.methods.length > 1
                    label: "sign-in method"
                    options: root.methods
                    current: root.method
                    onPicked: i => root.method = i
                }

                Line {
                    visible: !!root.note
                    text: root.note
                    color: root.noteIsTrouble ? Appearance.colour.warning : Appearance.colour.textDim
                }

                Item {
                    width: parent.width
                    visible: !!root.suggestion && server.text.trim() !== root.suggestion
                    implicitHeight: visible ? use.implicitHeight + Appearance.padding.small * 2 : 0

                    Button {
                        id: use

                        anchors.left: parent.left
                        anchors.leftMargin: Appearance.padding.normal
                        anchors.right: parent.right
                        anchors.rightMargin: Appearance.padding.normal
                        anchors.verticalCenter: parent.verticalCenter

                        size: 0
                        text: `Use ${root.suggestion}`
                        onClicked: server.text = root.suggestion
                    }
                }

                Item {
                    width: parent.width
                    implicitHeight: act.implicitHeight + Appearance.padding.small * 2

                    Button {
                        id: act

                        anchors.right: parent.right
                        anchors.rightMargin: Appearance.padding.normal
                        anchors.verticalCenter: parent.verticalCenter

                        size: 0
                        interactive: !root.busy
                        text: root.busy ? "Looking…" : root.needsServer && root.canCheck && !root.tls ? "Look up the server" : "Sign in"
                        onClicked: root.submit()
                    }
                }
            }
        }
    }
}
