pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.config
import "privacy.js" as Logic

Singleton {
    id: root

    readonly property bool enabled: Notices.live && Config.values.island.moments.privacy

    readonly property var snapshot: ({
            nodes: Pipewire.nodes.values.map(n => ({
                        id: n.id,
                        props: n.properties
                    })),
            links: Pipewire.links.values.map(l => ({
                        source: l.source?.id ?? -1,
                        target: l.target?.id ?? -1,
                        active: l.state === PwLinkState.Active
                    }))
        })

    readonly property var quiet: ({
            mic: Dictation.live || (ScreenRecorder.recording && ScreenRecorder.sound),
            screen: ScreenRecorder.recording
        })

    property var mockedUsages: null

    readonly property var usages: root.mockedUsages ?? (root.enabled ? Logic.usages(root.snapshot, root.quiet) : [])

    property var posted: []

    property var heard: []

    readonly property var micUsage: root.usages.find(u => u.kind === "mic") ?? null

    readonly property var micRow: root.micUsage ? {
        key: "privacy:privacy:mic",
        id: "privacy:mic",
        kind: "privacy",
        style: "privacy",
        text: Logic.usageSpec(root.micUsage).text,
        detail: "",
        icon: "mic",
        pressable: true,
        data: {
            privacy: "mic",
            apps: root.micUsage.apps
        }
    } : null

    property var listeners: []
    property var found: []
    property var mocked: null

    function listen(): void {
        if (root.mocked) {
            root.listeners = root.mocked;
            return;
        }
        dump.running = true;
    }

    function mock(usages: var, rows: var): void {
        root.mockedUsages = usages;
        root.mocked = rows;
        root.listeners = rows ?? [];
    }

    function settle(): void {
        const diff = Logic.changes(root.posted, root.usages);
        root.posted = root.usages;
        const mic = root.usages.find(u => u.kind === "mic") ?? null;
        const step = Logic.micStep(root.heard, mic, micMoment.running);
        root.heard = step.heard;
        if (!mic)
            micMoment.stop();
        else if (step.announce)
            micMoment.restart();
        for (const usage of diff.push)
            if (usage.kind !== "mic" || step.post)
                Activities.push(Logic.usageSpec(usage));
        for (const id of diff.end)
            Activities.remove(id);
    }

    onUsagesChanged: root.settle()

    Component.onCompleted: root.settle()

    Timer {
        id: micMoment

        interval: Notices.glanceMs
        onTriggered: Activities.remove("privacy:mic")
    }

    Process {
        id: dump

        command: ["pw-dump"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.found = Logic.listeners(text);
                const pids = root.found.map(l => String(l.pid)).filter(pid => pid !== "0");
                if (pids.length === 0) {
                    root.listeners = Logic.named(root.found, "");
                    return;
                }
                names.command = ["sh", "-c", 'for p; do [ -r "/proc/$p/cmdline" ] || continue; printf "%s\\t%s\\t%s\\n" "$p" "$(tr "\\0" " " < "/proc/$p/cmdline")" "$(tail -n 1 "/proc/$p/cgroup" 2>/dev/null)"; done', "sh", ...pids];
                names.running = true;
            }
        }
    }

    Process {
        id: names

        stdout: StdioCollector {
            onStreamFinished: root.listeners = Logic.named(root.found, text)
        }
    }

    PwObjectTracker {
        objects: [...Pipewire.nodes.values, ...Pipewire.links.values]
    }
}
