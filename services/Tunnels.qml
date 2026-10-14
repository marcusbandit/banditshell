pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.components
import "nmcli.js" as Nmcli
import "tunnels.js" as TunnelLogic

Singleton {
    id: root

    property var profiles: []
    property var wanted: ({})
    property var troubles: ({})
    property var queue: []

    property string importTrouble: ""
    property bool importing: false

    readonly property var list: TunnelLogic.merge(root.profiles, root.wanted, root.troubles)
    readonly property bool anyOn: root.list.some(t => t.on)
    readonly property string activeName: root.list.find(t => t.on)?.name ?? ""

    signal imported(string name)

    function refresh(): void {
        listing.running = true;
    }

    function set(tunnel: var, on: bool): void {
        if (!tunnel || root.wanted[tunnel.uuid] !== undefined || tunnel.on === on)
            return;
        root.wanted = Object.assign({}, root.wanted, {
            [tunnel.uuid]: on
        });
        root.queue = root.queue.concat([tunnel]);
        root.next();
    }

    function setFirst(on: bool): void {
        if (on)
            return root.set(root.list[0], true);
        for (const tunnel of root.list.filter(t => t.on))
            root.set(tunnel, false);
    }

    function next(): void {
        if (switching.busy || !root.queue.length)
            return;
        const tunnel = root.queue[0];
        switching.tunnel = tunnel;
        switching.run([TunnelLogic.switchCommand(tunnel, root.wanted[tunnel.uuid])]);
    }

    function settleSwitch(ok: bool, error: string): void {
        const tunnel = switching.tunnel;
        const on = root.wanted[tunnel.uuid];
        const troubles = Object.assign({}, root.troubles);
        if (ok)
            delete troubles[tunnel.uuid];
        else
            troubles[tunnel.uuid] = TunnelLogic.explainSwitch(error, on);
        root.troubles = troubles;

        const wanted = Object.assign({}, root.wanted);
        delete wanted[tunnel.uuid];
        root.wanted = wanted;
        root.queue = root.queue.slice(1);

        root.profiles = root.profiles.map(p => p.uuid === tunnel.uuid && ok ? Object.assign({}, p, {
            on: on
        }) : p);
        root.refresh();
        root.next();
    }

    function importFile(path: string): void {
        const file = TunnelLogic.resolvePath(path, Quickshell.env("HOME"));
        root.importTrouble = TunnelLogic.importProblem(file);
        if (root.importTrouble || importer.busy)
            return;
        importer.kind = TunnelLogic.importKind(file);
        root.importing = true;
        importer.run([TunnelLogic.importCommand(file)]);
    }

    Component.onCompleted: root.refresh()

    Connections {
        target: NetworkEvents

        function onChanged(): void {
            if (!switching.busy)
                root.refresh();
        }
    }

    CommandQueue {
        id: switching

        property var tunnel: null

        onFinished: (ok, output, error) => root.settleSwitch(ok, error)
    }

    CommandQueue {
        id: importer

        property string kind: ""

        onFinished: (ok, output, error) => {
            root.importing = false;
            if (ok) {
                root.importTrouble = "";
                root.imported(TunnelLogic.importedName(output));
                root.refresh();
            } else {
                root.importTrouble = TunnelLogic.explainImport(error, importer.kind);
            }
        }
    }

    Process {
        id: listing

        command: ["nmcli", "-t", "-e", "no", "-f", "NAME,UUID,TYPE,ACTIVE", "connection", "show"]

        stdout: StdioCollector {
            onStreamFinished: {
                const found = TunnelLogic.tunnelsFrom(Nmcli.connections(text));
                if (JSON.stringify(found) !== JSON.stringify(root.profiles))
                    root.profiles = found;
            }
        }
    }
}
