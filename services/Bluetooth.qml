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

    // One device by its address, for whoever holds an address and not a device.
    // PipeWire's bluetooth nodes carry `api.bluez5.address` and nothing else
    // about what the thing IS, so this is how the sound menu finds out that the
    // sink it is drawing is a pair of headphones.
    function deviceAt(address: string): var {
        if (!address)
            return null;
        const wanted = address.toUpperCase();
        return root.devices.find(d => (d.address ?? "").toUpperCase() === wanted) ?? null;
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
    //
    // ORDERED, and the order is the answer to "which one does the bar mean"
    // when several things are connected. Not a second list to keep in step with
    // the first: the kinds ARE the ranking, most-worth-showing first, and the
    // matcher walks them in order. Audio wins because it is the connection you
    // notice going wrong; a mouse you can see moving.
    readonly property var kinds: [
        {
            icon: "headphones",
            match: ["headset", "headphone"]
        },
        {
            icon: "speaker",
            match: ["audio", "speaker"]
        },
        {
            icon: "sports_esports",
            match: ["gaming", "joypad"]
        },
        {
            icon: "keyboard",
            match: ["keyboard"]
        },
        {
            icon: "mouse",
            match: ["mouse", "pointing"]
        },
        {
            icon: "watch",
            match: ["watch"]
        },
        {
            icon: "devices",
            match: ["phone"]
        },
        {
            icon: "computer",
            match: ["computer"]
        }
    ]

    // Which entry of `kinds` a device is, as an index, so both the icon for one
    // device and the pick between several come from the same walk.
    function kindOf(device: var): int {
        const name = (device?.icon ?? "").toLowerCase();
        return root.kinds.findIndex(k => k.match.some(m => name.includes(m)));
    }

    function icon(device: var): string {
        const i = root.kindOf(device);
        return i < 0 ? "bluetooth" : root.kinds[i].icon;
    }

    // The bar's mark: WHAT is connected, not merely that bluetooth exists.
    //
    // A generic radio glyph answers a question nobody has. "Are my headphones
    // on", "is the controller awake", "did the mouse drop again" are the actual
    // questions, and the device's own kind answers all three at a glance. With
    // several connected it shows the highest-ranked kind rather than whatever
    // bluez happened to sort first, so the bar does not change its mind about
    // what it means every time a device reconnects.
    function statusIcon(): string {
        if (!root.available || !root.enabled)
            return "bluetooth_disabled";

        const best = root.connectedDevices.reduce((a, d) => {
            const i = root.kindOf(d);
            // An unrecognised device still counts as connected; it just loses
            // to anything the icon font can actually name.
            return i >= 0 && i < a ? i : a;
        }, root.kinds.length);

        if (best < root.kinds.length)
            return root.kinds[best].icon;
        return root.anyConnected ? "bluetooth_connected" : "bluetooth";
    }
}
