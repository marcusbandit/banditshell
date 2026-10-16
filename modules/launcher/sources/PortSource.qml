import QtQuick
import Quickshell
import qs.services
import "../../../services/ranking.js" as Ranking
import "../../../services/listening-ports.js" as Logic
import "../search.js" as Search

QtObject {
    id: root

    required property var search

    readonly property var kinds: ["port"]

    readonly property var asked: ListeningPorts.enabled && ListeningPorts.found ? Logic.ask(root.search.text) ?? root.phrased(Search.portAsk(root.search.text)) : null

    function phrased(said: var): var {
        return said ? {
            port: String(said.port),
            words: "",
            udp: false,
            tcp: true,
            quit: !!said.kill,
            exact: true
        } : null;
    }
    readonly property bool intent: root.asked !== null

    onAskedChanged: {
        if (root.asked)
            ListeningPorts.want(root.asked.udp);
        else
            ListeningPorts.drop();
    }

    readonly property var caps: ({
            ports: 14
        })

    readonly property string armedFor: root.search.armed.startsWith("port") ? root.search.armed : ""

    function arming(listener: var): string {
        const armed = root.armedFor;
        const cut = armed.indexOf(":");
        return cut > 0 && armed.slice(cut + 1) === listener.key ? armed.slice(0, cut) : "";
    }

    function ownerOf(listener: var): string {
        return Logic.ownerName(listener) || `port ${listener.port}`;
    }

    function armedLabel(mode: string, listener: var): string {
        const name = root.ownerOf(listener);
        switch (mode) {
        case "portquit":
            return `Press Enter again to quit ${name}`;
        case "portkill":
            return `Press Enter again to force quit ${name}`;
        case "portstop":
            return `Press Enter again to stop ${listener.systemUnit}`;
        case "portrestart":
            return `Press Enter again to restart ${listener.systemUnit}`;
        case "portfree":
            return `Press Enter again to free port ${listener.port}`;
        }
        return "";
    }

    function row(listener: var, score: real): var {
        const mode = root.arming(listener);
        const busy = ListeningPorts.jobs[listener.key] ?? "";
        const owner = listener.owners[0]?.name ?? "";
        return {
            key: `port:${listener.key}`,
            kind: "port",
            listener: listener,
            mode: mode,
            label: mode ? root.armedLabel(mode, listener) : Logic.labelOf(listener),
            detail: mode ? "" : [Logic.detailOf(listener, ListeningPorts.uid, ListeningPorts.users), busy].filter(Boolean).join(" · "),
            iconSource: owner ? Apps.iconSourceFor([owner]) : "",
            icon: listener.protocol === "udp" ? "podcasts" : "lan",
            score: score
        };
    }

    function note(key: string, label: string, detail: string, icon: string): var {
        return {
            key: `port:${key}`,
            kind: "port",
            waiting: true,
            label: label,
            detail: detail,
            icon: icon,
            score: Infinity
        };
    }

    readonly property var rows: {
        const asked = root.asked;
        if (!asked)
            return [];
        const found = Logic.matching(ListeningPorts.listeners, asked, Ranking.place);
        if (found.length)
            return found.map((listener, i) => root.row(listener, i === 0 ? Infinity : 100 - i * 0.01));
        if (!ListeningPorts.read)
            return [root.note("reading", "Reading listening ports", "", "hourglass_top")];
        if (asked.port)
            return [root.note(`none:${asked.port}`, `Nothing listens on port ${asked.port}`, asked.udp && !asked.tcp ? "UDP" : asked.udp ? "TCP and UDP" : "TCP", "block")];
        if (asked.words)
            return [root.note(`none:${asked.words}`, `No listening port belongs to ${asked.words}`, "", "block")];
        return [];
    }

    readonly property var groups: [
        {
            key: "ports",
            title: "Listening ports",
            items: root.rows
        }
    ]

    function arm(mode: string, listener: var): void {
        root.search.armed = `${mode}:${listener.key}`;
    }

    function fire(mode: string, listener: var): void {
        root.search.armed = "";
        switch (mode) {
        case "portquit":
            ListeningPorts.quit(listener, false);
            return;
        case "portkill":
            ListeningPorts.quit(listener, true);
            return;
        case "portfree":
            ListeningPorts.quitAsAdministrator(listener, false);
            return;
        case "portstop":
        case "portrestart":
            SystemdUnits.control(SystemdUnits.systemUnit(listener.systemUnit), mode === "portstop" ? "stop" : "restart", () => ListeningPorts.relist());
            return;
        }
    }

    function activate(row: var): void {
        const first = root.actionsFor(row)[0];
        if (first)
            first.run();
    }

    function openActions(listener: var): var {
        const url = Logic.browsable(listener);
        const where = url.replace(/^http:\/\//, "");
        return (url ? [
                {
                    icon: "open_in_browser",
                    label: `Open ${where} in the browser`,
                    short: "Open",
                    run: () => root.search.launch(() => Quickshell.execDetached(["xdg-open", url]))
                }
            ] : []).concat([
            {
                icon: "content_copy",
                label: "Copy address",
                short: "Copy",
                tucked: true,
                run: () => root.search.leave(() => Clipboard.copy({
                            text: where || `${listener.addresses[0]}:${listener.port}`
                        }))
            }
        ]);
    }

    function actionsFor(row: var): var {
        if (row.waiting)
            return [];
        const listener = row.listener;
        if (row.mode)
            return [
                {
                    icon: "dangerous",
                    label: root.armedLabel(row.mode, listener).replace(/^Press Enter again to /, "").replace(/^./, c => c.toUpperCase()),
                    short: row.mode === "portkill" ? "Force quit" : row.mode === "portstop" ? "Stop" : row.mode === "portrestart" ? "Restart" : "Quit",
                    alarm: true,
                    button: true,
                    run: () => root.fire(row.mode, listener)
                },
                {
                    icon: "close",
                    label: "Cancel",
                    run: () => root.search.armed = ""
                }
            ];
        if (ListeningPorts.jobs[listener.key])
            return [
                {
                    icon: "hourglass_top",
                    label: "Quitting",
                    run: () => {}
                }
            ].concat(root.openActions(listener));
        const name = root.ownerOf(listener);
        if (listener.owners.length)
            return [
                {
                    icon: "close",
                    label: `Quit ${name}`,
                    short: "Quit",
                    run: () => root.arm("portquit", listener)
                },
                {
                    icon: "dangerous",
                    label: `Force quit ${name}`,
                    short: "Force quit",
                    tucked: true,
                    run: () => root.arm("portkill", listener)
                }
            ].concat(root.openActions(listener));
        if (listener.systemUnit && SystemdUnits.enabled)
            return [
                {
                    icon: "stop_circle",
                    label: `Stop ${listener.systemUnit}`,
                    short: "Stop",
                    run: () => root.arm("portstop", listener)
                },
                {
                    icon: "restart_alt",
                    label: `Restart ${listener.systemUnit}`,
                    short: "Restart",
                    run: () => root.arm("portrestart", listener)
                }
            ].concat(root.openActions(listener));
        if (ListeningPorts.fuserFound)
            return [
                {
                    icon: "admin_panel_settings",
                    label: `Free port ${listener.port} as administrator`,
                    short: "Free port",
                    run: () => root.arm("portfree", listener)
                }
            ].concat(root.openActions(listener));
        return root.openActions(listener);
    }

    function complete(row: var): bool {
        if (row.waiting)
            return false;
        root.search.retype(`port ${row.listener.port}`);
        return true;
    }
}
