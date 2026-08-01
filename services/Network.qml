pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking

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
    readonly property real activeStrength: active?.signalStrength ?? 0

    // Anything mid-connect, so the UI can say so rather than looking stuck.
    readonly property var connecting: wifiDevice?.networks?.values?.find(n => n.stateChanging && !n.connected) ?? null

    readonly property string address: wifiDevice?.address ?? ""

    // One entry per network NAME, strongest first, in reading order.
    readonly property var networks: {
        const seen = {};
        for (const n of wifiDevice?.networks?.values ?? []) {
            if (!n.name)
                continue;
            const best = seen[n.name];
            if (!best || n.signalStrength > best.signalStrength || n.connected)
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

    function scan(): void {
        if (root.wifiDevice)
            root.wifiDevice.scannerEnabled = true;
    }

    // "Needs a passphrase", which is not the same as "encrypted": the member is
    // Open, not None (comparing against a member that does not exist yields
    // undefined and every network came back secured, padlock and all), and OWE
    // is encrypted but joins without asking for anything.
    function secured(n: var): bool {
        const s = n?.security;
        return s !== undefined && s !== WifiSecurityType.Open && s !== WifiSecurityType.Owe && s !== WifiSecurityType.Unknown;
    }

    function securityLabel(n: var): string {
        if (!secured(n))
            return "open";
        return WifiSecurityType.toString(n.security).toLowerCase();
    }

    // The strength ramp, weakest first, taken from what the ICON FONT ACTUALLY
    // HAS rather than from what would be tidy.
    //
    // Material Symbols has wifi_1_bar and wifi_2_bar but no wifi_3_bar;
    // signal_wifi_0_bar but no 1 to 3; and network_wifi_1..3_bar but neither 0
    // nor 4. So no single family is a complete ramp, and the network_wifi one,
    // which looked like the obvious choice, draws an outlined wedge whose filled
    // bars are invisible at 18px: every network in the list looked identical.
    // This is assembled from two families, four steps, and legible small.
    //
    // Deriving it from the data means the count is not written down twice.
    readonly property var strengthIcons: ["signal_wifi_0_bar", "wifi_1_bar", "wifi_2_bar", "wifi"]

    function bars(strength: real): int {
        const steps = root.strengthIcons.length;
        return Math.max(0, Math.min(steps - 1, Math.floor(strength / (100 / steps))));
    }

    // One network's own strength, whatever else is going on.
    function barsIcon(strength: real): string {
        return root.strengthIcons[root.bars(strength)];
    }

    // The status bar's icon, which is about the CONNECTION rather than about any
    // one network: off, on but adrift, or connected at some strength.
    function icon(strength: real): string {
        if (!root.available || !root.enabled)
            return "wifi_off";
        if (!root.connected)
            return "signal_wifi_bad";
        return root.barsIcon(strength);
    }

    // Scanning costs power, so it runs while something is looking at the list
    // and stops when nothing is.
    function watch(on: bool): void {
        if (root.wifiDevice)
            root.wifiDevice.scannerEnabled = on;
    }
}
