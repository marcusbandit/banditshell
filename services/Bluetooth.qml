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

    // The rest of the adapter. Bluez lets you be findable and lets you accept
    // pairing separately, and they are not the same question: the first is
    // whether anyone can see this machine, the second is whether it will say yes
    // when they ask. Both are off by default and both are worth a control,
    // because being permanently visible is the bluetooth equivalent of leaving
    // your door open.
    readonly property bool discoverable: !!adapter?.discoverable
    readonly property bool pairable: !!adapter?.pairable
    readonly property string adapterName: adapter?.name ?? ""
    readonly property string adapterId: adapter?.adapterId ?? ""

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

    function order(a: var, b: var): int {
        if (a.connected !== b.connected)
            return a.connected ? -1 : 1;
        if (a.paired !== b.paired)
            return a.paired ? -1 : 1;
        return (a.name ?? "").localeCompare(b.name ?? "");
    }

    readonly property var devices: {
        const all = Bluez.Bluetooth.devices?.values ?? [];
        return all.filter(d => d.paired || d.bonded || !root.anonymous(d)).sort(root.order);
    }

    // YOURS, and everything else.
    //
    // A bluetooth list is two lists wearing one coat. `known` is the handful of
    // things you own and reach for; `strangers` is whatever is broadcasting in
    // the building, which on a street is dozens of televisions, doorbells and
    // other people's earbuds. Showing them together buries the four rows that
    // matter in a list that changes every few seconds, so they are separated
    // here and the menu only asks for the second one when you say you are
    // pairing something.
    readonly property var known: root.devices.filter(d => d.paired || d.bonded)
    readonly property var strangers: root.devices.filter(d => !d.paired && !d.bonded)

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

    function setDiscoverable(on: bool): void {
        if (root.adapter)
            root.adapter.discoverable = on;
    }

    function setPairable(on: bool): void {
        if (root.adapter)
            root.adapter.pairable = on;
    }

    // Per device, and all of them writable through bluez.
    //
    // TRUSTED is the one worth understanding: an untrusted device has to be
    // authorised every time it asks to connect, so headphones that reconnect on
    // their own are headphones bluez trusts. BLOCKED is the opposite and
    // stronger than forgetting, since a forgotten device can simply pair again.
    // WAKE is whether this machine may be woken by it, which is what a keyboard
    // is for and what nothing else should have.
    function setTrusted(device: var, on: bool): void {
        if (device)
            device.trusted = on;
    }

    function setBlocked(device: var, on: bool): void {
        if (device)
            device.blocked = on;
    }

    function setWakeAllowed(device: var, on: bool): void {
        if (device)
            device.wakeAllowed = on;
    }

    // The alias bluez keeps for a device, not the name the device advertises.
    // Two identical earbuds arrive with identical names and this is the only way
    // to tell them apart afterwards.
    function rename(device: var, name: string): void {
        if (device && name)
            device.name = name;
    }

    function forget(device: var): void {
        if (device)
            device.forget();
    }

    function cancelPair(device: var): void {
        if (device)
            device.cancelPair();
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

    // Is it mid-something? Connecting and disconnecting are states bluez passes
    // through and a row that says nothing during them looks like a row that
    // ignored the tap.
    function busy(device: var): bool {
        return !!device?.pairing || device?.state === Bluez.BluetoothDeviceState.Connecting || device?.state === Bluez.BluetoothDeviceState.Disconnecting;
    }

    function stateLabel(device: var): string {
        if (!device)
            return "";
        if (device.blocked)
            return "blocked";
        if (device.pairing)
            return "pairing";
        if (device.state === Bluez.BluetoothDeviceState.Connecting)
            return "connecting";
        if (device.state === Bluez.BluetoothDeviceState.Disconnecting)
            return "disconnecting";
        if (device.connected)
            return device.batteryAvailable ? `connected · ${Math.round(device.battery * 100)}%` : "connected";
        // Not "paired, and trusted, and allowed to wake you": the row says what
        // it is, the layer says what it may do. A detail line that elides is a
        // detail line that says nothing.
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
            match: ["gaming", "joypad"],
            wakes: true
        },
        {
            icon: "keyboard",
            match: ["keyboard"],
            wakes: true
        },
        {
            icon: "mouse",
            match: ["mouse", "pointing"],
            wakes: true
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

    // Can this thing wake the machine at all?
    //
    // Bluez only publishes WakeAllowed for devices that support it. On this
    // machine exactly one of nine has it, the keyboard, and the property is
    // absent from the D-Bus interface of the other eight; Quickshell reports an
    // absent property as false, which is indistinguishable from "supported, and
    // switched off". So the question is answered by KIND, off the same list that
    // draws the icons: waking a computer is what a keyboard, a mouse and a
    // controller are for, and no headset has ever needed to. A switch that
    // cannot move is worse than no switch, because it looks like it failed.
    function canWake(device: var): bool {
        const i = root.kindOf(device);
        return i >= 0 && !!root.kinds[i].wakes;
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
