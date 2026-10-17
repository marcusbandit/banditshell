pragma Singleton

import QtQuick
import Quickshell
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

    readonly property var usages: root.enabled ? Logic.usages(root.snapshot, root.quiet) : []

    property var posted: []

    function settle(): void {
        const diff = Logic.changes(root.posted, root.usages);
        root.posted = root.usages;
        for (const usage of diff.push)
            Activities.push(Logic.usageSpec(usage));
        for (const id of diff.end)
            Activities.remove(id);
    }

    onUsagesChanged: root.settle()

    Component.onCompleted: root.settle()

    PwObjectTracker {
        objects: [...Pipewire.nodes.values, ...Pipewire.links.values]
    }
}
