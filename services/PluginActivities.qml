pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    property var shown: []

    function entryOf(item: var): var {
        return {
            id: item.key,
            kind: "external",
            style: "plugin",
            text: item.title,
            detail: item.text || item.lines.join(", "),
            icon: item.icon,
            progress: item.progress,
            data: {
                tone: item.tone
            },
            actions: item.actions.map(a => ({
                        name: a.id,
                        label: a.title.slice(0, 12)
                    })),
            act: (entry, action) => PluginStatus.press(item.key, action),
            source: `plugin:${item.pluginId}`
        };
    }

    function mirror(): void {
        const now = PluginStatus.placed("island");
        for (const key of root.shown)
            if (!now.some(i => i.key === key))
                Activities.remove(key);
        for (const item of now) {
            const refused = Activities.push(root.entryOf(item));
            if (refused)
                console.warn("PluginActivities:", item.key, refused);
        }
        root.shown = now.map(i => i.key);
    }

    Connections {
        target: PluginStatus

        function onItemsChanged(): void {
            root.mirror();
        }
    }

    Component.onCompleted: root.mirror()
}
