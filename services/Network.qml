pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs.config

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
        const steps = Appearance.sizes.signalBands;
        return Math.ceil(root.percent(n) / (100 / steps));
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
    readonly property string wiredName: root.wiredDevice?.networks?.values?.find(n => n.connected)?.name ?? ""
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

    onCarrierChanged: settle.restart()
    onWiredLabelChanged: settle.restart()

    onActiveNameChanged: {
        settle.restart();

        if (root.sharing)
            root.readCard();
        else
            root.dropCard();
    }

    Timer {
        running: root.linked && root.checking && !root.online
        interval: 8000
        repeat: true
        onTriggered: root.checkNow()
    }

    readonly property string portalUri: Config.values.network.portalUri || root.checkUri || "http://nmcheck.gnome.org/"

    property string checkUri: ""

    function openPortal(): void {
        Quickshell.execDetached(["xdg-open", root.portalUri]);
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

    readonly property var scan: {
        const seen = {};
        for (const n of wifiDevice?.networks?.values ?? []) {
            if (!n.name)
                continue;
            const best = seen[n.name];
            if (!best || (n.connected && !best.connected) || (!best.connected && n.signalStrength > best.signalStrength))
                seen[n.name] = n;
        }
        return Object.values(seen).sort((a, b) => {
            if (a.connected !== b.connected)
                return a.connected ? -1 : 1;
            if (a.known !== b.known)
                return a.known ? -1 : 1;
            const ba = root.bars(a);
            const bb = root.bars(b);
            if (ba !== bb)
                return bb - ba;
            return a.name.localeCompare(b.name);
        });
    }

    property var networks: []

    function settled(next: var): var {
        const now = root.networks;
        if (now.length !== next.length)
            return next;
        const live = new Set(root.wifiDevice?.networks?.values ?? []);
        for (let i = 0; i < now.length; i++) {
            const a = now[i];
            const b = next[i];
            if (a === b)
                continue;
            if (a.name !== b.name || a.connected !== b.connected || !live.has(a))
                return next;
        }
        return now;
    }

    onScanChanged: {
        const next = root.settled(root.scan);
        if (next !== root.networks)
            root.networks = next;
    }

    function find(name: string): var {
        return root.scan.find(n => n.name === name) ?? null;
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
            return "signing in";
        if (root.enrollFailedName === n.name)
            return root.enrollTrouble;
        return "";
    }

    function forget(n: var): void {
        if (n) {
            root.clearFailure(n.name);
            root.clearEnroll(n.name);
            n.forget();
        }
    }

    property string enrollingName: ""

    property string enrollFailedName: ""
    property string enrollTrouble: ""

    property var enrollArgs: []

    function clearEnroll(name: string): void {
        if (root.enrollFailedName === name) {
            root.enrollFailedName = "";
            root.enrollTrouble = "";
        }
    }

    function failEnroll(why: string): void {
        root.enrollFailedName = root.enrollingName;
        root.enrollTrouble = why;
        root.enrollingName = "";
    }

    function joinEnterprise(name: string, identity: string, password: string, eap: string, phase2: string): void {
        if (!name || root.enrollingName)
            return;
        if (!root.deviceName) {
            root.enrollFailedName = name;
            root.enrollTrouble = "there is no wireless adapter to put it on";
            return;
        }

        root.clearFailure(name);
        root.enrollFailedName = "";
        root.enrollTrouble = "";
        root.enrollingName = name;

        const method = eap || "peap";
        const args = ["wifi-sec.key-mgmt", "wpa-eap", "802-1x.eap", method, "802-1x.identity", identity, "802-1x.password", password];
        if (method !== "tls")
            args.push("802-1x.phase2-auth", phase2 || "mschapv2");
        root.enrollArgs = args;

        profile.want = name;
        profile.exists = false;
        up.refused = false;
        profile.running = true;
    }

    Process {
        id: profile

        property string want: ""
        property bool exists: false

        command: ["nmcli", "-t", "-e", "no", "-f", "TYPE,NAME", "connection", "show"]

        stdout: StdioCollector {
            onStreamFinished: {
                if (profile.want !== root.enrollingName)
                    return;
                profile.exists = text.split("\n").some(line => {
                    const cut = line.indexOf(":");
                    return cut > 0 && line.slice(0, cut) === "802-11-wireless" && line.slice(cut + 1) === profile.want;
                });
            }
        }

        onExited: code => {
            if (profile.want !== root.enrollingName)
                return;
            if (code !== 0) {
                root.failEnroll("could not ask NetworkManager what it has saved");
                return;
            }
            const head = profile.exists ? ["nmcli", "connection", "modify", profile.want] : ["nmcli", "connection", "add", "type", "wifi", "con-name", profile.want, "ifname", root.deviceName, "ssid", profile.want];
            enrol.command = head.concat(root.enrollArgs);
            enrol.running = true;
        }
    }

    Process {
        id: enrol

        onExited: code => {
            if (!root.enrollingName)
                return;
            if (code !== 0) {
                root.failEnroll("NetworkManager would not take the profile");
                return;
            }
            up.command = ["nmcli", "--wait", "30", "connection", "up", "id", root.enrollingName];
            up.running = true;
        }
    }

    Process {
        id: up

        property bool refused: false

        function refuse(line: string): void {
            if (up.refused || !root.enrollingName)
                return;
            if (!/passwords or encryption keys|required to access the wireless network|not given in .passwd-file|cannot ask without/i.test(line))
                return;

            const name = root.enrollingName;
            const ours = !profile.exists;

            up.refused = true;
            root.failEnroll("wrong username or password");
            up.running = false;

            if (ours) {
                discard.command = ["nmcli", "connection", "delete", "id", name];
                discard.running = true;
            }
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
            switch (code) {
            case 0:
                root.enrollingName = "";
                return;
            case 3:
                return root.failEnroll("no answer, so nothing was checked");
            case 4:
                return root.failEnroll("wrong username or password");
            case 8:
                return root.failEnroll("NetworkManager is not running");
            case 10:
                return root.failEnroll("it went away while signing in");
            }
            root.failEnroll("could not sign in");
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

        root.clearFailure(n.name);

        if (root.secured(n) && card.password)
            n.connectWithPsk(card.password);
        else
            n.connect();
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

    function noteFailure(name: string, reason: int): void {
        root.failedName = name;
        root.failedReason = reason;
    }

    function clearFailure(name: string): void {
        if (root.failedName === name) {
            root.failedName = "";
            root.failedReason = ConnectionFailReason.Unknown;
        }
    }

    function failureLabel(): string {
        switch (root.failedReason) {
        case ConnectionFailReason.NoSecrets:
            return "wrong password";
        case ConnectionFailReason.WifiAuthTimeout:
            return "no answer";
        case ConnectionFailReason.WifiNetworkLost:
            return "it went away";
        case ConnectionFailReason.WifiClientDisconnected:
            return "it hung up";
        }
        return "could not join";
    }

    Instantiator {
        model: root.wifiDevice?.networks ?? null

        delegate: QtObject {
            id: watcher

            required property var modelData

            readonly property Connections link: Connections {
                target: watcher.modelData

                function onConnectionFailed(reason: int): void {
                    root.noteFailure(watcher.modelData.name, reason);
                }

                function onConnectedChanged(): void {
                    if (watcher.modelData.connected) {
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

    readonly property bool wantScanning: Config.values.network.keepListFresh

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

    function setScanning(on: bool): void {
        Config.set("network.keepListFresh", on);
    }
}
