import QtQuick
import qs.services
import "../search.js" as Search

QtObject {
    id: root

    required property var search

    readonly property var kinds: ["port"]

    readonly property var ask: Search.portAsk(root.search.text)
    readonly property int port: root.ask?.port ?? 0
    readonly property bool usable: !Ports.probed || Ports.found

    onPortChanged: Ports.want(root.port)

    readonly property bool intent: !!root.ask && root.usable

    readonly property var listeners: root.port ? Ports.listenersOn(root.port) : undefined

    function plainRow(label: string, detail: string): var {
        return {
            key: `port:${root.port}`,
            kind: "port",
            pid: 0,
            label: label,
            detail: detail,
            icon: "lan",
            score: Infinity
        };
    }

    function row(listener: var): var {
        const quitting = root.search.armed === `port:${listener.pid}:quit`;
        const forcing = root.search.armed === `port:${listener.pid}:force`;
        if (!listener.pid)
            return root.plainRow(`Port ${root.port} is in use`, listener.addresses.join(", "));
        return {
            key: `port:${root.port}:${listener.pid}`,
            kind: "port",
            pid: listener.pid,
            name: listener.name,
            armed: quitting || forcing,
            force: forcing,
            label: quitting ? `Press Enter again to quit ${listener.name}` : forcing ? `Press Enter again to force quit ${listener.name}` : listener.name,
            detail: quitting || forcing ? "" : `PID ${listener.pid} · ${listener.addresses.join(", ")}`,
            iconSource: Apps.iconSourceFor([listener.name]),
            icon: "lan",
            score: Infinity
        };
    }

    readonly property var rows: {
        if (!root.port || !root.usable)
            return [];
        const found = root.listeners;
        if (found === undefined)
            return Ports.failedOn(root.port) ? [] : [root.plainRow(`Port ${root.port}`, "checking")];
        if (!found.length)
            return [root.plainRow(`Nothing is listening on port ${root.port}`, "")];
        return found.map(listener => root.row(listener));
    }

    readonly property var groups: [
        {
            key: "ports",
            title: `Port ${root.port}`,
            items: root.rows
        }
    ]

    readonly property var phrases: [
        {
            head: "kill port ",
            picks: ["3000", "5173", "8000", "8080"]
        },
        {
            head: "what is using port ",
            picks: ["3000", "5173", "8000", "8080"]
        }
    ]

    function arm(row: var, how: string): void {
        root.search.armed = `port:${row.pid}:${how}`;
    }

    function activate(row: var): void {
        if (!row.pid)
            return;
        if (!row.armed) {
            root.arm(row, "quit");
            return;
        }
        root.search.armed = "";
        Ports.stop(row.pid, row.force);
    }

    function actionsFor(row: var): var {
        if (!row.pid)
            return [];
        return [
            {
                icon: "close",
                label: "Quit",
                button: true,
                run: () => root.arm(row, "quit")
            },
            {
                icon: "dangerous",
                label: "Force quit",
                run: () => root.arm(row, "force")
            }
        ];
    }

    function confirmActionsFor(row: var): var {
        return [
            {
                icon: row.force ? "dangerous" : "close",
                label: row.force ? "Force quit" : "Quit",
                alarm: true,
                run: () => root.activate(row)
            }
        ];
    }
}
