pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.components
import "hotspot.js" as HotspotLogic
import "nmcli.js" as Nmcli

Singleton {
    id: root

    readonly property string deviceName: Network.deviceName

    property bool profileExists: false
    property bool active: false
    property bool starting: false
    property bool stopping: false
    property string failure: ""
    property int clients: 0

    property string ssid: "banditshell"
    property string password: ""
    property string band: "2.4 GHz"

    property bool capabilitiesKnown: false
    property bool accessPoint: false
    property bool fiveGigahertz: false

    readonly property bool on: (root.active || root.starting) && !root.stopping
    readonly property bool working: root.starting || root.stopping || commands.busy

    readonly property string passwordTrouble: HotspotLogic.passwordProblem(root.password)

    readonly property string blocker: HotspotLogic.blocker({
        hasDevice: !!root.deviceName,
        capabilitiesKnown: root.capabilitiesKnown,
        accessPoint: root.accessPoint,
        fiveGigahertz: root.fiveGigahertz,
        radioOn: Network.enabled,
        band: root.band,
        ssid: root.ssid,
        password: root.password,
        profileExists: root.profileExists
    })

    readonly property string status: {
        if (root.starting)
            return "starting";
        if (root.stopping)
            return "stopping";
        if (root.active)
            return `on · ${HotspotLogic.clientsLabel(root.clients)}`;
        if (root.failure)
            return root.failure;
        return root.blocker;
    }

    function setOn(wanted: bool): void {
        if (wanted === root.on || root.working)
            return;
        if (wanted)
            root.start();
        else
            root.stop();
    }

    function details(): var {
        return {
            device: root.deviceName,
            ssid: root.ssid,
            password: root.password,
            band: root.band
        };
    }

    function start(): void {
        if (root.blocker)
            return;
        root.failure = "";
        root.starting = true;
        commands.run(HotspotLogic.startCommands(root.details(), root.profileExists));
    }

    function stop(): void {
        root.stopping = true;
        commands.run(HotspotLogic.stopCommands());
    }

    function setName(name: string): void {
        root.ssid = name;
        root.edited();
    }

    function setPassword(text: string): void {
        root.password = text;
        root.edited();
    }

    function setBand(label: string): void {
        root.band = label;
        root.edited();
    }

    function edited(): void {
        root.failure = "";
        if (root.profileExists)
            apply.restart();
    }

    function refresh(): void {
        listing.running = true;
    }

    function measure(): void {
        if (!root.active || !root.deviceName)
            return;
        counting.command = ["sh", "-c", "if command -v iw >/dev/null 2>&1; then iw dev \"$1\" station dump; else ip neigh show dev \"$1\"; fi", "sh", root.deviceName];
        counting.running = true;
    }

    Component.onCompleted: {
        root.refresh();
        root.probe();
    }

    onDeviceNameChanged: root.probe()

    function probe(): void {
        root.capabilitiesKnown = false;
        if (!root.deviceName)
            return;
        capabilities.command = ["nmcli", "-t", "-f", "WIFI-PROPERTIES.AP,WIFI-PROPERTIES.5GHZ", "device", "show", root.deviceName];
        capabilities.running = true;
    }

    onActiveChanged: {
        root.clients = 0;
        root.measure();
    }

    Connections {
        target: NetworkEvents

        function onChanged(): void {
            if (!commands.busy)
                root.refresh();
        }
    }

    Timer {
        running: root.active
        interval: 5000
        repeat: true
        onTriggered: root.measure()
    }

    Timer {
        id: apply

        interval: 1500
        onTriggered: {
            if (commands.busy)
                return apply.restart();
            if (root.blocker)
                return;
            commands.run(root.active ? HotspotLogic.restartCommands(root.details()) : HotspotLogic.editCommands(root.details()));
        }
    }

    CommandQueue {
        id: commands

        onFinished: (ok, output, error) => {
            if (ok && root.starting)
                root.active = true;
            if (ok && root.stopping)
                root.active = false;
            if (!ok && !root.stopping)
                root.failure = HotspotLogic.explainFailure(error);
            root.starting = false;
            root.stopping = false;
            root.refresh();
        }
    }

    Process {
        id: listing

        command: ["nmcli", "-t", "-e", "no", "-f", "NAME,UUID,TYPE,ACTIVE", "connection", "show"]

        stdout: StdioCollector {
            onStreamFinished: {
                const found = Nmcli.connections(text).find(c => c.type === "802-11-wireless" && c.name === "Hotspot");
                root.profileExists = !!found;
                if (!commands.busy)
                    root.active = !!found?.active;
                if (found)
                    reading.running = true;
            }
        }
    }

    Process {
        id: reading

        command: ["nmcli", "-s", "-t", "-e", "no", "-f", "802-11-wireless.ssid,802-11-wireless.band,802-11-wireless-security.psk", "connection", "show", "id", "Hotspot"]

        stdout: StdioCollector {
            onStreamFinished: {
                if (apply.running || commands.busy)
                    return;
                const saved = HotspotLogic.readProfile(Nmcli.fields(text));
                if (saved.ssid)
                    root.ssid = saved.ssid;
                root.band = saved.band;
                if (saved.password)
                    root.password = saved.password;
            }
        }
    }

    Process {
        id: capabilities

        stdout: StdioCollector {
            onStreamFinished: {
                const found = HotspotLogic.capabilities(text);
                root.accessPoint = found.accessPoint;
                root.fiveGigahertz = found.fiveGigahertz;
                root.capabilitiesKnown = true;
            }
        }
    }

    Process {
        id: counting

        stdout: StdioCollector {
            onStreamFinished: root.clients = HotspotLogic.countClients(text)
        }
    }
}
