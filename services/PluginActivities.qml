pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    property var pushed: ({})

    function idOf(key: string): string {
        if (key.length <= 64)
            return key;
        let hash = 5381;
        for (let i = 0; i < key.length; i++)
            hash = (hash * 33 + key.charCodeAt(i)) >>> 0;
        return `plugin:${hash.toString(36)}`;
    }

    function entryOf(item: var): var {
        return {
            id: root.idOf(item.key),
            kind: "external",
            style: "plugin",
            text: item.title,
            detail: (item.text || item.lines.join(", ")).slice(0, 200),
            icon: item.icon,
            progress: item.progress,
            pressable: true,
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
        const now = PluginStatus.island;
        const next = {};
        for (const key of Object.keys(root.pushed))
            if (!now.some(i => i.key === key))
                Activities.remove(root.idOf(key));
        for (const item of now) {
            const text = JSON.stringify(item);
            next[item.key] = text;
            if (root.pushed[item.key] === text)
                continue;
            const refused = Activities.push(root.entryOf(item));
            if (refused)
                console.warn("PluginActivities:", item.key, refused);
        }
        root.pushed = next;
    }

    Connections {
        target: PluginStatus

        function onIslandChanged(): void {
            root.mirror();
        }
    }

    Component.onCompleted: root.mirror()
}
