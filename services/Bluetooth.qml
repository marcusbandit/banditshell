pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth as Bluez

// bluez, adapted.
//
// Named Bluetooth and importing the real module under an alias, so widgets say
// `Bluetooth.devices` and get the list they actually want rather than every
// object bluez has ever seen. Discovery turns up transient junk with no name and
// no pairing, which is noise in a menu, so unnamed strangers are filtered out
// while anything paired is always kept.
Singleton {
    id: root

    readonly property var adapter: Bluez.Bluetooth.defaultAdapter ?? null

    readonly property bool available: !!adapter
    readonly property bool enabled: !!adapter?.enabled
    readonly property bool discovering: !!adapter?.discovering

    readonly property var connectedDevices: root.devices.filter(d => d.connected)
    readonly property bool anyConnected: connectedDevices.length > 0

    // Paired first, then connected within that, then by name, so the list does
    // not reshuffle under the cursor every time a scan result arrives.
    // A device with no name reports its ADDRESS as its name, in a different
    // punctuation from the address field, so "name !== address" lets every
    // passing phone and earbud in the street into the list as a row of hex.
    // Match the shape instead.
    function anonymous(d: var): bool {
        return !d?.name || /^([0-9a-f]{2}[:-]){5}[0-9a-f]{2}$/i.test(d.name);
    }

    readonly property var devices: {
        const all = Bluez.Bluetooth.devices?.values ?? [];
        return all.filter(d => d.paired || d.bonded || !root.anonymous(d)).sort((a, b) => {
            if (a.connected !== b.connected)
                return a.connected ? -1 : 1;
            if (a.paired !== b.paired)
                return a.paired ? -1 : 1;
            return (a.name ?? "").localeCompare(b.name ?? "");
        });
    }

    function setEnabled(on: bool): void {
        if (root.adapter)
            root.adapter.enabled = on;
    }

    function setDiscovering(on: bool): void {
        if (root.adapter)
            root.adapter.discovering = on;
    }

    // One press, whatever the device currently is.
    function toggleDevice(device: var): void {
        if (!device)
            return;
        if (device.connected)
            device.disconnect();
        else if (device.paired || device.bonded)
            device.connect();
        else
            device.pair();
    }

    function stateLabel(device: var): string {
        if (!device)
            return "";
        if (device.pairing)
            return "pairing";
        if (device.connected)
            return device.batteryAvailable ? `connected, ${Math.round(device.battery * 100)}%` : "connected";
        if (device.paired || device.bonded)
            return "paired";
        return "not paired";
    }

    // bluez reports a freedesktop icon name; map the handful that matter onto
    // the icon font, and fall back to a generic rather than to nothing.
    function icon(device: var): string {
        const name = device?.icon ?? "";
        if (name.includes("headset") || name.includes("headphone"))
            return "headphones";
        if (name.includes("audio"))
            return "speaker";
        if (name.includes("mouse"))
            return "mouse";
        if (name.includes("keyboard"))
            return "keyboard";
        if (name.includes("phone"))
            return "devices";
        if (name.includes("computer"))
            return "computer";
        if (name.includes("watch"))
            return "watch";
        if (name.includes("gaming") || name.includes("joypad"))
            return "sports_esports";
        return "bluetooth";
    }

    function statusIcon(): string {
        if (!root.available || !root.enabled)
            return "bluetooth_disabled";
        if (root.anyConnected)
            return "bluetooth_connected";
        return "bluetooth";
    }
}
