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
    readonly property bool filled: !!identity.text && (root.tls ? !!root.pathOf(certificate) : !!password.text)
    readonly property bool authorityMissing: root.trustKey === "file" && !root.pathOf(authority)
    readonly property bool keyMissing: root.tls && !root.pathOf(key) && CertificateFiles.needsKey(root.found, root.pathOf(certificate))
    readonly property bool started: !!identity.text || !!password.text || !!root.pathOf(certificate)
    readonly property bool certificateMissing: root.tls && !root.pathOf(certificate)
    readonly property bool passwordMissing: !root.tls && !password.text && !root.looksUp
    readonly property bool serverMissing: root.needsServer && !root.looksUp
    readonly property bool outerSpaced: !root.tls && /\s/.test(outer.text.trim())
    readonly property real now: Date.now()
    readonly property string authorityProblem: root.trustKey === "file" ? CertificateFiles.problem(root.found, root.pathOf(authority), "authority", root.now) : ""
    readonly property string certificateProblem: root.tls ? CertificateFiles.problem(root.found, root.pathOf(certificate), "client", root.now) : ""
    readonly property string keyProblem: root.tls && !root.keyCarried && !!root.pathOf(key) ? CertificateFiles.problem(root.found, root.pathOf(key), "key", root.now) : ""
    readonly property string fileProblem: root.authorityProblem || root.certificateProblem || root.keyProblem
    readonly property bool blocked: root.authorityMissing || root.outerSpaced || !!root.fileProblem || (!root.looksUp && (!identity.text || root.certificateMissing || root.keyMissing || root.passwordMissing || root.serverMissing))
    readonly property string blockReason: {
        if (!root.blocked)
            return "";
        if (root.authorityMissing)
            return "pick your school's root certificate.";
        if (root.fileProblem)
            return root.fileProblem;
        if (root.looksUp)
            return root.outerSpaced ? "the anonymous identity has a space in it." : "";
        if (!identity.text)
            return root.tls ? "fill in the name on your certificate." : "fill in your username.";
        if (root.certificateMissing)
            return "pick your certificate file.";
        if (root.keyMissing)
            return "pick the certificate's key file.";
        if (root.passwordMissing)
            return "fill in your password.";
        if (root.serverMissing)
            return "enter the server name.";
        return root.outerSpaced ? "the anonymous identity has a space in it." : "";
    }
    readonly property bool moreNeeded: root.started && (root.authorityMissing || root.outerSpaced)
    property bool serverUp: false

    onNeedsServerChanged: if (root.needsServer && !server.input.activeFocus)
        root.serverUp = true

    Connections {
        target: server.input

        function onActiveFocusChanged(): void {
            if (!server.input.activeFocus && root.needsServer)
                root.serverUp = true;
        }
    }

    onMoreNeededChanged: if (root.moreNeeded)
        root.more = true

    readonly property bool serverChecked: !!root.readServer(server.text) && !root.authorityMissing
    readonly property bool plainInside: root.methodName === "ttls" && root.innerName === "pap"

    readonly property var school: server.text.trim() ? root.schoolOf(server.text, "") : root.schoolOf("", identity.text)
    readonly property var trustKeys: root.school ? ["school", "system", "file"] : ["system", "file"]
    readonly property var trustNames: root.school ? [root.school.school, "system", "a file"] : ["system", "a file"]
    readonly property string trustKey: root.trustKeys.includes(root.trust) ? root.trust : root.school ? "school" : "system"

    property var found: []
    readonly property var authorities: CertificateFiles.roots(root.found, root.readServer(server.text), Date.now(), 4)
    readonly property var clients: CertificateFiles.fitting(root.found, "client", 4).map(path => ({
                path: path
            }))
    readonly property var keys: CertificateFiles.fitting(root.found, "key", 4).map(path => ({
                path: path
            }))
    readonly property bool keyCarried: root.tls && CertificateFiles.carriesKey(root.found, root.pathOf(certificate))
    property Item browsingInto: null
    property string local: ""
    property string localField: ""
    property string autoServer: ""

    function pathOf(entry: Item): string {
        return CertificateFiles.fullPath(entry.text, System.home);
    }

    function pickFile(entry: Item, path: string): void {
        entry.text = CertificateFiles.shortPath(path, System.home);
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
        root.browsingInto = entry;
        chooser.open(title, pattern);
    }

    function hintFor(listed: var): string {
        return listed.length || chooser.available ? "pick one below or type its path" : "type its full path";
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
        const inner = root.innerChoices.length ? `/${root.innerLabel(root.innerName)}` : "";
        const method = root.methodName.toUpperCase() + inner;
        const name = server.text.trim();
        const full = [method, root.trustNames[root.trustKeys.indexOf(root.trustKey)], name].filter(p => p).join(" · ");
        if (summaryInk.advanceWidth(full) <= room)
            return full;
        const brief = [method, name].filter(p => p).join(" · ");
        return summaryInk.advanceWidth(brief) <= room ? brief : `${method}\n${name}`;
    }

    implicitHeight: visible ? stack.implicitHeight : 0

    function form(): var {
        return {
            method: root.methodName,
            identity: identity.text,
            domain: server.text,
            trust: root.trustKey,
            authority: root.trustKey === "file" ? root.pathOf(authority) : "",
            certificate: root.tls ? root.pathOf(certificate) : "",
            key: !root.tls ? "" : root.keyCarried ? root.pathOf(certificate) : (root.pathOf(key) || root.pathOf(certificate)),
            locked: root.tls && !!keyPassword.text,
            inner: root.innerName,
            outer: root.tls ? "" : outer.text.trim()
        };
    }

    function fault(entry: Item, field: string, text: string): void {
        root.local = text;
        root.localField = field;
        if (entry !== server || !root.serverUp)
            root.more = true;
        entry.input.forceActiveFocus();
    }

    function submit(): void {
        if (root.refusal || root.busy)
            return;
        root.local = "";
        root.localField = "";
        if (root.trustKey === "file" && !root.pathOf(authority))
            return root.fault(authority, "authority", "Pick your school's root certificate file, or set trust back.");
        if (root.looksUp)
            return root.check(root.form());
        if (!root.needsServer && !root.readServer(server.text))
            return root.fault(server, "server", "That server name needs a dot, such as school.edu.");
        if (!root.filled || root.blocked)
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
        root.serverUp = root.needsServer;
        if (root.visible && !root.refusal) {
            Prompts.request(root);
            identity.input.forceActiveFocus();
            if (root.wantsFiles)
                files.running = true;
        } else {
            root.browsingInto = null;
            chooser.stop();
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

    FileChooser {
        id: chooser

        holder: root
        onPicked: path => {
            if (root.browsingInto)
                root.pickFile(root.browsingInto, path);
        }
        onMissing: if (root.browsingInto)
            root.fault(root.browsingInto, root.browsingInto.field, "No file chooser here. Type the file's full path.")
    }

    component Entry: Item {
        id: entry

        property alias input: box
        property alias text: box.text
        property string label: ""
        property string hint: ""
        property bool secret: false
        property bool shown: false
        property bool warn: false
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
                color: entry.warn ? Appearance.colour.warningFill : Appearance.colour.fillStrong
                stroke: entry.warn ? Appearance.colour.warning : "transparent"
                strokeWidth: entry.warn ? Appearance.stroke.ring : 0
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

                FormLine {
                    visible: root.started && !identity.text
                    text: root.tls ? "Fill in the name on your certificate." : "Fill in your username."
                    color: Appearance.colour.textDim
                }

                Entry {
                    id: certificate

                    width: parent.width
                    visible: root.tls
                    label: "Certificate file"
                    hint: root.hintFor(root.clients)
                    field: "certificate"
                    next: key.input
                }

                FormWarning {
                    visible: !!root.certificateProblem
                    text: root.certificateProblem
                }

                FormLine {
                    visible: root.started && root.certificateMissing
                    text: "Pick your certificate file."
                    color: Appearance.colour.textDim
                }

                FileChips {
                    visible: root.tls
                    files: root.clients
                    lead: "Certificates found:"
                    picked: root.pathOf(certificate)
                    canBrowse: chooser.available
                    choosing: chooser.running
                    browsing: chooser.running && root.browsingInto === certificate
                    onPick: path => root.pickFile(certificate, path)
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
                    visible: root.tls && !root.keyCarried
                    label: "Key file, if separate"
                    hint: root.hintFor(root.keys)
                    field: "key"
                    next: identity.input
                }

                FormWarning {
                    visible: !!root.keyProblem
                    text: root.keyProblem
                }

                FormLine {
                    visible: root.keyMissing
                    text: "This certificate holds no key. Pick its key file."
                    color: Appearance.colour.textDim
                }

                FileChips {
                    visible: root.tls && !root.keyCarried
                    files: root.keys
                    lead: "Keys found:"
                    picked: root.pathOf(key)
                    canBrowse: chooser.available
                    choosing: chooser.running
                    browsing: chooser.running && root.browsingInto === key
                    onPick: path => root.pickFile(key, path)
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

                FormLine {
                    visible: root.started && root.passwordMissing
                    text: "Fill in your password."
                    color: Appearance.colour.textDim
                }

                Item {
                    id: upSlot

                    width: parent.width
                    implicitHeight: root.serverUp ? serverBlock.implicitHeight : 0
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
                        interactive: !root.busy && !root.blocked && (root.looksUp || root.filled)
                        text: root.busy ? (root.checking ? "Looking…" : "Connecting…") : root.looksUp ? (root.suggestion ? "Look up again" : "Look up the server") : "Connect"
                        onClicked: root.submit()
                    }
                }

                FormLine {
                    visible: !root.busy && !!root.blockReason && (root.started || !!root.fileProblem)
                    text: `Connect is off: ${root.blockReason}`
                    color: Appearance.colour.textDim
                }

                FormLine {
                    visible: root.looksUp && !root.busy && !root.blocked
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
                        wrapMode: Text.Wrap
                        color: Appearance.colour.textDim
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

                    Item {
                        id: moreSlot

                        width: parent.width
                        implicitHeight: root.serverUp ? 0 : serverBlock.implicitHeight

                        Column {
                            id: serverBlock

                            parent: root.serverUp ? upSlot : moreSlot
                            width: parent.width
                            spacing: 0

                            Entry {
                                id: server

                                width: parent.width
                                warn: root.needsServer
                                label: "Server name"
                                hint: "such as school.edu"
                                next: root.trustKey === "file" ? authority.input : identity.input
                            }

                            FormWarning {
                                visible: root.needsServer && root.localField !== "server"
                                text: root.looksUp ? "Enter the server name to connect, or look it up. It stops a look-alike network posing as this one." : "Enter the server name to connect. It stops a look-alike network posing as this one; your school's Wi-Fi guide gives it."
                            }

                            FormLine {
                                visible: root.localField === "server"
                                text: root.local
                                color: Appearance.colour.warning
                            }

                            FormLine {
                                visible: root.serverChecked
                                text: root.tls ? "Your certificate only goes to a server with this name." : "Your password only goes to a server with this name."
                            }
                        }
                    }

                    FormLine {
                        visible: root.plainInside
                        text: "With TTLS and PAP, your password is sent as typed inside the tunnel."
                    }

                    FormChoice {
                        width: parent.width
                        label: "Trust"
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
                        hint: root.hintFor(root.authorities)
                        field: "authority"
                        next: identity.input
                    }

                    FormWarning {
                        visible: !!root.authorityProblem
                        text: root.authorityProblem
                    }

                    FormLine {
                        visible: root.authorityMissing && root.localField !== "authority"
                        text: "Pick your school's root certificate below, or set trust back to system."
                        color: Appearance.colour.textDim
                    }

                    FileChips {
                        visible: root.trustKey === "file"
                        files: root.authorities
                        lead: "Root certificates found:"
                        picked: root.pathOf(authority)
                        canBrowse: chooser.available
                        choosing: chooser.running
                        browsing: chooser.running && root.browsingInto === authority
                        onPick: path => root.pickFile(authority, path)
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
                        label: "Sign-in method"
                        options: root.methods.map(m => m.toUpperCase())
                        current: root.method
                        onPicked: i => root.method = i
                    }

                    FormChoice {
                        width: parent.width
                        visible: root.innerChoices.length > 1
                        label: "Phase 2"
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
                        visible: root.outerSpaced
                        text: `Take out the space in the middle, as in ${root.outerDefault.includes("@") ? root.outerDefault : "anonymous@school.edu"}.`
                        color: Appearance.colour.warning
                    }

                    FormLine {
                        visible: !root.tls
                        text: "Sent before the tunnel opens, so anyone nearby can read it."
                    }
                }
            }
        }
    }
}
