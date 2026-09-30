pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth as Bluez

Singleton {
    id: root

    readonly property var adapter: Bluez.Bluetooth.defaultAdapter ?? null

    readonly property bool available: !!adapter
    readonly property bool enabled: !!adapter?.enabled
    readonly property bool discovering: !!adapter?.discovering

    readonly property bool discoverable: !!adapter?.discoverable
    readonly property bool pairable: !!adapter?.pairable
    readonly property string adapterName: adapter?.name ?? ""
    readonly property string adapterId: adapter?.adapterId ?? ""

    readonly property var connectedDevices: root.devices.filter(d => d.connected)
    readonly property bool anyConnected: connectedDevices.length > 0

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

    readonly property var known: root.devices.filter(d => d.paired || d.bonded)
    readonly property var strangers: root.devices.filter(d => !d.paired && !d.bonded)

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

        if (device.paired || device.bonded)
            return "paired";
        return "not paired";
    }

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

    function kindOf(device: var): int {
        const name = (device?.icon ?? "").toLowerCase();
        return root.kinds.findIndex(k => k.match.some(m => name.includes(m)));
    }

    function icon(device: var): string {
        const i = root.kindOf(device);
        return i < 0 ? "bluetooth" : root.kinds[i].icon;
    }

    function canWake(device: var): bool {
        const i = root.kindOf(device);
        return i >= 0 && !!root.kinds[i].wakes;
    }

    function statusIcon(): string {
        if (!root.available || !root.enabled)
            return "bluetooth_disabled";

        const best = root.connectedDevices.reduce((a, d) => {
            const i = root.kindOf(d);

            return i >= 0 && i < a ? i : a;
        }, root.kinds.length);

        if (best < root.kinds.length)
            return root.kinds[best].icon;
        return root.anyConnected ? "bluetooth_connected" : "bluetooth";
    }
}
