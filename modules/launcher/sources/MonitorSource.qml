import QtQuick
import qs.services
import "../search.js" as Search
import "../../../services/system-monitor.js" as Monitor

QtObject {
    id: root

    required property var search

    readonly property var kinds: ["monitor", "monitorprocess"]

    readonly property string view: Monitor.monitorAsk(root.search.text)

    readonly property bool intent: root.view !== ""

    readonly property bool watching: root.view !== ""

    onWatchingChanged: SystemMonitor.watch(root.watching)

    Component.onDestruction: if (root.watching)
        SystemMonitor.watch(false)

    function wants(part: string): bool {
        return root.view === part || root.view === "system";
    }

    function row(key: string, label: string, detail: string, icon: string): var {
        return {
            key: `monitor:${key}`,
            kind: "monitor",
            label: label,
            detail: detail,
            icon: icon,
            score: Infinity
        };
    }

    readonly property var cpuRow: {
        const cores = SystemMonitor.cores;
        const heat = SystemInfo.temperature;
        return root.row("cpu", `CPU ${Monitor.cpuText(SystemInfo.cpu * 100)}`, [cores ? `${cores} cores` : "", heat > 0 ? `${Math.round(heat)} °C` : ""].filter(Boolean).join(" · "), "developer_board");
    }

    readonly property var memoryRow: root.row("memory", `Memory ${SystemInfo.memoryUsedGb.toFixed(1)} of ${SystemInfo.memoryTotalGb.toFixed(1)} GB`, `${Monitor.percentText(SystemInfo.memory)} used · swap ${Monitor.percentText(SystemInfo.swap)}`, "memory")

    readonly property var batteryRow: {
        if (!Battery.available)
            return null;
        const left = Battery.secondsLeft > 0 ? Search.spanText(Math.round(Battery.secondsLeft / 60) * 60) : "";
        const state = Battery.full ? "full" : Battery.charging ? (left ? `charging · full in ${left}` : "charging") : left ? `${left} left` : "on battery";
        return root.row("battery", `Battery ${Battery.percent}%`, state, Battery.charging ? "battery_charging_full" : "battery_full");
    }

    readonly property var uptimeRow: {
        if (SystemMonitor.uptime <= 0)
            return null;
        const since = new Date(Date.now() - SystemMonitor.uptime * 1000);
        return root.row("uptime", `Up ${Monitor.uptimeText(SystemMonitor.uptime)}`, `since ${Qt.locale().dayName(since.getDay(), Locale.ShortFormat)} ${TimeFormat.time(since, false)}`, "schedule");
    }

    readonly property var diskRows: SystemMonitor.disks.map(d => root.row(`disk:${d.mount}`, `${Monitor.bytesText(d.available)} free on ${d.mount}`, `${Monitor.percentText(d.fraction)} used · ${Monitor.bytesText(d.size)} · ${d.type}`, "hard_drive"))

    readonly property var processRows: SystemMonitor.top.map(p => ({
                key: `monitorprocess:${p.pid}`,
                kind: "monitorprocess",
                pid: p.pid,
                own: p.own,
                label: p.name,
                detail: `${Monitor.cpuText(p.cpu)} CPU · ${Monitor.bytesText(p.memory)} · PID ${p.pid}`,
                iconSource: Apps.iconSourceFor([p.name]),
                icon: "memory",
                score: Infinity
            }))

    readonly property var systemRows: {
        if (!root.watching)
            return [];
        const out = [];
        if (root.wants("cpu"))
            out.push(root.cpuRow);
        if (root.wants("memory"))
            out.push(root.memoryRow);
        if (root.view === "system" && root.batteryRow)
            out.push(root.batteryRow);
        if ((root.wants("uptime")) && root.uptimeRow)
            out.push(root.uptimeRow);
        return root.wants("disk") ? out.concat(root.diskRows) : out;
    }

    readonly property var groups: [
        {
            key: "monitor",
            title: "System",
            items: root.systemRows
        },
        {
            key: "busy",
            title: "Busy processes",
            items: root.watching && (root.wants("cpu") || root.view === "top") ? root.processRows : []
        }
    ]

    readonly property var caps: ({
            monitor: 16,
            busy: 5
        })

    function activate(row: var): void {
        root.actionsFor(row)[0].run();
    }

    function actionsFor(row: var): var {
        if (row.kind !== "monitorprocess")
            return [
                {
                    icon: "content_copy",
                    label: "Copy",
                    run: () => root.search.leave(() => Files.copyText(`${row.label} · ${row.detail}`))
                }
            ];
        const pid = row.pid;
        const name = row.label;
        if (!row.own)
            return [
                {
                    icon: "admin_panel_settings",
                    label: "Quit as administrator",
                    short: "Quit",
                    button: true,
                    run: () => SystemMonitor.quitAsAdministrator(pid, name)
                }
            ];
        return [
            {
                icon: "close",
                label: "Quit",
                button: true,
                run: () => SystemMonitor.quit(pid, false)
            },
            {
                icon: "dangerous",
                label: "Force quit",
                tucked: true,
                run: () => SystemMonitor.quit(pid, true)
            }
        ];
    }
}
