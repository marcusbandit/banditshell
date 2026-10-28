pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.services
import "certificate-files.js" as CertificateFiles

Item {
    id: root

    property string placeholder: ""

    property var methods: ["peap", "ttls", "tls"]
    property string refusal: ""
    property string domain: ""
    property string note: ""
    property bool noteIsTrouble: false
    property bool noteWarns: false
    property string suggestion: ""
    property string fill: ""
    property bool busy: false
    property bool checking: false
    property var readServer: text => text.trim()
    property var schoolOf: (domain, identity) => null
    property var innerOf: method => []
    property var innerLabel: inner => inner.toUpperCase()
    property var outerOf: (method, identity) => ""

    signal accepted(var form, string password)
    signal check(var form)
    signal cancelled

    property int method: 0
    property string trust: "auto"
    property bool more: false
    property var inner: ({})

    readonly property string methodName: root.methods[Math.min(root.method, root.methods.length - 1)] ?? ""
    readonly property bool tls: root.methodName === "tls"
    readonly property bool canCheck: root.methods.includes("peap")
    readonly property bool needsServer: !server.text.trim()
    readonly property bool looksUp: root.needsServer && root.canCheck && !root.tls
    readonly property var innerChoices: root.innerOf(root.methodName)
    readonly property string innerName: root.innerChoices.includes(root.inner[root.methodName]) ? root.inner[root.methodName] : root.innerChoices[0] ?? ""
    readonly property string outerDefault: root.outerOf(root.methodName, identity.text)
    readonly property bool filled: !!identity.text && (root.tls ? !!certificate.text.trim() : !!password.text)

    readonly property var school: server.text.trim() ? root.schoolOf(server.text, "") : root.schoolOf("", identity.text)
    readonly property var trustKeys: root.school ? ["school", "system", "file"] : ["system", "file"]
    readonly property var trustNames: root.school ? [root.school.school, "system", "a file"] : ["system", "a file"]
    readonly property string trustKey: root.trustKeys.includes(root.trust) ? root.trust : root.school ? "school" : "system"

    property var found: []
    readonly property var authorities: CertificateFiles.fitting(root.found, "authority", 4)
    readonly property var clients: CertificateFiles.fitting(root.found, "client", 4)
    readonly property var keys: CertificateFiles.fitting(root.found, "key", 4)
    property string local: ""
    property string localField: ""
    property string autoServer: ""

    function pickFile(entry: Item, path: string): void {
        entry.text = path;
        if (root.localField === entry.field) {
            root.local = "";
            root.localField = "";
        }
    }

    readonly property bool wantsFiles: root.visible && !root.refusal && (root.tls || root.trustKey === "file")

    onWantsFilesChanged: if (root.wantsFiles)
        files.running = true

    function browse(entry: Item, title: string, pattern: string): void {
        if (chooser.running)
            return;
        chooser.into = entry;
        chooser.title = title;
        chooser.pattern = pattern;
        Prompts.leave(root);
        chooser.running = true;
    }

    function realmServer(): void {
        const found = root.schoolOf("", identity.text);
        const want = found ? found.suffix : "";
        const now = server.text.trim();
        if (now && now !== root.autoServer)
            return;
        server.text = want;
        root.autoServer = want;
    }

    function summary(room: real): string {
        if (root.needsServer)
            return "no server name";
        const inner = root.innerChoices.length && root.innerName !== root.innerChoices[0] ? `/${root.innerLabel(root.innerName)}` : "";
        const parts = [root.methodName.toUpperCase() + inner, root.trustNames[root.trustKeys.indexOf(root.trustKey)], server.text.trim()];
        for (let i = 0; i < parts.length; i++) {
            const text = parts.slice(i).join(" · ");
            if (i === parts.length - 1 || summaryInk.advanceWidth(text) <= room)
                return text;
        }
        return "";
    }

    implicitHeight: visible ? stack.implicitHeight : 0

    function form(): var {
        return {
            method: root.methodName,
            identity: identity.text,
            domain: server.text,
            trust: root.trustKey,
            authority: root.trustKey === "file" ? authority.text.trim() : "",
            certificate: root.tls ? certificate.text.trim() : "",
            key: root.tls ? (key.text.trim() || certificate.text.trim()) : "",
            locked: root.tls && !!keyPassword.text,
            inner: root.innerName,
            outer: root.tls ? "" : outer.text.trim()
        };
    }

    function fault(entry: Item, field: string, text: string): void {
        root.local = text;
        root.localField = field;
        root.more = true;
        entry.input.forceActiveFocus();
    }

    function submit(): void {
        if (root.refusal || root.busy)
            return;
        root.local = "";
        root.localField = "";
        if (root.trustKey === "file" && !authority.text.trim())
            return root.fault(authority, "authority", "Pick your school's root certificate file, or set trust back.");
        if (!root.tls && /\s/.test(outer.text.trim()))
            return root.fault(outer, "outer", "An anonymous identity has no spaces, such as anonymous@school.edu.");
        if (root.looksUp)
            return root.check(root.form());
        if (!root.needsServer && !root.readServer(server.text))
            return root.fault(server, "server", "That server name needs a dot, such as school.edu.");
        if (!root.filled)
            return;
        if (root.needsServer)
            return root.fault(server, "server", "Fill in the server name your school's Wi-Fi guide gives.");
        root.accepted(root.form(), root.tls ? keyPassword.text : password.text);
    }

    onFillChanged: if (root.fill)
        server.text = root.fill

    readonly property bool surfaceActive: root.Window.active
    onSurfaceActiveChanged: if (root.surfaceActive && root.visible && !root.refusal)
        identity.input.forceActiveFocus()

    function claim(): void {
        identity.text = "";
        password.text = "";
        keyPassword.text = "";
        outer.text = "";
        password.shown = false;
        server.text = root.fill || root.domain;
        root.autoServer = "";
        root.local = "";
        root.localField = "";
        if (root.visible && !root.refusal) {
            Prompts.request(root);
            identity.input.forceActiveFocus();
            if (root.wantsFiles)
                files.running = true;
        } else {
            chooser.into = null;
            chooser.running = false;
            Prompts.release(root);
        }
    }

    onVisibleChanged: root.claim()
    Component.onCompleted: root.claim()
    Component.onDestruction: Prompts.release(root)

    Process {
        id: files

        command: ["sh", Quickshell.shellPath("scripts/certificate-files.sh")]

        stdout: StdioCollector {
            onStreamFinished: root.found = CertificateFiles.read(text)
        }
    }

    Process {
        id: chooser

        property Item into: null
        property string title: ""
        property string pattern: "*"

        command: ["python3", Quickshell.shellPath("scripts/pick-file.py"), chooser.title, chooser.pattern, "~/Downloads"]

        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                if (path && chooser.into)
                    root.pickFile(chooser.into, path);
            }
        }

        onRunningChanged: if (!chooser.running)
            Prompts.back(root)

        onExited: code => {
            if (code === 2 && chooser.into)
                root.fault(chooser.into, chooser.into.field, "No file browser here. Install xdg-desktop-portal-gtk or zenity, or type the path.");
        }
    }

    component Entry: Item {
        id: entry

        property alias input: box
        property alias text: box.text
        property string label: ""
        property string hint: ""
        property bool secret: false
        property bool shown: false
        property string field: ""

        property Item next: null

        implicitHeight: visible ? heading.height + field.height : 0

        StyledText {
            id: heading

            anchors.left: parent.left
            anchors.leftMargin: Appearance.padding.normal
            height: entry.label ? implicitHeight + Appearance.padding.small : 0
            visible: !!entry.label
            verticalAlignment: Text.AlignBottom
            text: entry.label
            color: Appearance.colour.textDim
            font.pixelSize: Appearance.font.size.small
        }

        Item {
            id: field

            anchors.top: heading.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: box.implicitHeight + Appearance.padding.normal * 2

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
                anchors.rightMargin: entry.secret ? eye.width + Appearance.padding.normal * 2 : Appearance.padding.normal

                verticalAlignment: TextInput.AlignVCenter
                echoMode: entry.secret && !entry.shown ? TextInput.Password : TextInput.Normal
                clip: true

                font.family: Appearance.font.family
                font.pixelSize: Appearance.font.size.small
                renderType: Text.NativeRendering
                color: Appearance.colour.text
                selectionColor: Appearance.colour.accent
                selectedTextColor: Appearance.colour.accentText

                KeyNavigation.tab: entry.next

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

            Icon {
                id: eye

                anchors.right: parent.right
                anchors.rightMargin: Appearance.padding.normal
                anchors.verticalCenter: parent.verticalCenter

                visible: entry.secret
                name: entry.shown ? "visibility_off" : "visibility"
                color: Appearance.colour.textDim

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -Appearance.padding.small
                    cursorShape: Qt.PointingHandCursor
                    onClicked: entry.shown = !entry.shown
                }

                HoverTip {
                    text: entry.shown ? "hide" : "show"
                }
            }
        }
    }

    Column {
        id: stack

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        FormLine {
            visible: !!root.refusal
            text: root.refusal
            color: Appearance.colour.textDim
        }

        Item {
            width: parent.width
            visible: !!root.refusal
            implicitHeight: visible ? close.implicitHeight + Appearance.padding.small * 2 : 0

            Button {
                id: close

                anchors.left: parent.left
                anchors.leftMargin: Appearance.padding.normal
                anchors.verticalCenter: parent.verticalCenter

                size: 0
                text: "Close"
                onClicked: root.cancelled()
            }
        }

        Item {
            width: parent.width
            implicitHeight: fields.implicitHeight
            visible: !root.refusal

            Column {
                id: fields

                width: parent.width
                spacing: 0

                FormLine {
                    text: root.tls ? `Sign in to ${root.placeholder} with a certificate from your school or work.` : `Sign in to ${root.placeholder} with your ${root.school ? root.school.school : "school or work"} account.`
                    color: Appearance.colour.textDim
                }

                FormLine {
                    visible: !!root.note
                    text: root.note
                    color: root.noteIsTrouble || root.noteWarns ? Appearance.colour.warning : Appearance.colour.textDim
                }

                Entry {
                    id: identity

                    width: parent.width
                    label: root.tls ? "Name on your certificate" : root.school ? `${root.school.school} username or email` : "Username or email"
                    hint: root.tls ? "" : root.school ? `username@${root.school.suffix}` : "name@school.edu"
                    next: root.tls ? certificate.input : password.input
                    onTextChanged: root.realmServer()
                }

                Entry {
                    id: certificate

                    width: parent.width
                    visible: root.tls
                    label: "Certificate file"
                    hint: "pick one below or type its path"
                    field: "certificate"
                    next: key.input
                }

                FileChips {
                    visible: root.tls
                    files: root.clients
                    lead: "Certificates found:"
                    choosing: chooser.running
                    browsing: chooser.running && chooser.into === certificate
                    onPicked: path => root.pickFile(certificate, path)
                    onBrowse: root.browse(certificate, "Pick your certificate", "*.p12 *.pfx *.pem *.crt *.cer")
                }

                FormLine {
                    visible: root.localField === "certificate"
                    text: root.local
                    color: Appearance.colour.warning
                }

                Entry {
                    id: key

                    width: parent.width
                    visible: root.tls
                    label: "Key file, if separate"
                    field: "key"
                    next: identity.input
                }

                FileChips {
                    visible: root.tls
                    files: root.keys
                    lead: "Keys found:"
                    choosing: chooser.running
                    browsing: chooser.running && chooser.into === key
                    onPicked: path => root.pickFile(key, path)
                    onBrowse: root.browse(key, "Pick your key file", "*.key *.pem")
                }

                FormLine {
                    visible: root.localField === "key"
                    text: root.local
                    color: Appearance.colour.warning
                }

                Entry {
                    id: password

                    width: parent.width
                    visible: !root.tls
                    label: "Password"
                    secret: true
                    next: identity.input
                }

                Item {
                    width: parent.width
                    implicitHeight: act.implicitHeight + Appearance.padding.small * 2

                    Button {
                        id: act

                        anchors.left: parent.left
                        anchors.leftMargin: Appearance.padding.normal
                        anchors.right: parent.right
                        anchors.rightMargin: Appearance.padding.normal
                        anchors.verticalCenter: parent.verticalCenter

                        style: "accent"
                        interactive: !root.busy && (root.looksUp || root.filled)
                        text: root.busy ? (root.checking ? "Looking…" : "Connecting…") : root.looksUp ? (root.suggestion ? "Look up again" : "Look up the server") : "Connect"
                        onClicked: root.submit()
                    }
                }

                FormLine {
                    visible: root.looksUp && !root.busy
                    text: "Looking up sends nothing secret, but your Wi-Fi drops for a moment."
                }

                Item {
                    width: parent.width
                    visible: !!root.suggestion && server.text.trim() !== root.suggestion
                    implicitHeight: visible ? use.implicitHeight + Appearance.padding.small * 2 : 0

                    Button {
                        id: use

                        anchors.left: parent.left
                        anchors.leftMargin: Appearance.padding.normal
                        anchors.verticalCenter: parent.verticalCenter

                        size: 0
                        style: "bare"
                        text: `Use ${root.suggestion} anyway`
                        onClicked: server.text = root.suggestion
                    }
                }

                Item {
                    width: parent.width
                    implicitHeight: Math.max(moreLabel.implicitHeight, opener.implicitHeight) + Appearance.padding.small * 2

                    FontMetrics {
                        id: summaryInk

                        font: moreLabel.font
                    }

                    StyledText {
                        id: moreHead

                        anchors.left: parent.left
                        anchors.leftMargin: Appearance.padding.normal
                        anchors.verticalCenter: parent.verticalCenter

                        text: "More"
                        color: Appearance.colour.textDim
                        font.pixelSize: Appearance.font.size.small
                    }

                    StyledText {
                        id: moreLabel

                        anchors.left: moreHead.right
                        anchors.leftMargin: Appearance.padding.large
                        anchors.right: opener.left
                        anchors.rightMargin: Appearance.padding.normal
                        anchors.verticalCenter: parent.verticalCenter

                        visible: !root.more
                        text: root.summary(moreLabel.width)
                        color: root.needsServer ? Appearance.colour.warning : Appearance.colour.textDim
                        font.pixelSize: Appearance.font.size.small
                    }

                    Expander {
                        id: opener

                        anchors.right: parent.right
                        anchors.rightMargin: Appearance.padding.normal
                        anchors.verticalCenter: parent.verticalCenter

                        open: root.more
                        tip: root.more ? "less" : "more"
                        onToggled: root.more = !root.more
                    }

                    MouseArea {
                        anchors.left: parent.left
                        anchors.right: opener.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.more = !root.more
                    }
                }

                Column {
                    width: parent.width
                    visible: root.more
                    spacing: 0

                    Entry {
                        id: server

                        width: parent.width
                        label: "Server name"
                        hint: "such as school.edu"
                        next: root.trustKey === "file" ? authority.input : identity.input
                    }

                    FormLine {
                        visible: root.localField === "server"
                        text: root.local
                        color: Appearance.colour.warning
                    }

                    FormLine {
                        text: root.tls ? "Your certificate only goes to a server with this name." : "Your password only goes to a server with this name."
                    }

                    FormChoice {
                        width: parent.width
                        label: "trust"
                        options: root.trustNames
                        current: root.trustKeys.indexOf(root.trustKey)
                        onPicked: i => {
                            root.trust = root.trustKeys[i];
                            if (root.trust === "file")
                                authority.input.forceActiveFocus();
                        }
                    }

                    Entry {
                        id: authority

                        width: parent.width
                        visible: root.trustKey === "file"
                        label: "Your school's root certificate file"
                        hint: "pick one below or type its path"
                        field: "authority"
                        next: identity.input
                    }

                    FileChips {
                        visible: root.trustKey === "file"
                        files: root.authorities
                        lead: "Root certificates found:"
                        choosing: chooser.running
                    browsing: chooser.running && chooser.into === authority
                        onPicked: path => root.pickFile(authority, path)
                        onBrowse: root.browse(authority, "Pick your school's root certificate", "*.pem *.crt *.cer *.der")
                    }

                    FormLine {
                        visible: root.localField === "authority"
                        text: root.local
                        color: Appearance.colour.warning
                    }

                    Entry {
                        id: keyPassword

                        width: parent.width
                        visible: root.tls
                        label: "Key password, if it has one"
                        secret: true
                        next: identity.input
                    }

                    FormChoice {
                        width: parent.width
                        visible: root.methods.length > 1
                        label: "sign-in method"
                        options: root.methods.map(m => m.toUpperCase())
                        current: root.method
                        onPicked: i => root.method = i
                    }

                    FormChoice {
                        width: parent.width
                        visible: root.innerChoices.length > 1
                        label: "phase 2"
                        options: root.innerChoices.map(i => root.innerLabel(i))
                        current: root.innerChoices.indexOf(root.innerName)
                        onPicked: i => root.inner = Object.assign({}, root.inner, {
                                [root.methodName]: root.innerChoices[i]
                            })
                    }

                    Entry {
                        id: outer

                        width: parent.width
                        visible: !root.tls
                        label: "Anonymous identity"
                        hint: root.outerDefault || "same as your username"
                        field: "outer"
                        next: identity.input
                    }

                    FormLine {
                        visible: !root.tls
                        text: "Sent before the tunnel opens, so anyone nearby can read it."
                    }

                    FormLine {
                        visible: root.localField === "outer"
                        text: root.local
                        color: Appearance.colour.warning
                    }
                }
            }
        }
    }
}
