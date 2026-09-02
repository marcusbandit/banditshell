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

    // The same figure at the resolution it is actually SHOWN at, which is the
    // one the list is sorted on. See `scan` for why the raw percentage is the
    // wrong thing to order by, and Config's `signalBands` for why the meter's
    // step count is the number both ends read.
    function bars(n: var): int {
        const steps = Appearance.sizes.signalBands;
        return Math.ceil(root.percent(n) / (100 / steps));
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

    // ---- THE WIRE ----------------------------------------------------------
    //
    // Everything above this line is the radio, and for a long time that was the
    // whole of what this shell called "the network". On a desktop it is exactly
    // backwards: the machine is on a cable, the radio is idle, and the bar was
    // reporting the one that is doing nothing. "Wi-Fi not connected" was true,
    // and it was not the answer to the question anybody had.
    //
    // NetworkManager knows far more wired devices than the machine has ports:
    // every docker bridge and every container veth is an ethernet device to it.
    // Quickshell has already dropped those by the time `devices` is readable
    // here (measured on this box: enp6s0 and wlan0, with six bridges and four
    // veths in nmcli's own list), so this does not filter them again. What it
    // does have to handle is more than one real port, which is a laptop in a
    // dock: the one carrying traffic is the one the bar is about, and the first
    // port is only what to fall back to when none of them is.
    readonly property var wiredDevices: Networking.devices.values.filter(d => d.type === DeviceType.Wired)
    readonly property var wiredDevice: root.wiredDevices.find(d => d.connected) ?? root.wiredDevices[0] ?? null

    readonly property bool wiredAvailable: !!root.wiredDevice
    readonly property bool wiredConnected: !!root.wiredDevice?.connected
    readonly property bool wiredConnecting: root.wiredDevice?.state === ConnectionState.Connecting

    // The port, and the profile riding on it. Usually the same string, because
    // NetworkManager names a wired profile after the interface it found; on a
    // machine where somebody has named the connection they differ, and the name
    // they chose is the better label.
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

    // WHETHER THERE IS ANYTHING TO SAY ABOUT THE WIRE, which is a stricter
    // question than whether the machine has a port. Nearly every laptop has one
    // and most of them have never had a cable in it; a row reading "Ethernet /
    // not connected" over the network you are actually using is noise about a
    // socket, not news about a connection.
    //
    // So: carrying, or about to be, or held down by the one switch in this
    // shell that can hold it down. That last clause is not tidiness. Turning
    // "Managed by the system" off drops the link, and without it the row would
    // disappear on the way out and take the switch that undoes it along, which
    // makes the setting unreachable by the act of using it. A port that is idle
    // because nothing is plugged into it has no such way back and needs none.
    readonly property bool wiredShowing: root.wiredAvailable && (root.wiredConnected || root.wiredConnecting || !root.wiredManaged)

    // ---- WHICH ONE IS ACTUALLY CARRYING ------------------------------------
    //
    // "wired", "wifi", or "" for neither. The wire wins when both are up, and
    // that is not a preference: NetworkManager gives a wired connection the
    // lower metric, so the wire is the default route and an associated radio
    // beside it is a spare. A bar that drew the radio in that state would be
    // metering a link nothing is going through.
    //
    // `linked` is the question everything outside this file used to ask
    // `connected`, back when there was only one thing it could mean.
    readonly property string carrier: root.wiredConnected ? "wired" : root.connected ? "wifi" : ""
    readonly property bool linked: !!root.carrier

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

    // The list is seeded here rather than left to `scan`'s own first change,
    // because a binding that evaluates to the empty array it was already going
    // to hold announces nothing, and an adapter that is up before this
    // singleton is would then have no list until something moved.
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

    // The link changing at all is worth a fresh check: a cable going in is as
    // much a new connection to test as a network being joined.
    onCarrierChanged: settle.restart()
    onWiredLabelChanged: settle.restart()

    onActiveNameChanged: {
        settle.restart();
        // A different network is a different secret, and the one being held is
        // now somebody else's. See the share card below.
        if (root.sharing)
            root.readCard();
        else
            root.dropCard();
    }

    // And while the answer is bad, ask more often. Signing in happens in a
    // browser, outside this shell, and there is no signal for "they finished":
    // the only way the notice clears itself when you come back is to keep
    // looking. Bounded to exactly that state, so a working connection is not
    // paying for it.
    Timer {
        running: root.linked && root.checking && !root.online
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

    // THE SAME SENTENCE, BUT ONLY WHERE IT BELONGS. There is one connectivity
    // answer for the whole machine, and the menu has two rows to hang it on.
    // Hung on both, a dead uplink on the cable would put "no internet" beside a
    // radio that is carrying nothing and is not the reason for anything.
    function reachFor(which: string): string {
        return root.carrier === which ? root.reachLabel() : "";
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
    //
    // SORTED ON THE METER, not on the number behind it. NetworkManager's
    // strength wanders by a few percent between scans and there are usually two
    // or three networks within that much of each other, so an ordering by the
    // raw figure permuted itself several times a second while the four bars it
    // is drawn as sat perfectly still. Every one of those permutations is a
    // different list as far as `networks` below is concerned. Ties fall back to
    // the name, so equal-looking networks have an order at all rather than
    // whichever one the hash happened to yield first.
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

    // THE LIST, which is the scan holding still.
    //
    // `scan` above is a fresh array on every signal-strength report, and a
    // Repeater over a plain array rebuilds EVERY delegate whenever that array
    // changes identity. A wifi row is not cheap: a squircle, a meter, a
    // chevron, a password field and a folded-up layer of its own, times seven
    // rows, times however many times a second NetworkManager felt like
    // mentioning that something moved by one percent. That is the whole of why
    // the menu was slow to arrive and stayed slow while it was up, and it is
    // why the menu had to grow a freeze of its own to be usable at all.
    //
    // So the scan runs as often as it likes and this only changes when the list
    // MEANS something different: a network arrived or left, they are in a
    // different order, or one of them started or stopped carrying the
    // connection. Otherwise the very same array goes back out, the Repeater is
    // told nothing happened, and the rows that are already on screen update
    // themselves through their own live bindings to the network objects, which
    // is what those bindings were for.
    //
    // THE OBJECTS ARE KEPT, not just the names, and that needs the liveness
    // test below. Dedup picks the strongest radio behind a name, so a dual-band
    // router flips which object represents it constantly, and holding on to the
    // incumbent is exactly right up until NetworkManager forgets the AP: a
    // deleted QObject in a live binding is an error printed once per row per
    // frame. `live` is the set the device still admits to hearing.
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

    // ASSIGNED ONLY WHEN IT IS DIFFERENT. A `var` property does not promise to
    // compare what it is handed against what it holds, so writing the same array
    // back would announce a change to every binding downstream and the whole
    // point of `settled` would be lost one line after it was made.
    onScanChanged: {
        const next = root.settled(root.scan);
        if (next !== root.networks)
            root.networks = next;
    }

    // The one a name resolves to, off the SCAN rather than off the settled list
    // above: a code pointed at a network that has only just come into range
    // should join it, not be told to wait for the list to admit it exists.
    function find(name: string): var {
        return root.scan.find(n => n.name === name) ?? null;
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

    // A PASSWORD IS NOT ENOUGH FOR ALL OF THEM. An enterprise network's secret
    // is an identity and a password, checked by a RADIUS server somewhere behind
    // the access point rather than by the access point itself, and
    // NetworkManager holds that pair as a settings PROFILE: a key management of
    // wpa-eap, an EAP method, an inner phase-2 auth, and the credentials. The
    // only thing Quickshell will take is a pre-shared key, so there is no API
    // here that can build one, and for a long time that was the end of the
    // sentence: the menu offered a passphrase box that could only ever fail, or
    // later said "needs a profile" and left the person to go and open a
    // terminal.
    //
    // IT IS NOT THE END OF THE SENTENCE ANY MORE. DESIGN.md section 3 is
    // explicit that this menu covers the whole of its domain, WPA-Enterprise
    // named in the same breath as WPA personal and captive portals, and half a
    // wifi menu is exactly what guarantees the terminal goes on being the real
    // one. So `joinEnterprise` below builds the profile with nmcli, which is
    // what `~/bin/wifi` has been doing from this machine all along and does
    // without sudo: polkit grants the session user
    // org.freedesktop.NetworkManager.settings.modify.system and
    // network-control, so writing a system connection is something a desktop is
    // allowed to ask for.
    //
    // That is the ONE exception in this file and it is narrow on purpose.
    // Everything else here goes through Quickshell's API, or reads a property
    // off the bus that Quickshell does not expose; a command line standing in
    // for an API that exists is how a shell rots.
    function enterprise(n: var): bool {
        const s = n?.security;
        return s === WifiSecurityType.Wpa2Eap || s === WifiSecurityType.WpaEap || s === WifiSecurityType.Leap || s === WifiSecurityType.DynamicWep || s === WifiSecurityType.Wpa3SuiteB192;
    }

    // THE SECURITY, IN WORDS SOMEBODY WOULD SAY. This string is one hover away
    // on the row's lock and written out in full in the row's own layer, so it is
    // read by a person working out whether they are about to be asked for
    // something, and by nothing that needs to know a cipher suite.
    //
    // OFF THE ENUM MEMBERS, not off `WifiSecurityType.toString`. That
    // stringification is Quickshell's own label for its own enum: it names the
    // MECHANISM, it is free to change shape under this file whenever the enum
    // grows, and lowercasing it has produced everything from "wpa2eap" to
    // "wpa3 suite b 192-bit" sitting under a network's name where a person is
    // trying to pick one. The members are the stable thing to ask about, and the
    // words are then this shell's own vocabulary: "enterprise" for every EAP
    // flavour, because that is the word that says what is about to be asked of
    // you, and no suite number, because nobody has ever chosen a network on one.
    //
    // The `undefined` guard is the first line for the reason `secured` explains:
    // a member a given Quickshell build does not carry compares as undefined,
    // and so does the security of a network that is not there, so a switch below
    // must never be reached holding it.
    //
    // Anything a future Quickshell adds falls through to its own string rather
    // than to silence, which is wrong-sounding but visible, and visible is what
    // gets it fixed.
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

    // What a row says about itself, in the order it becomes true.
    //
    // THE SECURITY WORD IS NOT IN HERE ANY MORE. Every row that was not doing
    // something read "wpa2", or "wpa2, saved", so the column under eight names
    // was the same acronym eight times: nobody picks a network by its cipher,
    // and the only question the word was answering, "will this ask me for a
    // password", is answered better by the lock the row now wears. The word
    // itself is still one hover away on that mark, and still written out in full
    // in the row's own layer.
    //
    // What is left is only ever the states that differ from each other, and an
    // ordinary network in range says nothing at all, which is correct: there is
    // nothing to say about it that its name and its meter have not said.
    //
    // AND AN ENTERPRISE NETWORK IS AN ORDINARY NETWORK HERE. Every one of them
    // used to read "needs a profile", which was not a state at all: it was this
    // shell's refusal written into the column where a network describes itself,
    // and it sat there permanently with nowhere to go from it. The refusal is
    // gone, so the sentence goes with it and nothing replaces it. In range and
    // doing nothing is in range and doing nothing, whatever the network will ask
    // for when it is pressed. That it wants an identity is a fact ABOUT the
    // network rather than a state it is in, and the row carries facts like that
    // as a mark, next to the lock, where the security word already lives.
    //
    // What does belong here is the enrolment while it is happening and the
    // sentence it leaves behind if it does not work, which are states in exactly
    // the way "connecting" and "wrong password" are, and which sit in the same
    // place in the order: after the real connection states, because a network
    // that has since connected has answered every question an old failure was
    // asking.
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

    // ---- SIGNING IN TO AN ENTERPRISE NETWORK -------------------------------
    //
    // The one place this shell drives NetworkManager through a command line
    // instead of an API, for the reason set out above `enterprise`: the thing
    // being made is a settings profile and there is nothing in Quickshell that
    // makes one.
    //
    // THE SHAPE IS `~/bin/wifi`'s, because that script has been getting this
    // machine onto eduroam and campus networks for years and its answers are the
    // tested ones. Ask what is already saved, amend that profile if there is
    // one and create it if there is not, then bring it up. The amend branch
    // matters more than it looks: a profile left behind by a password that has
    // since been rotated is the single most common reason an enterprise network
    // stops working, and `add` beside an existing profile of the same name
    // leaves TWO of them, with NetworkManager free to keep picking the stale
    // one. Deleting and recreating would work as well and would throw away
    // whatever else has been set on that profile by hand.
    //
    // THE CREDENTIALS GO THROUGH ARGV, and for the moment nmcli is running they
    // are visible to anyone else with a shell on this box who runs `ps`. That is
    // a deliberate trade and `~/bin/wifi` records the same one: putting them in
    // the profile is precisely what makes the network rejoin itself after a
    // reboot instead of asking again every morning, and at rest NetworkManager
    // keeps the file root-owned and mode 600. It is also not a cost nmcli is
    // adding. The D-Bus route to the same profile is an AddConnection call, and
    // driving that from here means handing the identity and the password to
    // `busctl` as argv in exactly the same way; the only version of this without
    // the exposure is a native D-Bus client, which is Quickshell's job and not
    // this file's. On a single-user laptop the trade is not close.
    //
    // ONE AT A TIME. Three processes run in sequence and each hands the next its
    // argument list, so a reply from an abandoned attempt landing in the middle
    // of a live one would either point a write at the wrong profile or write a
    // sentence about a network nobody is looking at. `enrollingName` is the
    // whole of that state, and because a second attempt cannot begin while it is
    // set, "is this name still the one in flight" is the same guard `readCard`
    // makes on `sharing`, and every handler below makes it.
    property string enrollingName: ""

    // WHICH NETWORK THE SENTENCE IS ABOUT, held apart from the sentence for the
    // same reason `failedName` is held apart from `failedReason`: an attempt
    // that has finished failing is no longer in flight, `enrollingName` is empty
    // by then, and a row still has to be able to ask whether the failure was
    // its. Whoever is doing the enrolling reads `enrollTrouble` directly, since
    // there is only ever one of these and it belongs to the thing they just did.
    property string enrollFailedName: ""
    property string enrollTrouble: ""

    // What the profile is made of, held between the question and the write:
    // the write cannot know whether it is adding or amending until the question
    // comes back, and the arguments are identical either way.
    property var enrollArgs: []

    function clearEnroll(name: string): void {
        if (root.enrollFailedName === name) {
            root.enrollFailedName = "";
            root.enrollTrouble = "";
        }
    }

    // Failing is one motion: the attempt stops being in flight, and the name it
    // was for keeps the sentence. Separated out because three handlers do it and
    // an attempt that forgot to clear `enrollingName` would lock the whole thing
    // out for the rest of the session.
    function failEnroll(why: string): void {
        root.enrollFailedName = root.enrollingName;
        root.enrollTrouble = why;
        root.enrollingName = "";
    }

    // DEFAULTS THAT MATCH THE CLI'S, because they are what almost every campus
    // and office network actually wants, and a form insisting on being filled in
    // before it will do anything is a form that gets abandoned. PEAP with
    // MSCHAPv2 is what eduroam is nearly everywhere.
    //
    // Phase 2 is a PEAP and TTLS question: it names the authentication that runs
    // INSIDE the tunnel those two set up. TLS has no inside, it proves itself
    // with a client certificate, so the setting is left off entirely rather than
    // filled with something meaningless. The certificate and key that TLS then
    // does want are not asked for here yet; `~/bin/wifi` takes them, and this
    // will grow the same two fields when there is a reason to. Until it does, a
    // TLS network gets as far as the profile and NetworkManager refuses it for
    // the missing certificate, which is at least the true reason and is the
    // sentence the write below already says.
    function joinEnterprise(name: string, identity: string, password: string, eap: string, phase2: string): void {
        if (!name || root.enrollingName)
            return;
        if (!root.deviceName) {
            root.enrollFailedName = name;
            root.enrollTrouble = "there is no wireless adapter to put it on";
            return;
        }

        // A fresh attempt is the answer to everything the last one said, its own
        // sentence included: leaving the old trouble up while "signing in" is
        // showing is two states at once and the stale one reads as the live one.
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

    // IS THERE ALREADY A PROFILE BY THAT NAME. `-e no` so that a network whose
    // name contains a colon comes back whole instead of backslashed, which means
    // the name is everything after the FIRST colon and the line is not a thing
    // to split on. That is `~/bin/wifi`'s own reading of the same output, and
    // the reason it is awk there and a scan here rather than a split in either.
    //
    // Asked of nmcli rather than of `n.known`, which looks like the same
    // question and is not: `known` is about the network in front of the radio,
    // and the profile being amended is a record on disk that may well outlive
    // every AP this machine can currently hear.
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

        // SET, NOT BOUND, and assembled here rather than declared above, for the
        // reason `onSavedPathChanged` gives further down: what this command IS
        // depends on an answer that has only just arrived, and a bound argument
        // list would have had to be right before the question was asked.
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

    // THE PROFILE ITSELF, and nothing is on the air when this succeeds: it has
    // written a connection down, no more. Which is exactly why its failure gets
    // its own sentence. Nothing here has been anywhere near the person's
    // credentials yet, so a refusal at this point is NetworkManager objecting to
    // the shape of what it was handed, and telling somebody to check their
    // password over it would send them to look at the one thing that cannot be
    // the cause.
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

    // AND NOW ON THE AIR. This is the one that carries the credentials out to
    // the RADIUS server, so it is the one that can be told no.
    //
    // BOUNDED, because the alternative is a menu that says "signing in" forever.
    // An association that is never going to work does not fail fast: nmcli waits
    // ninety seconds by default, and a supplicant talking to a RADIUS server
    // that is simply not answering will use every one of them. Worse, nothing in
    // here cancels, so those ninety seconds are ninety in which `enrollingName`
    // is set and every further attempt is refused. Thirty is past the slowest
    // honest case, which is a RADIUS round trip and then DHCP.
    //
    // ONE SENTENCE FOR THE REJECTION, still, because an activation that failed
    // cannot separate a mistyped password from a wrong EAP method from an inner
    // auth the server does not run: all three come back the same way, so naming
    // them would be three things to check and an admission that the shell does
    // not know which. But the half of that argument which said the exit code is
    // what tells the rejection apart from everything else was simply wrong, and
    // this is what the real network did when it was asked.
    //
    // A REFUSED PASSWORD IS NOT AN EXIT CODE, IT IS A SECOND REQUEST FOR THE
    // PASSWORD. Point this at a live 802.1X network with credentials that are
    // wrong on purpose and NetworkManager never reports a failed activation at
    // all. RADIUS says no, NM concludes that the secrets it was handed must be
    // the wrong ones, and it ASKS FOR THEM AGAIN. There is no secret agent
    // behind a bare nmcli, so the re-request has nowhere to go and nmcli says so
    // instead, in two halves, on two different streams, at the same instant:
    //
    //     stdout: Passwords or encryption keys are required to access the
    //             wireless network 'eduroam'.
    //     stderr: Warning: password for '802-1x.identity' not given in
    //             'passwd-file' and nmcli cannot ask without '--ask' option.
    //
    // and then it holds the line open, doing nothing further, until `--wait`
    // runs out and it exits 3. Exit 3 is the timeout, and "no answer, so nothing
    // was checked" is the honest sentence for a timeout, so a version of this
    // that reads only the exit code sits through the whole wait in order to
    // finally tell somebody who mistyped their password to go and look at the
    // network instead. It is not a near miss. It is the one wrong answer of the
    // set, given to the most likely question.
    //
    // MEASURED, TWICE, on two different campus networks: the re-request lands at
    // about twenty-six seconds and the timeout at thirty. So the time this saves
    // is roughly four seconds of a thirty second wait, and the time is not the
    // point; the sentence is. What the four seconds do buy is the case where the
    // wait is longer than thirty, which is nmcli's own default of ninety and is
    // what this would fall back to if the bound above were ever loosened.
    //
    // WHICH IS WHY THIS IS THE ONE PROCESS IN THE FILE THAT READS OUTPUT AS IT
    // ARRIVES. Everywhere else a StdioCollector is right, because everywhere
    // else the whole of what was said is wanted and the process ending is no
    // worse a moment to be handed it than any other. Here the process ending is
    // precisely the thing being cut short, so a collector would be waiting for
    // exactly what it was added to avoid. A SplitParser hands the line over
    // while nmcli is still sitting there.
    //
    // BOTH STREAMS, one handler, because the two halves above are one thought
    // that nmcli happens to split, and which half arrives depends on plumbing
    // rather than on meaning: run it in a terminal and both appear, run it under
    // a process that reads only stderr and the stdout half is simply gone. Being
    // right either way costs one more parser. Matched on the parts that are not
    // about this network, since the SSID, the quoting and the capitalisation are
    // none of them promised and the shape of the sentence is the only stable
    // thing in it.
    //
    // THE EXIT CODES STAY, as the fallback for everything the output did not
    // already answer, and exit 3 now means what its sentence says: reached
    // WITHOUT the re-request, nothing answered, and sending somebody to look at
    // the network is right. The parsed path simply gets to the credential case
    // first, and more accurately than a number ever could.
    Process {
        id: up

        // WHETHER THE CREDENTIALS CAME BACK, kept on the process because it is
        // about this one invocation and nothing outside these handlers has any
        // use for it. Cleared at the top of every attempt in `joinEnterprise`,
        // so a refusal cannot be inherited by the one after it.
        //
        // THE SECOND FIRING IS REAL. `running = false` is a kill, a killed
        // process still exits, and the exit measured here arrives one
        // millisecond later carrying code 1, which is not in the list below and
        // would land on "could not sign in" and paint that over the sentence
        // that was right. The same goes for the other half of the re-request,
        // which lands on the other stream in the same millisecond and would
        // otherwise be read as a second refusal and delete the profile twice.
        //
        // BOTH OF THOSE ARE ALREADY CAUGHT by the older `enrollingName` test, as
        // it happens, because failing clears that name and both handlers refuse
        // to act without it. The flag stays anyway, and not out of caution: the
        // older test only works because `failEnroll` happens to be called BEFORE
        // `running = false` a few lines down, which is a fact about the order of
        // two statements rather than anything anyone would think to preserve.
        // This one says what it means.
        property bool refused: false

        function refuse(line: string): void {
            if (up.refused || !root.enrollingName)
                return;
            if (!/passwords or encryption keys|required to access the wireless network|not given in .passwd-file|cannot ask without/i.test(line))
                return;

            // Read before failing, because failing clears `enrollingName` and
            // the tidy-up below still needs to know which profile it is about.
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

    // THE PROFILE WE MADE AND COULD NOT GET ONTO. A refused sign-in leaves a
    // saved connection behind holding credentials that are now known not to
    // work, and leaving it there is worse than untidy: NetworkManager keeps
    // autoconnecting to it and keeps failing, and the row in the menu grows the
    // mark that says this network is saved, about a network nobody has ever been
    // on. The mark is a claim, and it would be a false one.
    //
    // ONLY WHEN THIS ATTEMPT IS THE ONE THAT MADE IT. `profile.exists` recorded
    // which branch the write took, and it is still this attempt's answer at the
    // moment the refusal arrives: it is set once per attempt, a second attempt
    // cannot begin while `enrollingName` is set, and this reads it before
    // `failEnroll` releases that lock. If the write amended a profile that was
    // already there, that profile is the person's rather than this shell's. It
    // may be carrying a certificate, an anonymous identity, a static address,
    // anything put on it by hand years ago, and destroying all of it because one
    // password was typed wrong takes away enormously more than was asked for.
    // `~/bin/wifi` deletes a stale profile it could not connect with and is
    // right to, and this is the same instinct with the line drawn where it
    // belongs: at what this shell itself created.
    //
    // Nothing reads the result. There is no second thing to tell somebody if the
    // tidy-up fails, and the sentence they are already reading is the true one.
    Process {
        id: discard
    }

    // A WI-FI CARD, which is what the square of dots on the back of a router is.
    //
    // The format is not a URL and not JSON: it is `WIFI:` and then `KEY:value;`
    // repeated, ending in a second semicolon, with `\` escaping any of `\;,:"`
    // that appear inside a value. A password with a semicolon in it is
    // completely ordinary and a split on `;` mangles it, which is why this is a
    // scanner rather than three regexes. Unknown keys are skipped rather than
    // rejected: the format has grown fields (a transition-disable flag, an
    // anonymous identity) and a card with one in it is still a card.
    //
    // Returns null for anything that is not one, which is most of what a camera
    // pointed at the world will find.
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
                // The terminating `;;` and any stray one: an empty key is not a
                // field, it is the end of the last one.
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

    // JOIN WHAT THE CARD NAMES, and say why not when it cannot.
    //
    // Everything this refuses, it refuses for the reason in the header of
    // NetworkMenu: joining a network the radio cannot currently hear means
    // handing NetworkManager a settings profile, and Quickshell exposes no way
    // to build one. A card for the cafe you are standing in works; a card for
    // the cafe you are going to tomorrow, or for a hidden SSID, is a profile,
    // and the honest thing is to say so rather than to appear to do nothing.
    //
    // THE ENTERPRISE REFUSAL IS NOW ABOUT THE CARD, not about the shell.
    // `joinEnterprise` can build that profile, but the format has no field to
    // put an identity in: a Wi-Fi card carries a passphrase, there is no sign-in
    // printed on it to read, and a code that has been scanned successfully
    // cannot be answered by asking for two more things. So the code is refused
    // and the row, which can ask, is where enrolling happens.
    //
    // Returns "" when it acted, and the sentence to show when it did not.
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
        // A card for an open network carries no password, and a card for a
        // secured one that somehow carries none is still better spent asking
        // NetworkManager to try than refused here: it already knows the secret
        // if the network is saved.
        if (root.secured(n) && card.password)
            n.connectWithPsk(card.password);
        else
            n.connect();
        return "";
    }

    // THE SAME CARD, FACING OUT.
    //
    // A wifi password is the worst string anybody is ever asked to read ALOUD,
    // for every reason it is the worst one to retype, plus one more: the person
    // typing it cannot see it. The square of dots carries it exactly, and a
    // screen is a perfectly good thing to hold up.
    //
    // NOTHING HERE IS HELD UNLESS THE CARD IS ON SCREEN. The card is the
    // passphrase in machine-readable form, so building one means having the
    // passphrase, and a shell has no business keeping a secret it was not asked
    // for. `sharing` is set by whoever is showing the card and cleared when it
    // goes away; the secret is fetched then and dropped after, and it does not
    // survive the layer rolling back up, a change of network, or the menu being
    // walked away from.
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

    // WHERE THE SECRET LIVES, which is two questions away from the network.
    //
    // NetworkManager splits a connection in two: the ACTIVE one, which is what
    // is running, and the SAVED one, which is what is stored, and the passphrase
    // is only ever on the second. Quickshell's network object is neither, so
    // this walks the bus for it: the list of active connections, then the type
    // and saved path of each, then the secrets of whichever one is wifi.
    //
    // It READS, which is the whole reason it is allowed. This is the same
    // exception `checkUri` above makes: a property NetworkManager exposes and
    // Quickshell does not, asked for directly. The wall at the top of
    // NetworkMenu is about CONSTRUCTING settings profiles through a command
    // line when there is an API for it; there is no API for this at all, and
    // nothing here changes anything.
    property var candidates: []
    property string savedPath: ""

    function readCard(): void {
        root.dropCard();
        // An open network's card carries no password, so there is nothing to
        // go and get and no reason to touch the bus.
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

        // EVERY ANSWER IS CHECKED AGAINST THE CARD STILL BEING UP, here and in
        // both handlers below. A reply is asynchronous and dropping the card
        // does not un-ask the question, so the last word on a network you have
        // stopped showing arrives after the shell has finished forgetting it.
        // Unguarded, that is a stale sentence on the next card at best and the
        // previous network's passphrase reinstalled after `dropCard` at worst.
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

    // ONE PROBE PER CANDIDATE, ALL AT ONCE, rather than a walk that has to
    // remember where it was. There are three or four active connections on any
    // machine, the question asked of each is the same two properties, and the
    // wifi one answers by writing down where its saved connection is. A queue
    // and an index would be more code and one more thing to get wrong when the
    // list changes underneath it.
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
                        // One JSON object per line, per property, in the order
                        // they were asked for.
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

    // SET, NOT BOUND, like every other command in this shell that runs more than
    // once: a bound argument list updates the moment the path does, which is not
    // reliably after the handler that stopped the process still reading the old
    // one.
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
                    // a{sa{sv}}: one setting group per key, and the passphrase
                    // is the one variant inside the security group.
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

    // ESCAPED, because a passphrase containing a semicolon is completely
    // ordinary and an unescaped one ends the field early: the phone would join
    // with half a password and blame itself. The inverse of the unescaping
    // `parseQr` does, over the same five characters.
    function escapeQr(s: string): string {
        return s.replace(/([\\;,:"])/g, "\\$1");
    }

    // WHAT THE `T:` FIELD SAYS. The card format's vocabulary is narrower than
    // NetworkManager's: anything that wants a passphrase is WPA, WEP is WEP, and
    // anything that joins without one is nopass. Read off the same label the row
    // shows, rather than a second table that could drift out of step with it.
    function cardSecurity(n: var): string {
        if (!root.secured(n))
            return "nopass";
        return root.securityLabel(n).indexOf("wep") >= 0 ? "WEP" : "WPA";
    }

    // The card itself, in the format on the back of every router. Empty until
    // there is something honest to put in it, which for a secured network means
    // until the secret has actually arrived.
    readonly property string card: {
        if (!root.activeName || root.enterprise(root.active))
            return "";
        const kind = root.cardSecurity(root.active);
        const head = `WIFI:T:${kind};S:${root.escapeQr(root.activeName)};`;
        if (kind === "nopass")
            return `${head};`;
        return root.secret ? `${head}P:${root.escapeQr(root.secret)};;` : "";
    }

    // WHY THERE IS NO CARD, when there is none. An enterprise network is the one
    // case that is not a failure and never resolves: its credentials are a
    // profile, and the format has no field for one.
    readonly property string cardTrouble: !root.connected ? "join a network first" : root.enterprise(root.active) ? `${root.activeName} signs in with a profile, and a card cannot carry one` : root.secretTrouble

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

                // Succeeding is the only real answer to having failed, and that
                // holds for a sign-in exactly as it holds for a passphrase: a
                // network that is carrying traffic is not still telling anybody
                // their username was wrong.
                function onConnectedChanged(): void {
                    if (watcher.modelData.connected) {
                        root.clearFailure(watcher.modelData.name);
                        root.clearEnroll(watcher.modelData.name);
                    }
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
    // THE WIRE LEADS, for the same reason it wins `carrier`: it is the link the
    // traffic is on, and a radio glyph over a cabled machine describes the one
    // part of the network that is idle.
    function icon(): string {
        if (root.carrier === "wired")
            return "lan";
        // A port and no radio, which is most desktops. The only honest thing
        // left to draw is the wire, dark: the bar dims a gauge that is not
        // `active`, and the line above has already ruled out this one being it.
        // "wifi_off" here would report the state of a device the machine does
        // not have.
        if (!root.available)
            return root.wiredAvailable ? "lan" : "wifi_off";
        return root.wifiIcon();
    }

    // THE RADIO'S OWN GLYPH, which is not the same picture as the bar's any
    // more. The bar draws whatever is carrying; the Wi-Fi row of the menu draws
    // the Wi-Fi, and it has to go on saying "off" while the wire beside it says
    // "connected". Kept as a function rather than inlined into the menu so the
    // enumeration of wireless states lives next to the properties it reads.
    function wifiIcon(): string {
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

    // THE SCANNER, and why nothing hovers it on and off any more.
    //
    // This used to run while a menu was looking at the list and stop when it
    // was not, which is the obvious arrangement and costs more than anything
    // else in this shell. Writing `scannerEnabled` is a SYNCHRONOUS trip to
    // NetworkManager that waits on the radio: measured in place, at the moment
    // the wifi menu opened and again when it closed, it blocked the GUI thread
    // for 1622ms, 1507ms, 1643ms and 1552ms. Four freezes of a second and a
    // half for one pass along the gauge column. It is the whole of why hovering
    // the bar felt broken, and it is why the panel's own `settle` debounce
    // helped and could not fix it: a debounce moves a stall, and this one was
    // simply too big to have anywhere to move to.
    //
    // AND IT IS NOT A REFRESH. With the scanner off, NetworkManager reports one
    // network, the one you are connected to. The list this menu exists to show
    // does not exist unless this is on. So it cannot be dropped, only decided
    // once instead of forty times a minute.
    //
    // So it is a REMEMBERED PREFERENCE, exactly like the connectivity check
    // above and for a related reason: it is a NetworkManager-wide state rather
    // than something this shell owns, the choice is the user's, and applying it
    // costs enough that it must be applied once. `wantScanning` is what config
    // asks for; `scanning` is what NetworkManager is actually doing, which is
    // what the switch in the menu shows.
    readonly property bool wantScanning: Config.values.network.keepListFresh

    // DEFERRED, and not merely because `wifiDevice` arrives late (it does, and
    // `onWifiDeviceChanged` covers that). The second and a half has to land
    // somewhere, and a moment after launch is the only place in the whole
    // session where nothing is on screen for it to interrupt.
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

    // Asked for by the switch in the menu, and paid for by whoever flipped it:
    // this is the one moment the pause is honest, because it is the answer to
    // something somebody just did.
    function setScanning(on: bool): void {
        Config.set("network.keepListFresh", on);
    }
}
