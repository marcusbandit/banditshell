pragma Singleton

import QtQuick
import Quickshell
import qs.config
import "moments.js" as Logic

Singleton {
    id: root

    readonly property var wanted: Config.values.island.moments

    property bool armed: false
    property var heard: []
    property string pendingAddress: ""

    readonly property var connectedAddresses: Bluetooth.connectedDevices.map(d => d.address)

    function wants(kind: string): bool {
        return Logic.momentWanted(root.wanted, kind);
    }

    function screenshot(path: string): void {
        const spec = root.wants("screenshot") ? Logic.screenshotSpec(path) : null;
        if (spec)
            Activities.push(Object.assign(spec, {
                act: (entry, action) => root.answerScreenshot(entry, action)
            }));
    }

    function answerScreenshot(entry: var, action: string): void {
        const path = entry.data.path;
        const chosen = Logic.screenshotAction(action);
        switch (chosen) {
        case "copy":
            Clipboard.copy({
                file: path
            });
            break;
        case "edit":
            Quickshell.execDetached(Logic.editorCommand(Config.values.picker.editor, path));
            break;
        case "folder":
            Files.reveal(path);
            break;
        case "delete":
            Files.trash([path]);
            Activities.remove(entry.id);
            return;
        default:
            Quickshell.execDetached(["xdg-open", path]);
        }
        Activities.end(entry.id, "done", 500, "");
    }

    function copied(command: var, input: string, secret: bool): void {
        const spec = root.wants("copied") ? Logic.copiedSpec(command, input, secret) : null;
        if (spec)
            Activities.push(spec);
    }

    function connected(address: string): void {
        const device = Bluetooth.deviceAt(address);
        if (!device || !root.wants("bluetooth"))
            return;
        const icon = Bluetooth.icon(device);
        if (!Logic.audioDevice(icon))
            return;
        const battery = Logic.batteryPercent(device.battery, device.batteryAvailable);
        Activities.push(Logic.bluetoothSpec(device.name, icon, battery));
        if (battery < 0) {
            root.pendingAddress = address;
            batteryWait.restart();
        }
    }

    function wifiFailed(name: string, kind: string, message: string): void {
        const spec = root.wants("wifi") ? Logic.wifiSpec(name, kind, message) : null;
        if (spec)
            Activities.push(Object.assign(spec, {
                act: (entry, action) => {
                    if (action === "retry")
                        root.retryWifi(entry);
                }
            }));
    }

    function offerUndo(): void {
        const hush = Notifications.hushed;
        const spec = hush ? Logic.undoSpec([hush.app], hush.entry, Logic.hushDone(hush.kind, Notifications.endsAt(hush.until, Date.now()))) : Logic.undoSpec(Notifications.shelf.map(r => r.entry.appName), Notifications.shelf[0]?.entry);
        if (!spec) {
            Activities.remove("moment:undo");
            return;
        }
        Activities.push(Object.assign(spec, {
            act: (entry, action) => {
                if (action === "undo")
                    Notifications.undo();
            }
        }));
    }

    function retryWifi(entry: var): void {
        Activities.remove(entry.id);
        WifiJoin.retry(entry.data.name, entry.data.kind);
    }

    onConnectedAddressesChanged: {
        const fresh = Logic.newlyConnected(root.heard, root.connectedAddresses);
        root.heard = root.connectedAddresses;
        if (!root.armed)
            return;
        for (const address of fresh)
            root.connected(address);
    }

    Connections {
        target: Screenshots

        function onCaptured(path: string): void {
            root.screenshot(path);
        }
    }

    Connections {
        target: Clipboard

        function onCopied(command: var, input: string, secret: bool): void {
            root.copied(command, input, secret);
        }
    }

    Connections {
        target: Network

        function onActiveNameChanged(): void {
            const failed = Activities.entries.find(e => e.id === "moment:wifi");
            if (failed && failed.data?.name === Network.activeName)
                Activities.remove(failed.id);
        }
    }

    Connections {
        target: Notifications

        function onShelvedChanged(): void {
            root.offerUndo();
        }

        function onHushedChanged(): void {
            root.offerUndo();
        }
    }

    Connections {
        target: WifiJoin

        function onFailed(name: string, kind: string, message: string): void {
            root.wifiFailed(name, kind, message);
        }
    }

    Timer {
        id: batteryWait

        interval: 900

        onTriggered: {
            const device = Bluetooth.deviceAt(root.pendingAddress);
            const battery = device ? Logic.batteryPercent(device.battery, device.batteryAvailable) : -1;
            if (battery >= 0)
                Activities.update("moment:bluetooth", {
                    data: {
                        battery: battery
                    }
                });
        }
    }

    Timer {
        interval: 4000
        running: true
        onTriggered: {
            root.heard = root.connectedAddresses;
            root.armed = true;
        }
    }
}
