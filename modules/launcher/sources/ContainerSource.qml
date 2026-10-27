import QtQuick
import Quickshell
import qs.services
import "../../../services/ranking.js" as Ranking
import "../../../services/containers.js" as Logic

QtObject {
    id: root

    required property var search

    readonly property var kinds: ["container"]

    readonly property var asked: Containers.enabled ? Logic.ask(root.search.text) : null
    readonly property bool intent: root.asked !== null

    onAskedChanged: {
        if (root.asked)
            Containers.want();
        else
            Containers.drop();
    }

    readonly property var caps: ({
            containers: 14
        })

    readonly property string armedFor: root.search.armed.startsWith("container") ? root.search.armed : ""

    function arming(container: var): string {
        const armed = root.armedFor;
        const cut = armed.indexOf(":");
        return cut > 0 && armed.slice(cut + 1) === container.id ? armed.slice(9, cut) : "";
    }

    readonly property bool both: Containers.containers.some(c => c.engine === "podman") && Containers.containers.some(c => c.engine === "docker")

    function row(container: var, score: real): var {
        const armed = root.arming(container);
        const busy = Containers.jobs[container.id] ?? "";
        return {
            key: `container:${container.engine}:${container.id}`,
            kind: "container",
            container: container,
            armedVerb: armed,
            label: armed ? `Press Enter again to ${armed} ${container.name}` : container.name,
            detail: armed ? "" : busy ? [container.image, busy].filter(Boolean).join(" · ") : Logic.detailOf(container, root.both),
            icon: Logic.running(container) ? "deployed_code" : "deployed_code_history",
            score: score
        };
    }

    function note(key: string, label: string, detail: string, icon: string, extra: var): var {
        return Object.assign({
            key: `container:${key}`,
            kind: "container",
            waiting: true,
            label: label,
            detail: detail,
            icon: icon,
            score: Infinity
        }, extra ?? {});
    }

    function problemRow(engine: string): var {
        const problem = Containers.problems[engine];
        if (!problem || problem.kind === "missing")
            return null;
        const name = engine === "docker" ? "Docker" : "Podman";
        switch (problem.kind) {
        case "denied":
            return root.note(`${engine}:denied`, `No access to ${name}`, problem.socket ? problem.socket.slice(problem.socket.lastIndexOf("/") + 1) : "permission denied", "lock");
        case "stopped":
            return root.note(`${engine}:stopped`, `${name} is not running`, "", "power_off", engine === "docker" && SystemdUnits.enabled ? {
                startDocker: true
            } : {});
        case "slow":
            return root.note(`${engine}:slow`, `${name} did not answer`, "no reply in 10 seconds", "hourglass_disabled");
        }
        return root.note(`${engine}:failed`, `${name} could not list containers`, problem.said ?? "", "error");
    }

    readonly property var rows: {
        const asked = root.asked;
        if (!asked)
            return [];
        if (!Containers.read)
            return [root.note("reading", "Reading containers", "", "hourglass_top")];
        const found = Logic.matching(Containers.containers, asked, Ranking.place);
        const out = found.map((c, i) => root.row(c, i === 0 ? Infinity : 100 - i * 0.01));
        const engines = asked.engine ? [asked.engine] : ["podman", "docker"];
        const problems = asked.words ? [] : engines.map(e => root.problemRow(e)).filter(Boolean).map((r, i) => Object.assign(r, {
                    score: out.length ? 50 - i * 0.01 : i === 0 ? Infinity : 100 - i * 0.01
                }));
        if (!out.length && !problems.length && !asked.words) {
            const missing = engines.every(e => Containers.problems[e]?.kind === "missing");
            return [missing ? root.note("none", asked.engine ? `${asked.engine === "docker" ? "Docker" : "Podman"} is not installed` : "Neither Podman nor Docker is installed", "", "deployed_code_alert") : root.note("empty", "No containers", engines.join(" · "), "deployed_code")];
        }
        return out.concat(problems);
    }

    readonly property var prefixes: !Containers.enabled ? [] : [
            {
                section: "System",
                word: "containers",
                example: "containers postgres",
                about: "Podman and Docker containers",
                icon: "deployed_code",
                also: ["podman", "docker"]
            }
        ]

    readonly property var groups: [
        {
            key: "containers",
            title: "Containers",
            items: root.rows
        }
    ]

    function arm(verb: string, container: var): void {
        root.search.armed = `container${verb}:${container.id}`;
    }

    function fire(verb: string, container: var): void {
        root.search.armed = "";
        Containers.control(container, verb);
    }

    function activate(row: var): void {
        const first = root.actionsFor(row)[0];
        if (first)
            first.run();
    }

    function actionsFor(row: var): var {
        if (row.startDocker)
            return [
                {
                    icon: "play_arrow",
                    label: "Start docker.service",
                    short: "Start",
                    run: () => SystemdUnits.control(SystemdUnits.systemUnit("docker.service"), "start", () => Containers.relist())
                }
            ];
        if (row.waiting)
            return [];
        const container = row.container;
        if (row.armedVerb)
            return [
                {
                    icon: row.armedVerb === "stop" ? "stop" : "restart_alt",
                    label: `${row.armedVerb === "stop" ? "Stop" : "Restart"} ${container.name}`,
                    short: row.armedVerb === "stop" ? "Stop" : "Restart",
                    alarm: true,
                    button: true,
                    run: () => root.fire(row.armedVerb, container)
                },
                {
                    icon: "close",
                    label: "Cancel",
                    run: () => root.search.armed = ""
                }
            ];
        const logs = {
            icon: "article",
            label: `Follow the logs of ${container.name}`,
            short: "Logs",
            run: () => root.search.launch(() => Containers.logs(container))
        };
        const busy = Containers.jobs[container.id];
        if (busy)
            return [
                {
                    icon: "hourglass_top",
                    label: busy.replace(/^./, c => c.toUpperCase()),
                    run: () => {}
                },
                logs
            ];
        if (container.state === "paused")
            return [
                {
                    icon: "play_arrow",
                    label: `Resume ${container.name}`,
                    short: "Resume",
                    run: () => root.fire("unpause", container)
                },
                logs
            ];
        if (!Logic.running(container))
            return [
                {
                    icon: "play_arrow",
                    label: `Start ${container.name}`,
                    short: "Start",
                    run: () => root.fire("start", container)
                },
                logs
            ];
        return [
            logs,
            {
                icon: "terminal",
                label: `Open a shell in ${container.name}`,
                short: "Shell",
                run: () => root.search.launch(() => Containers.shell(container))
            },
            {
                icon: "stop",
                label: `Stop ${container.name}`,
                short: "Stop",
                run: () => root.arm("stop", container)
            },
            {
                icon: "restart_alt",
                label: `Restart ${container.name}`,
                short: "Restart",
                tucked: true,
                run: () => root.arm("restart", container)
            }
        ];
    }

    function complete(row: var): bool {
        if (row.waiting)
            return false;
        root.search.retype(`${row.container.engine} ${row.container.name}`);
        return true;
    }
}
