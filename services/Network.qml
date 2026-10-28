pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs.config
import qs.components
import "wifilist.js" as WifiList

Singleton {
    id: root

    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null

    readonly property bool available: !!wifiDevice
    readonly property bool enabled: Networking.wifiEnabled
    readonly property bool hardwareEnabled: Networking.wifiHardwareEnabled

    readonly property var active: wifiDevice?.networks?.values?.find(n => n.connected) ?? null
    readonly property bool connected: !!active
    readonly property string activeName: active?.name ?? ""
    readonly property real activeStrength: root.percent(active)

    function percent(n: var): real {
        return Math.round((n?.signalStrength ?? 0) * 100);
    }

    function bars(n: var): int {
        return WifiList.band(n?.signalStrength ?? 0, Config.values.control.signalBands);
    }

    readonly property string connectingName: wifiDevice?.networks?.values?.find(n => n.stateChanging && !n.connected)?.name ?? ""

    function isConnecting(n: var): bool {
        return !!n?.name && n.name === root.connectingName;
    }

    readonly property string address: wifiDevice?.address ?? ""
    readonly property bool autoconnect: !!wifiDevice?.autoconnect
    readonly property bool managed: !!wifiDevice?.nmManaged
    readonly property bool scanning: !!wifiDevice?.scannerEnabled
    readonly property string deviceName: wifiDevice?.name ?? ""

    function setAutoconnect(on: bool): void {
        if (root.wifiDevice)
            root.wifiDevice.autoconnect = on;
    }

    function setManaged(on: bool): void {
        if (root.wifiDevice)
            root.wifiDevice.nmManaged = on;
    }

    readonly property var wiredDevices: Networking.devices.values.filter(d => d.type === DeviceType.Wired)
    readonly property var wiredDevice: root.wiredDevices.find(d => d.connected) ?? root.wiredDevices[0] ?? null

    readonly property bool wiredAvailable: !!root.wiredDevice
    readonly property bool wiredConnected: !!root.wiredDevice?.connected
    readonly property bool wiredConnecting: root.wiredDevice?.state === ConnectionState.Connecting

    readonly property string wiredDeviceName: root.wiredDevice?.name ?? ""
    readonly property string wiredName: root.connectedName(root.wiredDevice)
    function connectedName(device: var): string {
        for (const n of device?.networks?.values ?? []) {
            if (n?.connected)
                return typeof n.name === "string" ? n.name : "";
        }
        return "";
    }

    readonly property string wiredLabel: root.wiredName || root.wiredDeviceName

    readonly property string wiredAddress: root.wiredDevice?.address ?? ""
    readonly property bool wiredAutoconnect: !!root.wiredDevice?.autoconnect
    readonly property bool wiredManaged: !!root.wiredDevice?.nmManaged

    function setWiredAutoconnect(on: bool): void {
        if (root.wiredDevice)
            root.wiredDevice.autoconnect = on;
    }

    function setWiredManaged(on: bool): void {
        if (root.wiredDevice)
            root.wiredDevice.nmManaged = on;
    }

    readonly property bool wiredShowing: root.wiredAvailable && (root.wiredConnected || root.wiredConnecting || !root.wiredManaged)

    readonly property string carrier: root.wiredConnected ? "wired" : root.connected ? "wifi" : ""
    readonly property bool linked: !!root.carrier

    readonly property int connectivity: Networking.connectivity
    readonly property bool canCheck: Networking.canCheckConnectivity
    readonly property bool checking: Networking.connectivityCheckEnabled
    readonly property bool online: connectivity === NetworkConnectivity.Full
    readonly property bool captive: connectivity === NetworkConnectivity.Portal

    readonly property bool wantChecking: Config.values.network.checkForInternet

    function applyChecking(): void {
        if (root.canCheck && Networking.connectivityCheckEnabled !== root.wantChecking)
            Networking.connectivityCheckEnabled = root.wantChecking;
    }

    onWantCheckingChanged: root.applyChecking()
    onCanCheckChanged: root.applyChecking()

    Component.onCompleted: {
        root.applyChecking();
        root.networks = root.scan;
        scanSettle.restart();
    }

    function setChecking(on: bool): void {
        Config.set("network.checkForInternet", on);
    }

    function checkNow(): void {
        Networking.checkConnectivity();
    }

    Timer {
        id: settle

        interval: 1500
        onTriggered: if (root.checking)
            root.checkNow()
    }

    onCarrierChanged: {
        settle.restart();
        recheck.reset();
    }
    onWiredLabelChanged: settle.restart()

    onActiveNameChanged: {
        settle.restart();

        if (root.sharing)
            root.readCard();
        else
            root.dropCard();
    }

    Backoff {
        id: recheck

        running: root.linked && root.checking && !root.online
        base: 8000
        cap: 120000
        onDue: root.checkNow()
    }

    readonly property string portalUri: Config.values.network.portalUri || root.checkUri || "http://nmcheck.gnome.org/"

    property string checkUri: ""

    function openPortal(): void {
        Quickshell.execDetached(["xdg-open", root.portalUri]);
        recheck.reset();
    }

    Process {
        running: true
        command: ["busctl", "--system", "get-property", "org.freedesktop.NetworkManager", "/org/freedesktop/NetworkManager", "org.freedesktop.NetworkManager", "ConnectivityCheckUri"]

        stdout: StdioCollector {
            onStreamFinished: {

                const m = text.trim().match(/^s\s+"(.*)"$/);
                if (m)
                    root.checkUri = m[1];
            }
        }
    }

    function reachLabel(): string {
        if (!root.linked || !root.checking)
            return "";
        switch (root.connectivity) {
        case NetworkConnectivity.Portal:
            return "sign in required";
        case NetworkConnectivity.Limited:
            return "no internet";
        case NetworkConnectivity.None:
            return "no internet";
        }
        return "";
    }

    function reachFor(which: string): string {
        return root.carrier === which ? root.reachLabel() : "";
    }

    readonly property var scan: WifiList.arrange(root.wifiDevice?.networks?.values ?? [], Config.values.control.signalBands)

    property var networks: []

    readonly property var knownNetworks: root.networks.filter(n => n.known || n.connected)

    onScanChanged: {
        const next = WifiList.settle(root.networks, root.scan);
        if (next !== root.networks)
            root.networks = next;
    }

    function find(name: string): var {
        return root.scan.find(n => n.name === name) ?? null;
    }

    function pick(names: var): var {
        return WifiList.pick(names, root.networks);
    }

    function setEnabled(on: bool): void {
        Networking.wifiEnabled = on;
    }

    function secured(n: var): bool {
        const s = n?.security;
        return s !== undefined && s !== WifiSecurityType.Open && s !== WifiSecurityType.Owe && s !== WifiSecurityType.Unknown;
    }

    function enterprise(n: var): bool {
        const s = n?.security;
        return s === WifiSecurityType.Wpa2Eap || s === WifiSecurityType.WpaEap || s === WifiSecurityType.Leap || s === WifiSecurityType.DynamicWep || s === WifiSecurityType.Wpa3SuiteB192;
    }

    function securityLabel(n: var): string {
        const s = n?.security;
        if (s === undefined)
            return "open";
        switch (s) {
        case WifiSecurityType.Wpa3SuiteB192:
            return "wpa3 enterprise";
        case WifiSecurityType.Wpa2Eap:
            return "wpa2 enterprise";
        case WifiSecurityType.WpaEap:
            return "wpa enterprise";
        case WifiSecurityType.Leap:
            return "leap";
        case WifiSecurityType.Sae:
            return "wpa3";
        case WifiSecurityType.Wpa2Psk:
            return "wpa2";
        case WifiSecurityType.WpaPsk:
            return "wpa";
        case WifiSecurityType.StaticWep:
            return "wep";
        case WifiSecurityType.DynamicWep:
            return "dynamic wep";
        case WifiSecurityType.Owe:
            return "owe";
        case WifiSecurityType.Open:
        case WifiSecurityType.Unknown:
            return "open";
        }
        return WifiSecurityType.toString(s).toLowerCase();
    }

    function stateLabel(n: var): string {
        if (!n)
            return "";
        if (n.connected)
            return root.reachLabel() || "connected";
        if (root.isConnecting(n))
            return "connecting";
        if (root.failedName === n.name)
            return root.failureLabel();
        if (root.enrollingName === n.name)
            return root.enrollChecking ? "checking the server" : "signing in";
        if (root.enrollFailedName === n.name)
            return root.enrollTrouble;
        return "";
    }

    function forget(n: var): void {
        if (n) {
            if (root.trying === n.name)
                root.trying = "";
            root.clearFailure(n.name);
            root.clearEnroll(n.name);
            n.forget();
        }
    }

    property string enrollingName: ""
    property bool enrollChecking: false
    property string enrollProfile: ""
    property string enrollDomain: ""
    property int enrollSince: 0
    property bool enrollReading: false
    property string enrollWhy: ""

    property string enrollFailedName: ""
    property string enrollTrouble: ""
    property string enrollDetail: ""
    property string enrollServer: ""

    property string checkedName: ""
    property string checkedNote: ""
    property string checkedServer: ""
    property string checkedFill: ""
    property string checkedState: ""
    property string enrollIdentity: ""

    property var enrollArgs: []
    property string enrollSecrets: ""

    function signInKind(n: var): string {
        switch (n?.security) {
        case WifiSecurityType.Wpa2Eap:
        case WifiSecurityType.WpaEap:
            return "wpa";
        case WifiSecurityType.DynamicWep:
            return "wep";
        case WifiSecurityType.Wpa3SuiteB192:
            return "suiteb";
        case WifiSecurityType.Leap:
            return "leap";
        }
        return "";
    }

    function clearEnroll(name: string): void {
        if (root.enrollFailedName === name) {
            root.enrollFailedName = "";
            root.enrollTrouble = "";
            root.enrollDetail = "";
            root.enrollServer = "";
        }
        if (root.checkedName === name) {
            root.checkedName = "";
            root.checkedNote = "";
            root.checkedServer = "";
            root.checkedFill = "";
            root.checkedState = "";
        }
    }

    function failEnroll(why: string, detail: string): void {
        root.enrollArgs = [];
        root.enrollSecrets = "";
        root.enrollFailedName = root.enrollingName;
        root.enrollTrouble = why;
        root.enrollDetail = detail;
        root.enrollingName = "";
        root.enrollChecking = false;
    }

    function startEnroll(name: string, checking: bool, profileName: string, domain: string, args: var, secrets: string, copy: var): void {
        if (!root.deviceName) {
            root.enrollFailedName = name;
            root.enrollTrouble = "there is no wireless adapter to put it on";
            root.enrollDetail = "";
            return;
        }

        root.clearFailure(name);
        root.clearEnroll(name);
        root.enrollingName = name;
        root.enrollChecking = checking;
        root.enrollProfile = profileName;
        root.enrollDomain = domain;
        root.enrollSince = Math.floor(Date.now() / 1000) - 1;
        root.enrollReading = false;
        root.enrollArgs = args;
        root.enrollSecrets = secrets;

        profile.want = profileName;
        profile.exists = false;
        up.refused = false;
        if (copy.length) {
            stash.command = copy;
            stash.running = true;
        } else {
            profile.running = true;
        }
    }

    Process {
        id: stash

        onExited: code => {
            if (!root.enrollingName)
                return;
            if (code !== 0) {
                root.failEnroll("could not put the school's certificate in place", "");
                return;
            }
            profile.running = true;
        }
    }

    function signInMethods(kind: string): var {
        return WifiList.signInMethods(kind);
    }

    function signInRefusal(kind: string): string {
        return WifiList.signInRefusal(kind);
    }

    function knownServer(name: string): string {
        return WifiList.knownServer(name);
    }

    function innerMethods(method: string): var {
        return WifiList.innerMethods(method);
    }

    function innerName(inner: string): string {
        return WifiList.innerName(inner);
    }

    function outerIdentity(method: string, identity: string): string {
        return WifiList.outerIdentity(method, identity);
    }

    function serverName(text: string): string {
        return WifiList.serverDomain(text);
    }

    readonly property string certificateDir: `${Config.stateDir}/certificates`

    function school(domain: string, identity: string): var {
        const entry = WifiList.schoolFor(domain, identity);
        return entry ? {
            school: entry.school,
            suffix: entry.suffix
        } : null;
    }

    function signInFiles(form: var, checking: bool): var {
        const home = Quickshell.env("HOME") ?? "";
        const files = Object.assign({}, form);
        for (const field of ["certificate", "key"]) {
            if (!form[field])
                continue;
            files[field] = WifiList.filePath(form[field], home);
            if (!files[field])
                return null;
        }
        files.authority = checking ? WifiList.checkAuthority(form, home, root.certificateDir) : WifiList.trustedAuthority(form, home, root.certificateDir);
        return files.authority === null ? null : files;
    }

    function schoolCopy(files: var): var {
        if (files.trust !== "school" || !files.authority)
            return [];
        const file = files.authority.slice(files.authority.lastIndexOf("/") + 1);
        return ["install", "-D", "-m", "0644", Quickshell.shellPath(`assets/certificates/${file}`), files.authority];
    }

    function joinEnterprise(name: string, kind: string, form: var, password: string): void {
        if (!name || root.enrollingName)
            return;
        const files = root.signInFiles(form, false);
        const args = files ? WifiList.signInArgs(kind, files) : null;
        if (!args) {
            root.enrollFailedName = name;
            root.enrollTrouble = files ? "the sign-in is missing a field" : form.trust === "school" ? "that school's certificate does not cover this server" : "a certificate file needs its full path";
            root.enrollDetail = "";
            return;
        }
        root.enrollIdentity = files.identity;
        root.startEnroll(name, false, name, WifiList.serverDomain(files.domain), args, WifiList.signInSecrets(files.method, files.identity, password), root.schoolCopy(files));
    }

    function checkServer(name: string, kind: string, form: var): void {
        const files = root.signInFiles(form, true);
        const args = files ? WifiList.serverCheckArgs(kind, files) : null;
        if (!name || root.enrollingName || !args)
            return;
        root.enrollIdentity = files.identity ?? "";
        root.startEnroll(name, true, `${name} server check`, "", args, WifiList.serverCheckSecrets(files), root.schoolCopy(files));
    }

    Process {
        id: profile

        property string want: ""
        property bool exists: false

        command: ["nmcli", "-t", "-e", "no", "-f", "TYPE,NAME", "connection", "show"]

        stdout: StdioCollector {
            onStreamFinished: {
                if (profile.want !== root.enrollProfile || !root.enrollingName)
                    return;
                profile.exists = text.split("\n").some(line => {
                    const cut = line.indexOf(":");
                    return cut > 0 && line.slice(0, cut) === "802-11-wireless" && line.slice(cut + 1) === profile.want;
                });
            }
        }

        onExited: code => {
            if (profile.want !== root.enrollProfile || !root.enrollingName)
                return;
            if (code !== 0) {
                root.failEnroll("could not ask NetworkManager what it has saved", "");
                return;
            }
            const head = profile.exists ? ["nmcli", "connection", "modify", "id", profile.want] : ["nmcli", "connection", "add", "type", "wifi", "con-name", profile.want, "ifname", root.deviceName, "ssid", root.enrollingName];
            enrol.said = "";
            enrol.command = head.concat(root.enrollArgs);
            root.enrollArgs = [];
            enrol.running = true;
        }
    }

    function failSignIn(why: string): void {
        if (root.enrollReading || !root.enrollingName)
            return;
        root.enrollReading = true;
        root.enrollWhy = why;
        serverLog.command = ["journalctl", "-u", "wpa_supplicant", "-o", "cat", "-q", "--no-pager", "--since", `@${root.enrollSince}`];
        serverLog.running = true;
    }

    function finishSignIn(log: string): void {
        if (!root.enrollReading)
            return;
        root.enrollReading = false;
        const name = root.enrollingName;
        const made = !profile.exists || root.enrollChecking;
        const trouble = WifiList.serverTrouble(log, root.deviceName);

        if (root.enrollChecking) {
            root.failEnroll("", "");
            root.enrollFailedName = "";
            root.checkedName = name;
            const match = WifiList.serverMatch(trouble?.kind === "name" ? trouble.server : "", root.enrollIdentity);
            root.checkedState = match.state;
            root.checkedFill = match.fill;
            root.checkedServer = match.state === "match" ? "" : trouble?.kind === "name" ? trouble.server : "";
            root.checkedNote = WifiList.serverSeenMessage(trouble, root.enrollIdentity);
        } else if (trouble) {
            root.failEnroll(WifiList.serverLabel(trouble), WifiList.serverMessage(trouble, root.enrollDomain));
            root.enrollServer = trouble.kind === "name" ? trouble.server : "";
        } else {
            root.failEnroll(root.enrollWhy, "");
        }

        if (name && made) {
            discard.command = ["nmcli", "connection", "delete", "id", root.enrollProfile];
            discard.running = true;
        }
    }

    Process {
        id: serverLog

        stdout: StdioCollector {
            onStreamFinished: root.finishSignIn(text)
        }

        onExited: code => {
            if (code !== 0)
                root.finishSignIn("");
        }
    }

    Process {
        id: enrol

        property string said: ""

        stderr: SplitParser {
            onRead: line => enrol.said += line + "\n"
        }

        onExited: code => {
            enrol.command = [];
            if (!root.enrollingName)
                return;
            if (code !== 0) {
                root.failEnroll(/802-1x\.ca-cert/.test(enrol.said) ? "could not read the server certificate file" : /802-1x\.(client-cert|private-key)/.test(enrol.said) ? "could not read your certificate or key" : "NetworkManager would not take the profile", "");
                return;
            }
            up.command = ["nmcli", "--wait", root.enrollChecking ? "30" : "60", "connection", "up", "id", root.enrollProfile, "passwd-file", "/dev/stdin"];
            up.stdinEnabled = true;
            up.running = true;
        }
    }

    Process {
        id: up

        property bool refused: false

        stdinEnabled: true

        onStarted: {
            up.write(root.enrollSecrets);
            root.enrollSecrets = "";
            up.stdinEnabled = false;
        }

        function refuse(line: string): void {
            if (up.refused || !root.enrollingName)
                return;
            if (!/passwords or encryption keys|required to access the wireless network|not given in .passwd-file|cannot ask without|secrets were required|no valid secrets/i.test(line))
                return;

            up.refused = true;
            root.failSignIn("wrong username or password");
            up.running = false;
        }

        stdout: SplitParser {
            onRead: line => up.refuse(line)
        }

        stderr: SplitParser {
            onRead: line => up.refuse(line)
        }

        onExited: code => {
            if (up.refused || !root.enrollingName)
                return;
            if (code === 0 && !root.enrollChecking) {
                root.enrollingName = "";
                return;
            }
            switch (code) {
            case 3:
                return root.failSignIn("no answer, so nothing was checked");
            case 4:
                return root.failSignIn("wrong username or password");
            case 8:
                return root.failSignIn("NetworkManager is not running");
            case 10:
                return root.failSignIn("it went away while signing in");
            }
            root.failSignIn("could not sign in");
        }
    }

    Process {
        id: discard
    }

    function parseQr(text: string): var {
        if (!text || text.slice(0, 5).toUpperCase() !== "WIFI:")
            return null;

        const body = text.slice(5);
        const card = {
            ssid: "",
            security: "",
            password: "",
            hidden: false
        };

        let key = "";
        let buf = "";
        let onKey = true;

        for (let i = 0; i < body.length; i++) {
            const c = body[i];
            if (c === "\\") {
                buf += body[++i] ?? "";
                continue;
            }
            if (onKey) {

                if (c === ";")
                    continue;
                if (c === ":") {
                    key = buf.toUpperCase();
                    buf = "";
                    onKey = false;
                    continue;
                }
                buf += c;
                continue;
            }
            if (c === ";") {
                if (key === "S")
                    card.ssid = buf;
                else if (key === "T")
                    card.security = buf.toUpperCase();
                else if (key === "P")
                    card.password = buf;
                else if (key === "H")
                    card.hidden = buf.toLowerCase() === "true";
                key = "";
                buf = "";
                onKey = true;
                continue;
            }
            buf += c;
        }

        return card.ssid ? card : null;
    }

    function joinQr(text: string): string {
        const card = root.parseQr(text);
        if (!card)
            return "that code is not a Wi-Fi network";
        if (card.hidden)
            return `${card.ssid} is hidden, and a hidden network needs a profile`;

        const n = root.find(card.ssid);
        if (!n)
            return `${card.ssid} is not in range`;
        if (n.connected)
            return `already on ${card.ssid}`;
        if (root.enterprise(n))
            return `${card.ssid} signs in with an identity, and a card cannot carry one`;

        root.join(n, root.secured(n) ? card.password : "");
        return "";
    }

    property bool sharing: false

    property string secret: ""
    property string secretTrouble: ""

    function share(on: bool): void {
        root.sharing = on;
    }

    onSharingChanged: {
        if (root.sharing)
            root.readCard();
        else
            root.dropCard();
    }

    property var candidates: []
    property string savedPath: ""

    function readCard(): void {
        root.dropCard();

        if (!root.connected || !root.secured(root.active) || root.enterprise(root.active))
            return;
        actives.running = true;
    }

    function dropCard(): void {
        actives.running = false;
        root.candidates = [];
        root.savedPath = "";
        root.secret = "";
        root.secretTrouble = "";
    }

    Process {
        id: actives

        command: ["busctl", "--system", "--json=short", "get-property", "org.freedesktop.NetworkManager", "/org/freedesktop/NetworkManager", "org.freedesktop.NetworkManager", "ActiveConnections"]

        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.sharing)
                    return;
                try {
                    root.candidates = JSON.parse(text.trim()).data ?? [];
                } catch (e) {
                    root.candidates = [];
                }
                if (!root.candidates.length)
                    root.secretTrouble = "NetworkManager is not admitting to this connection";
            }
        }

        onExited: code => {
            if (code !== 0 && root.sharing)
                root.secretTrouble = "could not ask NetworkManager for the passphrase";
        }
    }

    Instantiator {
        model: root.candidates

        delegate: QtObject {
            id: probe

            required property string modelData

            readonly property Process ask: Process {
                running: true
                command: ["busctl", "--system", "--json=short", "get-property", "org.freedesktop.NetworkManager", probe.modelData, "org.freedesktop.NetworkManager.Connection.Active", "Type", "Connection"]

                stdout: StdioCollector {
                    onStreamFinished: {

                        const lines = text.trim().split("\n");
                        if (!root.sharing || lines.length < 2)
                            return;
                        try {
                            if (JSON.parse(lines[0]).data === "802-11-wireless")
                                root.savedPath = JSON.parse(lines[1]).data;
                        } catch (e) {
                        }
                    }
                }
            }
        }
    }

    onSavedPathChanged: {
        keys.running = false;
        if (!root.savedPath)
            return;
        keys.command = ["busctl", "--system", "--json=short", "call", "org.freedesktop.NetworkManager", root.savedPath, "org.freedesktop.NetworkManager.Settings.Connection", "GetSecrets", "s", "802-11-wireless-security"];
        keys.running = true;
    }

    Process {
        id: keys

        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.sharing)
                    return;
                try {

                    root.secret = JSON.parse(text.trim()).data[0]["802-11-wireless-security"].psk.data ?? "";
                } catch (e) {
                    root.secret = "";
                }
                if (!root.secret)
                    root.secretTrouble = "NetworkManager would not hand over the passphrase";
            }
        }

        onExited: code => {
            if (code !== 0 && root.sharing)
                root.secretTrouble = "not allowed to read this network's passphrase";
        }
    }

    function escapeQr(s: string): string {
        return s.replace(/([\\;,:"])/g, "\\$1");
    }

    function cardSecurity(n: var): string {
        if (!root.secured(n))
            return "nopass";
        return root.securityLabel(n).indexOf("wep") >= 0 ? "WEP" : "WPA";
    }

    readonly property string card: {
        if (!root.activeName || root.enterprise(root.active))
            return "";
        const kind = root.cardSecurity(root.active);
        const head = `WIFI:T:${kind};S:${root.escapeQr(root.activeName)};`;
        if (kind === "nopass")
            return `${head};`;
        return root.secret ? `${head}P:${root.escapeQr(root.secret)};;` : "";
    }

    readonly property string cardTrouble: !root.connected ? "join a network first" : root.enterprise(root.active) ? `${root.activeName} signs in with a profile, and a card cannot carry one` : root.secretTrouble

    property string failedName: ""
    property int failedReason: ConnectionFailReason.Unknown

    property string trying: ""

    signal joinFailed(string name, string kind)

    function join(n: var, psk: string): void {
        if (!n)
            return;
        root.clearFailure(n.name);
        root.trying = n.name;
        tryingExpiry.restart();
        if (psk)
            n.connectWithPsk(psk);
        else
            n.connect();
    }

    function noteFailure(name: string, reason: int): void {
        root.failedName = name;
        root.failedReason = reason;
        if (root.trying !== name)
            return;
        root.joinFailed(name, root.failureKind(reason));
        root.trying = "";
    }

    Timer {
        id: tryingExpiry

        interval: 90000
        onTriggered: root.trying = ""
    }

    function failureKind(reason: int): string {
        switch (reason) {
        case ConnectionFailReason.NoSecrets:
            return "password";
        case ConnectionFailReason.WifiAuthTimeout:
            return "timeout";
        case ConnectionFailReason.WifiNetworkLost:
            return "lost";
        case ConnectionFailReason.WifiClientDisconnected:
            return "hungup";
        }
        return "unknown";
    }

    function clearFailure(name: string): void {
        if (root.failedName === name) {
            root.failedName = "";
            root.failedReason = ConnectionFailReason.Unknown;
        }
    }

    function failureLabel(): string {
        return WifiList.failureLabel(root.failureKind(root.failedReason));
    }

    Instantiator {
        model: root.wifiDevice?.networks ?? null

        delegate: QtObject {
            id: watcher

            required property var modelData

            readonly property Connections link: Connections {
                target: watcher.modelData ?? null
                ignoreUnknownSignals: true

                function onConnectionFailed(reason: int): void {
                    if (watcher.modelData)
                        root.noteFailure(watcher.modelData.name, reason);
                }

                function onConnectedChanged(): void {
                    if (watcher.modelData?.connected) {
                        if (root.trying === watcher.modelData.name)
                            root.trying = "";
                        root.clearFailure(watcher.modelData.name);
                        root.clearEnroll(watcher.modelData.name);
                    }
                }
            }
        }
    }

    function icon(): string {
        if (root.carrier === "wired")
            return "lan";

        if (!root.available)
            return root.wiredAvailable ? "lan" : "wifi_off";
        return root.wifiIcon();
    }

    function wifiIcon(): string {
        if (!root.available || !root.enabled)
            return "wifi_off";
        if (!root.connected)
            return "signal_wifi_bad";
        return "wifi";
    }

    readonly property bool stranded: !!root.reachLabel()

    readonly property bool keepListFresh: Config.values.network.keepListFresh

    readonly property bool keepingFresh: root.keepListFresh && root.carrier === "wifi"

    property var viewers: []

    readonly property bool viewed: root.viewers.length > 0

    function setViewing(viewer: var, on: bool): void {
        const held = root.viewers.indexOf(viewer) >= 0;
        if (on && !held)
            root.viewers = root.viewers.concat([viewer]);
        else if (!on && held)
            root.viewers = root.viewers.filter(other => other !== viewer);
    }

    readonly property bool wantScanning: root.viewed || root.keepingFresh

    Timer {
        id: scanSettle

        interval: 4000
        onTriggered: root.applyScanning()
    }

    function applyScanning(): void {
        if (root.wifiDevice && root.wifiDevice.scannerEnabled !== root.wantScanning)
            root.wifiDevice.scannerEnabled = root.wantScanning;
    }

    onWantScanningChanged: root.applyScanning()
    onWifiDeviceChanged: scanSettle.restart()

    function setKeepListFresh(on: bool): void {
        Config.set("network.keepListFresh", on);
    }
}
