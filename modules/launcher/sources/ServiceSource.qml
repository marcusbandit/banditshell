import QtQuick
import Quickshell
import qs.services
import "../../../services/ranking.js" as Ranking
import "../../../services/systemd-units.js" as Logic

QtObject {
    id: root

    required property var search

    readonly property var kinds: ["service"]

    readonly property var asked: SystemdUnits.enabled && SystemdUnits.found ? Logic.ask(root.search.text) : null

    onAskedChanged: {
        if (root.asked)
            SystemdUnits.want();
        else
            SystemdUnits.drop();
    }

    readonly property var found: root.asked ? Logic.matching(SystemdUnits.units, root.asked, Ranking.place, root.asked.verb ? 6 : 14) : []
    readonly property bool exact: root.found.some(f => f.exact)
    readonly property bool intent: !!root.asked && (!root.asked.verb || root.exact)

    readonly property var caps: ({
            services: 14
        })

    readonly property string armedFor: root.search.armed.startsWith("service") ? root.search.armed : ""

    function keyOf(unit: var): string {
        return SystemdUnits.keyOf(unit);
    }

    function arming(unit: var): string {
        const armed = root.armedFor;
        const cut = armed.indexOf(":");
        return cut > 0 && armed.slice(cut + 1) === root.keyOf(unit) ? armed.slice(7, cut) : "";
    }

    function scoreAt(i: int): real {
        const asked = root.asked;
        if (asked.verb && !root.exact)
            return 0.45 - i * 0.01;
        return i === 0 ? Infinity : 100 - i * 0.01;
    }

    function row(unit: var, score: real): var {
        const verb = root.asked?.verb ?? "";
        const armed = root.arming(unit);
        const busy = SystemdUnits.jobs[root.keyOf(unit)] ?? "";
        const state = Logic.stateOf(unit);
        return {
            key: `service:${root.keyOf(unit)}${verb ? `:${verb}` : ""}`,
            kind: "service",
            unit: unit,
            verb: verb,
            armedVerb: armed,
            label: armed ? `Press Enter again to ${armed} ${unit.base}` : verb ? `${Logic.verbLabel(verb === "restart" && Logic.startable(unit) ? "start" : verb)} ${unit.base}` : unit.base,
            detail: armed ? "" : busy ? [unit.scope === "user" ? "user" : "", busy, unit.description].filter(Boolean).join(" · ") : Logic.detailOf(unit),
            icon: state === "failed" ? "error" : Logic.running(unit) ? "settings_suggest" : "settings_applications",
            score: score
        };
    }

    function note(key: string, label: string, icon: string): var {
        return {
            key: `service:${key}`,
            kind: "service",
            waiting: true,
            label: label,
            detail: "",
            icon: icon,
            score: Infinity
        };
    }

    readonly property var rows: {
        const asked = root.asked;
        if (!asked)
            return [];
        if (!root.found.length) {
            if (!SystemdUnits.read && !asked.verb)
                return [root.note("reading", "Reading services", "hourglass_top")];
            if (asked.failed && SystemdUnits.read)
                return [root.note("nofailed", "No service has failed", "check")];
            return [];
        }
        return root.found.map((f, i) => root.row(f.unit, root.scoreAt(i)));
    }

    readonly property var groups: [
        {
            key: "services",
            title: "Services",
            items: root.rows
        }
    ]

    function arm(verb: string, unit: var): void {
        root.search.armed = `service${verb}:${root.keyOf(unit)}`;
    }

    function fire(verb: string, unit: var): void {
        root.search.armed = "";
        SystemdUnits.control(unit, verb, null);
    }

    function verbAction(verb: string, unit: var): var {
        const icons = {
            start: "play_arrow",
            stop: "stop",
            restart: "restart_alt"
        };
        return {
            icon: icons[verb],
            label: `${Logic.verbLabel(verb)} ${unit.base}`,
            short: Logic.verbLabel(verb),
            run: () => verb === "start" ? root.fire(verb, unit) : root.arm(verb, unit)
        };
    }

    function activate(row: var): void {
        const first = root.actionsFor(row)[0];
        if (first)
            first.run();
    }

    function actionsFor(row: var): var {
        if (row.waiting)
            return [];
        const unit = row.unit;
        const logs = {
            icon: "article",
            label: `Show the log of ${unit.base}`,
            short: "Logs",
            run: () => root.search.launch(() => SystemdUnits.logs(unit))
        };
        if (row.armedVerb)
            return [
                {
                    icon: row.armedVerb === "stop" ? "stop" : "restart_alt",
                    label: `${Logic.verbLabel(row.armedVerb)} ${unit.base}`,
                    short: Logic.verbLabel(row.armedVerb),
                    alarm: true,
                    button: true,
                    run: () => root.fire(row.armedVerb, unit)
                },
                {
                    icon: "close",
                    label: "Cancel",
                    run: () => root.search.armed = ""
                }
            ];
        const busy = SystemdUnits.jobs[root.keyOf(unit)];
        if (busy)
            return [
                {
                    icon: "hourglass_top",
                    label: busy.replace(/^./, c => c.toUpperCase()),
                    run: () => {}
                },
                logs
            ];
        const running = Logic.running(unit);
        const offered = running ? ["restart", "stop"] : Logic.startable(unit) ? ["start"] : [];
        const wanted = row.verb === "restart" && !running ? "start" : row.verb;
        const order = offered.indexOf(wanted) >= 0 ? [wanted].concat(offered.filter(v => v !== wanted)) : offered;
        const already = wanted === "stop" && !running ? "Already stopped" : wanted === "start" && running ? "Already running" : "";
        return (already ? [
                {
                    icon: "check",
                    label: already,
                    run: () => {}
                }
            ] : []).concat(order.map(v => root.verbAction(v, unit)), [logs]);
    }

    function complete(row: var): bool {
        if (row.waiting)
            return false;
        root.search.retype(`${row.verb || "service"} ${row.unit.base}`);
        return true;
    }
}
