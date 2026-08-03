pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs.config

// NetworkManager, adapted.
//
// The list a wifi menu wants is not the list NetworkManager gives. NM reports
// every BSSID it can hear, so a mesh or a dual-band router appears three or four
// times under one name; and it reports them in whatever order they arrived. So
// this collapses duplicates to the strongest of each name and sorts the result
// the way a person reads it: what you are on, then what you have joined before,
// then everything else by signal.
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

    // PERCENT, from the fraction Quickshell reports.
    //
    // NetworkManager's own API hands out a 0..100 integer and Quickshell divides
    // it down to 0..1, which is a perfectly good decision and a silent trap for
    // everything downstream: 0.61 read as a percentage is not a weak signal, it
    // is a signal one four-hundredth of the way up a four-bar meter, so EVERY
    // network drew one bar and the status glyph sat on `signal_wifi_0_bar`
    // forever. It looked like a design that did not react rather than an
    // arithmetic bug, which is why it survived.
    //
    // The conversion lives here, once, at the boundary. A widget that has to
    // remember which of two scales it is holding will eventually hold the wrong
    // one.
    function percent(n: var): real {
        return Math.round((n?.signalStrength ?? 0) * 100);
    }

    // Anything mid-connect, so the UI can say so rather than looking stuck.
    //
    // BY NAME, because the row that has to say "connecting" is a row from
    // `networks`, which is one deduplicated object per SSID, while the AP that
    // is actually changing state is any of the several radios behind that name.
    // On a dual-band router those are different objects, so comparing the two by
    // identity was false exactly when it was needed and the word never appeared.
    readonly property string connectingName: wifiDevice?.networks?.values?.find(n => n.stateChanging && !n.connected)?.name ?? ""

    function isConnecting(n: var): bool {
        return !!n?.name && n.name === root.connectingName;
    }

    // The adapter itself: its MAC, whether NetworkManager is driving it at all,
    // and whether it rejoins things on its own.
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

    // WHETHER IT ACTUALLY WORKS, which is not the same question as whether it
    // joined. A hotel's wifi associates perfectly and serves you a login page;
    // an AP with a dead uplink associates perfectly and serves you nothing. The
    // difference has a name in NetworkManager and the shell was not asking.
    readonly property int connectivity: Networking.connectivity
    readonly property bool canCheck: Networking.canCheckConnectivity
    readonly property bool checking: Networking.connectivityCheckEnabled
    readonly property bool online: connectivity === NetworkConnectivity.Full
    readonly property bool captive: connectivity === NetworkConnectivity.Portal

    // ON BY DEFAULT, rather than offered.
    //
    // This used to be off unless you went and found the switch, and off does not
    // mean "do not answer": it means NetworkManager GUESSES. It sees a default
    // route and reports Full. So every state below collapsed to "connected", the
    // bar's alert could not fire, and a captive portal, the one case a wifi menu
    // most needs to name, was indistinguishable from a working connection. The
    // menu had the sentence "sign in required" written in it the whole time and
    // was never in a position to say it.
    //
    // Offering it was the wrong shape for the trade. It costs one small HTTP
    // request a minute; it buys the shell knowing what it is talking about. So
    // it is on, and the switch turns it OFF.
    //
    // It is a NetworkManager-wide setting rather than something this shell owns,
    // so the choice is REMEMBERED and reapplied, not re-forced at every launch
    // over the top of a deliberate no. `wantChecking` is what config asks for;
    // `checking` is what NetworkManager is actually doing, which is what the
    // switch shows.
    readonly property bool wantChecking: Config.values.network.checkForInternet

    function applyChecking(): void {
        if (root.canCheck && Networking.connectivityCheckEnabled !== root.wantChecking)
            Networking.connectivityCheckEnabled = root.wantChecking;
    }

    // Deferred, because `canCheck` is false until NetworkManager is up, and the
    // config file lands after the defaults do.
    onWantCheckingChanged: root.applyChecking()
    onCanCheckChanged: root.applyChecking()
    Component.onCompleted: root.applyChecking()

    function setChecking(on: bool): void {
        Config.set("network.checkForInternet", on);
    }

    function checkNow(): void {
        Networking.checkConnectivity();
    }

    // ASKING AT THE MOMENT IT MATTERS. NetworkManager's own check is on a timer,
    // an interval that a fresh install sets to a minute, and the minute after
    // joining a hotel network is exactly the minute you spend wondering why
    // nothing loads. Waiting it out means the shell tells you what you have
    // already worked out for yourself.
    Timer {
        id: settle

        interval: 1500
        onTriggered: if (root.checking)
            root.checkNow()
    }

    onActiveNameChanged: settle.restart()

    // And while the answer is bad, ask more often. Signing in happens in a
    // browser, outside this shell, and there is no signal for "they finished":
    // the only way the notice clears itself when you come back is to keep
    // looking. Bounded to exactly that state, so a working connection is not
    // paying for it.
    Timer {
        running: root.connected && root.checking && !root.online
        interval: 8000
        repeat: true
        onTriggered: root.checkNow()
    }

    // WHERE THE LOGIN PAGE IS.
    //
    // NetworkManager knows, and for a good reason: the URL it fetches to test
    // the connection is the URL the portal intercepted, and that redirect is
    // literally how it concluded "Portal". So it is the one address guaranteed
    // to land on the login page rather than on a cached copy of somewhere else.
    //
    // Quickshell does not expose the property, so it is read once off the bus.
    // That is a read of one string at startup, not this shell growing a habit of
    // driving NetworkManager through its command line; the fallback is only for
    // a machine whose NetworkManager predates the property.
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
                // `s "http://ping.archlinux.org/nm-check.txt"`
                const m = text.trim().match(/^s\s+"(.*)"$/);
                if (m)
                    root.checkUri = m[1];
            }
        }
    }

    // What the connection is worth, in the order a person would ask it: joined
    // at all, then whether anything is on the other end. Empty while the check
    // is off, because the only honest thing to say then is nothing.
    function reachLabel(): string {
        if (!root.connected || !root.checking)
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

    // One entry per network NAME, strongest first, in reading order.
    //
    // THE CONNECTED ONE ALWAYS WINS, whichever way round the two arrive. The
    // rule used to be "keep the strongest, or this one if it is connected",
    // which protects an incoming connected AP and not an incumbent one: a
    // stronger idle radio on the same SSID overwrote the one actually carrying
    // the connection, and the row for the network you were on lost its
    // `connected` flag. It then showed its security instead of "connected", and
    // pressing it called connect() on a network already connected rather than
    // disconnecting. A dual-band router is exactly the case this dedup exists
    // for, so it was wrong precisely where it mattered.
    readonly property var networks: {
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
            return b.signalStrength - a.signalStrength;
        });
    }

    function setEnabled(on: bool): void {
        Networking.wifiEnabled = on;
    }

    // "Needs a passphrase", which is not the same as "encrypted": the member is
    // Open, not None (comparing against a member that does not exist yields
    // undefined and every network came back secured, padlock and all), and OWE
    // is encrypted but joins without asking for anything.
    function secured(n: var): bool {
        const s = n?.security;
        return s !== undefined && s !== WifiSecurityType.Open && s !== WifiSecurityType.Owe && s !== WifiSecurityType.Unknown;
    }

    // A PASSWORD IS NOT ENOUGH FOR ALL OF THEM. Enterprise networks want an
    // identity and often a certificate, which arrive as a settings profile, not
    // as a string typed into a box. The menu offered a passphrase field for them
    // anyway, which could only ever fail; there is nothing this shell can do for
    // them yet beyond saying so and joining the ones already saved.
    function enterprise(n: var): bool {
        const s = n?.security;
        return s === WifiSecurityType.Wpa2Eap || s === WifiSecurityType.WpaEap || s === WifiSecurityType.Leap || s === WifiSecurityType.DynamicWep || s === WifiSecurityType.Wpa3SuiteB192;
    }

    function securityLabel(n: var): string {
        if (!secured(n))
            return "open";
        return WifiSecurityType.toString(n.security).toLowerCase();
    }

    // What a row says about itself, in the order it becomes true.
    function stateLabel(n: var): string {
        if (!n)
            return "";
        if (n.connected)
            return root.reachLabel() || "connected";
        if (root.isConnecting(n))
            return "connecting";
        if (root.failedName === n.name)
            return root.failureLabel();
        if (root.enterprise(n))
            return `${root.securityLabel(n)}, needs a profile`;
        return n.known ? `${root.securityLabel(n)}, saved` : root.securityLabel(n);
    }

    function forget(n: var): void {
        if (n) {
            root.clearFailure(n.name);
            n.forget();
        }
    }

    // WHY IT DID NOT WORK. NetworkManager says so, over a signal per network,
    // and nothing was listening: a rejected passphrase closed the prompt, left
    // the row exactly as it was, and looked for all the world like a button that
    // did nothing. "Wrong password" is the single most useful sentence a wifi
    // menu can say and it was the one thing this one could not.
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

    // One watcher per network object, rebuilt with the list. The signal is on
    // the network rather than on the device, and it carries only a reason, so
    // WHICH network failed has to come from the object that emitted it.
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

                // Succeeding is the only real answer to having failed.
                function onConnectedChanged(): void {
                    if (watcher.modelData.connected)
                        root.clearFailure(watcher.modelData.name);
                }
            }
        }
    }

    // The status bar's glyph, which is about the CONNECTION and only about the
    // states that are not a level: no adapter, switched off, on but joined to
    // nothing, joined to something that goes nowhere.
    //
    // The four-step ramp of font glyphs that used to live here is gone. It was
    // assembled out of two icon families because no single one had four legible
    // steps, and its whole job was to draw a meter a font cannot draw. The bar
    // draws a real meter now, so the ramp was only ever reachable in the states
    // where strength is not the point, and it had drifted into rounding its
    // steps differently from the meter it was standing in for.
    function icon(): string {
        if (!root.available || !root.enabled)
            return "wifi_off";
        if (!root.connected)
            return "signal_wifi_bad";
        return "wifi";
    }

    // Joined, and going nowhere. Worth the bar's one accent, for the same reason
    // a muted microphone is: you will otherwise spend a minute blaming
    // everything except the network.
    //
    // OFF THE LABEL, so there is one enumeration of what counts as broken rather
    // than two that can drift apart. It used to be `!online`, which is not the
    // same set: NetworkManager has a fifth state, Unknown, and it means "the
    // check has not come back yet", not "there is nothing there". Its own
    // documentation says a shell should assume the internet might be fine in
    // that state and specifically not raise a portal window.
    //
    // Inverting Full swept Unknown in with Limited and None, and Unknown is
    // exactly where every connection starts: for the second and a half between
    // joining a network and the first check landing, and again at every launch
    // while the check is being switched on, the bar lit its alert and the menu
    // said "no internet" about a network that was about to be fine. A warning
    // that fires every single time you join anything is one you learn to
    // ignore, which would have cost the real one its whole meaning.
    readonly property bool stranded: !!root.reachLabel()

    // Scanning costs power, so it runs while something is looking at the list
    // and stops when nothing is.
    function watch(on: bool): void {
        if (root.wifiDevice)
            root.wifiDevice.scannerEnabled = on;
    }
}
