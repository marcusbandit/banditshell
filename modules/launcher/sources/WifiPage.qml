pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking as Networking
import qs.config
import qs.components
import qs.services
import qs.modules.controls
import "../search.js" as Search
import "../../../services/wifilist.js" as WifiList

Item {
    id: root

    property string typed: ""
    property string query: ""
    property string selection: ""
    property var view: null

    signal leave(var what)
    signal launch(var what)
    signal back
    signal retitle(string text)
    signal asks(Item item, var actions, real x, real y)
    signal commit

    required property var source
    property var order: null

    property string mode: ""
    property string name: ""
    property var card: null

    property string needs: ""
    property bool asking: false
    property string warning: ""
    property bool started: false
    property string failure: ""
    property bool looking: false
    property bool portalSeen: false
    property bool fresh: false
    property bool settled: false
    property real since: Date.now()
    property real now: Date.now()

    property string scanNote: ""
    property var copied: null
    property int picked: 0
    property bool colourful: true
    property string flash: ""

    readonly property var network: root.name ? Network.find(root.name) : null
    readonly property bool joined: Network.connected && Network.activeName === root.name
    readonly property bool checks: Network.canCheck && Network.checking
    readonly property string connectivity: {
        switch (Network.connectivity) {
        case Networking.NetworkConnectivity.Full:
            return "full";
        case Networking.NetworkConnectivity.Portal:
            return "portal";
        case Networking.NetworkConnectivity.Limited:
            return "limited";
        case Networking.NetworkConnectivity.None:
            return "none";
        }
        return "unknown";
    }

    readonly property var steps: root.mode !== "join" ? [] : WifiList.joinSteps({
        asks: root.needs,
        asking: root.asking,
        warning: root.warning,
        started: root.started,
        looking: root.looking,
        stage: root.fresh ? Network.stage : "",
        connected: root.joined,
        checks: root.checks,
        connectivity: root.connectivity,
        settled: root.settled,
        portalSeen: root.portalSeen,
        failure: root.failure
    })
    readonly property string phase: root.mode === "join" ? WifiList.joinPhase(root.steps) : ""
    readonly property string activeStep: root.steps.find(step => step.state === "active")?.key ?? ""

    onActiveStepChanged: root.since = Date.now()

    readonly property var secretAsk: root.mode === "join" && root.asking && root.needs === "password" ? {
        placeholder: `Password for ${root.name}`,
        alarm: !!root.warning
    } : null

    property var identityForm: null

    readonly property bool holdsFocus: !!root.identityForm

    function takeFocus(): void {
        root.identityForm?.focusFirst();
    }

    readonly property string heading: {
        switch (root.phase) {
        case "asking":
            return root.needs === "identity" ? `Sign in to ${root.name}` : `Join ${root.name}`;
        case "joining":
            return `Joining ${root.name}`;
        case "portal":
            return `Sign in to use ${root.name}`;
        case "failed":
            return `Could not join ${root.name}`;
        case "online":
        case "offline":
            return `Connected to ${root.name}`;
        }
        return `Join ${root.name}`;
    }

    readonly property bool shareable: Network.connected && !Network.enterprise(Network.active)

    readonly property var joinFacts: {
        const n = root.network;
        const facts = [];
        if (n) {
            facts.push(["Security", Network.securityLabel(n).toUpperCase()]);
            facts.push(["Signal", `${Network.percent(n)}%`]);
        } else if (root.card) {
            facts.push(["Security", WifiList.qrSecurity(root.card.security) === "open" ? "OPEN" : root.card.security]);
        }
        if (root.joined && Network.ipAddress)
            facts.push(["Address", Network.ipAddress]);
        return facts;
    }

    readonly property var shareFacts: {
        if (!Network.connected)
            return [];
        const open = !Network.secured(Network.active);
        const trouble = Network.cardTrouble;
        const password = open ? ["Password", "None", "dim"] : Network.secret ? ["Password", Network.secret] : ["Password", trouble || "Reading", trouble ? "alarm" : "dim"];
        return [password, ["Security", Network.securityLabel(Network.active).toUpperCase()]];
    }

    readonly property var options: {
        const list = [];
        if (root.copied)
            list.push({
                key: "copied",
                icon: "content_paste",
                label: `Join ${root.copied.ssid} from the copied code`,
                verb: "Join"
            });
        list.push({
            key: "screen",
            icon: "screenshot_monitor",
            label: "Scan the screen",
            verb: "Scan the screen"
        });
        return list;
    }

    readonly property string primaryLabel: {
        if (root.mode === "share")
            return Network.secret ? "Copy password" : "";
        if (root.mode === "scan")
            return root.options[root.picked]?.verb ?? "";
        switch (root.phase) {
        case "asking":
            return root.needs === "password" ? "Join" : "";
        case "portal":
            return "Open sign-in page";
        case "failed":
            return "Try again";
        case "idle":
            return "Join";
        }
        return "Done";
    }

    readonly property string footerIcon: root.mode === "share" ? "qr_code_2" : root.mode === "scan" ? "qr_code_scanner" : root.phase === "failed" ? "signal_wifi_bad" : root.joined ? "wifi" : root.needs ? "wifi_lock" : "wifi_find"

    readonly property string footerTitle: root.mode === "share" ? Network.activeName || "Wi-Fi" : root.mode === "scan" ? "Join with a QR code" : root.name

    implicitHeight: Math.max(Appearance.sizes.rowHeight * 5, body.implicitHeight + footer.implicitHeight + Appearance.padding.normal)

    Component.onCompleted: root.begin(root.order ?? {})

    Component.onDestruction: {
        Network.setViewing(root, false);
        if (root.mode === "share")
            Network.share(false);
        if (WifiJoin.onPage === root.name)
            WifiJoin.onPage = "";
    }

    function begin(order: var): void {
        Network.setViewing(root, true);
        root.show(order.mode ?? "join", order);
    }

    function show(mode: string, order: var): void {
        if (root.mode === "share" || mode === "share")
            Network.share(mode === "share");
        root.mode = mode;
        root.scanNote = order.note ?? "";
        root.flash = "";
        if (mode === "share") {
            root.retitle(Network.activeName ? `Share ${Network.activeName}` : "Share Wi-Fi");
            return;
        }
        if (mode === "scan") {
            root.picked = 0;
            root.retitle("Join with a QR code");
            clipboardReader.running = true;
            return;
        }
        root.card = order.card ?? null;
        root.name = root.card?.ssid ?? order.name ?? "";
        root.retitle(root.name);
        WifiJoin.onPage = root.name;
        root.prepare();
    }

    function reset(): void {
        root.needs = "";
        root.asking = false;
        root.warning = "";
        root.started = false;
        root.failure = "";
        root.looking = false;
        root.portalSeen = false;
        root.fresh = false;
        root.settled = false;
    }

    function prepare(): void {
        root.reset();
        if (root.joined) {
            root.started = true;
            root.settled = true;
            return;
        }
        if (root.card) {
            root.joinCard();
            return;
        }
        const n = root.network;
        if (!n) {
            root.started = true;
            root.failure = `${root.name} is not in range`;
            return;
        }
        if (Network.enterprise(n) && !n.known) {
            root.needs = "identity";
            root.asking = true;
            return;
        }
        if (Network.secured(n) && !n.known) {
            root.needs = "password";
            root.asking = true;
            return;
        }
        root.connect("");
    }

    function connect(secret: string): void {
        const n = root.network;
        root.failure = "";
        root.asking = false;
        root.started = true;
        root.fresh = false;
        root.settled = false;
        if (!n) {
            root.failure = `${root.name} is not in range`;
            return;
        }
        Network.join(n, secret);
    }

    function takeSecret(secret: string): void {
        if (root.asking && secret)
            root.connect(secret);
    }

    function joinCard(): void {
        const c = root.card;
        const n = root.network;
        root.started = true;
        if (n) {
            root.looking = false;
            if (Network.enterprise(n)) {
                root.failure = "A code cannot carry a school sign-in";
                return;
            }
            root.connect(Network.secured(n) ? c.password : "");
            return;
        }
        if (c.hidden) {
            const security = WifiList.qrSecurity(c.security);
            if (!security) {
                root.failure = "That code uses a kind of security this cannot join";
                return;
            }
            const trouble = Network.joinHidden(c.ssid, security, c.password);
            if (trouble)
                root.failure = trouble;
            return;
        }
        root.looking = true;
        hunt.restart();
    }

    onNetworkChanged: if (root.looking && root.network)
        root.joinCard()

    Timer {
        id: hunt

        interval: 15000
        onTriggered: if (root.looking) {
            root.looking = false;
            root.failure = `${root.name} is not in range`;
        }
    }

    onJoinedChanged: {
        if (!root.joined || root.mode !== "join")
            return;
        root.started = true;
        root.asking = false;
        root.failure = "";
        Network.checkNow();
        settle.restart();
    }

    onConnectivityChanged: if (root.connectivity === "portal" && root.joined)
        root.portalSeen = true

    Timer {
        id: settle

        interval: 8000
        onTriggered: root.settled = true
    }

    Timer {
        interval: 3000
        repeat: true
        running: root.mode === "join" && root.joined && root.checks && root.connectivity !== "full"
        onTriggered: Network.checkNow()
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.activeStep !== ""
        triggeredOnStart: true
        onTriggered: root.now = Date.now()
    }

    Timer {
        id: unflash

        interval: 2000
        onTriggered: root.flash = ""
    }

    Connections {
        target: Network

        function onStageChanged(): void {
            if (root.started)
                root.fresh = true;
        }

        function onJoinFailed(name: string, kind: string): void {
            if (name !== root.name || root.mode !== "join")
                return;
            const n = root.network;
            if (kind === "password" && Network.secured(n) && !Network.enterprise(n)) {
                root.needs = "password";
                root.asking = true;
                root.started = false;
                root.warning = WifiJoin.wrongPassword;
                return;
            }
            root.failure = WifiJoin.reason(kind);
        }

        function onHiddenDone(name: string, ok: bool): void {
            if (name === root.name && !ok)
                root.failure = Network.hiddenTrouble || "Could not join";
        }

        function onEnrollingNameChanged(): void {
            if (root.needs !== "identity" || Network.enrollingName || Network.enrollFailedName !== root.name)
                return;
            root.asking = true;
            root.started = false;
            root.warning = Network.enrollDetail || `Could not sign in: ${Network.enrollTrouble}`;
        }
    }

    function primary(): void {
        if (root.mode === "share") {
            root.copyPassword();
            return;
        }
        if (root.mode === "scan") {
            root.pick(root.options[root.picked]);
            return;
        }
        switch (root.phase) {
        case "asking":
            if (root.needs === "password")
                root.commit();
            return;
        case "portal":
            root.launch(() => Network.openPortal());
            return;
        case "failed":
        case "idle":
            root.prepare();
            return;
        }
        root.leave(() => {});
    }

    function copyPassword(): void {
        if (!Network.secret)
            return;
        System.copyText(Network.secret);
        root.flash = "Password copied";
        unflash.restart();
    }

    function copyCode(): void {
        if (!Network.card)
            return;
        System.copyText(Network.card);
        root.flash = "Code copied";
        unflash.restart();
    }

    function pick(option: var): void {
        if (option?.key === "copied")
            root.takeCard(root.copied);
        else if (option?.key === "screen")
            root.source.scanScreen();
    }

    function takeCode(text: string): void {
        const found = WifiList.parseCard(text);
        if (!found) {
            root.scanNote = "That code is not a Wi-Fi network";
            return;
        }
        root.takeCard(found);
    }

    function takeCard(found: var): void {
        root.show("join", {
            card: found
        });
    }

    function share(): void {
        root.show("share", {});
    }

    function openActions(): void {
        root.asks(footer, root.actions(), footer.width / 2, footer.height / 2);
    }

    function actions(): var {
        const acts = [];
        if (root.primaryLabel)
            acts.push({
                icon: "keyboard_return",
                label: root.primaryLabel,
                run: () => root.primary()
            });
        if (root.mode === "share") {
            if (Network.card)
                acts.push({
                    icon: "content_copy",
                    label: "Copy as a Wi-Fi code",
                    run: () => root.copyCode()
                });
            acts.push({
                icon: "invert_colors",
                label: root.colourful ? "Ink on paper" : "In colour",
                run: () => root.colourful = !root.colourful
            });
        } else if (root.mode === "scan") {
            for (const option of root.options)
                if (option !== root.options[root.picked])
                    acts.push({
                        icon: option.icon,
                        label: option.label,
                        run: () => root.pick(option)
                    });
        } else {
            const n = root.network;
            if (root.joined && root.shareable)
                acts.push({
                    icon: "qr_code_2",
                    label: "Share as a QR code",
                    run: () => root.share()
                });
            if (root.joined && Network.ipAddress)
                acts.push({
                    icon: "content_copy",
                    label: "Copy address",
                    run: () => root.leave(() => System.copyText(Network.ipAddress))
                });
            if (root.phase === "portal")
                acts.push({
                    icon: "refresh",
                    label: "Check again",
                    run: () => Network.checkNow()
                });
            if (n && (root.joined || root.phase === "joining"))
                acts.push({
                    icon: "link_off",
                    label: root.joined ? "Disconnect" : "Stop joining",
                    run: () => {
                        n.disconnect();
                        root.back();
                    }
                });
            if (n?.known)
                acts.push({
                    icon: "delete",
                    label: "Forget",
                    alarm: true,
                    tucked: true,
                    run: () => {
                        Network.forget(n);
                        root.back();
                    }
                });
        }
        const screen = root.source.search.screenName;
        acts.push({
            icon: "settings",
            label: "Wi-Fi settings",
            tucked: true,
            run: () => root.leave(() => Panels.open("settings", {
                        screen: screen,
                        page: "wifi"
                    }))
        });
        return acts;
    }

    function claimKey(event: var): bool {
        if (Search.opensSheet(event.key, event.modifiers)) {
            root.openActions();
            return true;
        }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.primary();
            return true;
        }
        if (root.mode === "scan" && (event.key === Qt.Key_Down || event.key === Qt.Key_Up || event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)) {
            const step = event.key === Qt.Key_Down || event.key === Qt.Key_Tab ? 1 : -1;
            root.picked = (root.picked + step + root.options.length) % root.options.length;
            return true;
        }
        return false;
    }

    Process {
        id: clipboardReader

        command: [Quickshell.shellPath("scripts/wifi-qr.sh"), "clipboard"]

        stdout: StdioCollector {
            onStreamFinished: {
                const found = WifiList.cardIn(text);
                root.copied = found;
                root.picked = 0;
            }
        }
    }

    Item {
        id: body

        readonly property real inset: Appearance.padding.normal

        x: body.inset
        width: root.width - body.inset * 2
        anchors.top: parent.top
        anchors.topMargin: Appearance.padding.normal
        anchors.bottom: footer.top
        implicitHeight: loader.implicitHeight + Appearance.padding.normal * 2

        Loader {
            id: loader

            width: body.width
            sourceComponent: root.mode === "share" ? shareBody : root.mode === "scan" ? scanBody : root.mode === "join" ? joinBody : null
        }
    }

    Component {
        id: joinBody

        Column {
            width: body.width
            spacing: Appearance.padding.card

            StyledText {
                width: parent.width
                visible: !root.identityForm
                text: root.heading
                font.pixelSize: Appearance.font.size.large
                font.bold: true
                wrapMode: Text.Wrap
            }

            Loader {
                width: parent.width
                active: root.needs === "identity" && root.asking
                visible: active
                onItemChanged: root.identityForm = item

                sourceComponent: IdentityField {
                    readonly property string kind: Network.signInKind(root.network)

                    placeholder: root.name
                    capsLock: Keymap.capsLock
                    onCapsAsked: Keymap.refresh()
                    methods: Network.signInMethods(kind)
                    refusal: Network.signInRefusal(kind)
                    domain: Network.knownServer(root.name)
                    busy: Network.enrollingName === root.name
                    checking: Network.enrollChecking
                    note: Network.enrollFailedName === root.name ? Network.enrollDetail || `Could not sign in: ${Network.enrollTrouble}.` : Network.checkedName === root.name ? Network.checkedNote : ""
                    noteIsTrouble: Network.enrollFailedName === root.name
                    suggestion: Network.checkedName === root.name ? Network.checkedServer : Network.enrollFailedName === root.name ? Network.enrollServer : ""
                    readServer: text => Network.serverName(text)
                    schoolOf: (domain, identity) => Network.school(domain, identity)
                    innerOf: method => Network.innerMethods(method)
                    innerLabel: inner => Network.innerName(inner)
                    outerOf: (method, identity) => Network.outerIdentity(method, identity)
                    fill: Network.checkedName === root.name ? Network.checkedFill : ""
                    noteWarns: Network.checkedName === root.name && Network.checkedState === "mismatch"

                    onAccepted: (form, password) => {
                        if (!root.network)
                            return;
                        root.asking = false;
                        root.warning = "";
                        root.started = true;
                        root.fresh = false;
                        Network.joinEnterprise(root.name, kind, form, password);
                    }
                    onCheck: form => {
                        if (root.network)
                            Network.checkServer(root.name, kind, form);
                    }
                    onCancelled: root.back()
                }
            }

            WifiSteps {
                width: parent.width
                steps: root.steps.filter(step => !(step.key === "secret" && root.needs === "identity" && root.asking))
                since: root.since
                now: root.now
            }

            WifiFacts {
                width: parent.width
                visible: root.joinFacts.length > 0
                facts: root.joinFacts
            }
        }
    }

    Component {
        id: shareBody

        Item {
            id: share

            readonly property real side: Math.min(Math.round(body.width * 0.42), Appearance.sizes.rowHeight * 8)

            width: body.width
            implicitHeight: Math.max(share.side, shareFacts.implicitHeight)

            QrCode {
                id: code

                width: share.side
                maxHeight: share.side
                text: Network.card
                colourful: root.colourful
                flippable: true
                onFlipped: root.colourful = !root.colourful
            }

            Column {
                id: shareFacts

                x: share.side + Appearance.padding.large * 2
                width: share.width - x
                spacing: Appearance.padding.card

                StyledText {
                    width: parent.width
                    text: Network.activeName || "Not on Wi-Fi"
                    font.pixelSize: Appearance.font.size.large
                    font.bold: true
                    wrapMode: Text.Wrap
                }

                WifiFacts {
                    width: parent.width
                    facts: root.shareFacts
                }

                StyledText {
                    width: parent.width
                    visible: !!code.trouble
                    text: code.trouble
                    font.pixelSize: Appearance.font.size.small
                    color: Appearance.colour.alarm
                    wrapMode: Text.Wrap
                }
            }
        }
    }

    Component {
        id: scanBody

        Item {
            id: scan

            readonly property real lens: Math.round(body.width * 0.55)

            width: body.width
            implicitHeight: Math.max(scanner.implicitHeight, picks.implicitHeight)

            QrScanner {
                id: scanner

                width: scan.lens
                active: root.mode === "scan"
                hints: false
                note: root.scanNote
                onDecoded: text => root.takeCode(text)
            }

            Column {
                id: picks

                x: scan.lens + Appearance.padding.large
                width: scan.width - x
                spacing: Appearance.padding.small

                Repeater {
                    model: root.options

                    MenuRow {
                        required property var modelData
                        required property int index

                        width: picks.width
                        icon: modelData.icon
                        label: modelData.label
                        tips: false
                        selected: index === root.picked
                        onActivated: {
                            root.picked = index;
                            root.pick(modelData);
                        }
                    }
                }
            }
        }
    }

    PageFooter {
        id: footer

        anchors.bottom: parent.bottom
        width: root.width
        icon: root.footerIcon
        title: root.footerTitle
        note: root.flash
        primary: root.primaryLabel
        onPrimed: root.primary()
        onAsked: root.openActions()
    }
}
