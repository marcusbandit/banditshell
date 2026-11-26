pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "agent-limits.js" as Logic

Singleton {
    id: root

    readonly property var cfg: Config.values.agentLimits
    readonly property var enabledIds: Logic.enabledProviders(root.cfg)
    readonly property bool anyEnabled: root.enabledIds.length > 0
    readonly property bool sidebarWanted: root.anyEnabled && (root.cfg?.sidebar ?? true)
    readonly property bool widgetWanted: root.anyEnabled && (Config.values.widgets?.enabled ?? false) && (Config.values.widgets?.limits ?? false)
    readonly property bool wanted: root.sidebarWanted || root.widgetWanted

    property var providers: []
    property double fetchedAt: 0
    property double nowMs: Date.now()
    readonly property bool loading: reader.running
    readonly property var compact: Logic.compactEntries(root.providers)
    readonly property bool ready: root.compact.length > 0

    function colorFor(id: string): color {
        if (id === "claude")
            return Appearance.colour.providerClaude;
        if (id === "antigravity")
            return Appearance.colour.providerAntigravity;
        return Appearance.colour.text;
    }

    function barHeight(rail: bool): real {
        return Logic.barHeight(root.cfg?.size ?? "tall", rail);
    }

    function remainingPercent(usedPercent: real): int {
        return Logic.remainingPercent(usedPercent);
    }

    function remainingFraction(usedPercent: real): real {
        return Logic.remainingFraction(usedPercent);
    }

    function paceFraction(resetsAt: string, durationMins: int): real {
        return Logic.paceFraction(resetsAt, durationMins, root.nowMs);
    }

    function formatReset(resetsAt: string): string {
        return Logic.formatReset(resetsAt, root.nowMs);
    }

    function refresh(): void {
        if (!root.anyEnabled || reader.running)
            return;
        const list = root.enabledIds.slice();
        reader.requestedIds = list;
        reader.command = ["python3", Quickshell.shellPath("scripts/agent-limits.py"), "--providers", list.join(",")];
        reader.running = true;
    }

    function keepFresh(): void {
        const ttl = Math.max(1, root.cfg?.minutes ?? 2) * 60000;
        if (Date.now() - root.fetchedAt >= ttl)
            root.refresh();
    }

    onEnabledIdsChanged: {
        root.providers = Logic.mergeReadings(root.providers, [], root.enabledIds);
        if (root.wanted)
            root.refresh();
    }

    onWantedChanged: {
        if (root.wanted)
            root.keepFresh();
    }

    Component.onCompleted: {
        if (root.wanted)
            root.refresh();
    }

    Timer {
        interval: Math.max(1, root.cfg?.minutes ?? 2) * 60000
        repeat: true
        running: root.wanted
        onTriggered: root.refresh()
    }

    Timer {
        interval: 30000
        repeat: true
        running: root.wanted
        onTriggered: root.nowMs = Date.now()
    }

    Process {
        id: reader

        property var requestedIds: []

        stdout: StdioCollector {
            onStreamFinished: {
                const incoming = Logic.parseOutput(text);
                root.providers = Logic.mergeReadings(root.providers, incoming, root.enabledIds);
                root.fetchedAt = Date.now();
                root.nowMs = root.fetchedAt;
            }
        }
    }
}
