pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    property var items: []
    property string menuKey: ""
    readonly property var menuItem: root.items.find(i => i.key === root.menuKey) ?? null

    signal pressed(string pluginId, string id, string action)

    function placed(place: string): var {
        return root.items.filter(i => i.place === place);
    }

    function set(item: var): void {
        const at = root.items.findIndex(i => i.key === item.key);
        if (!item.shown)
            root.items = root.items.filter(i => i.key !== item.key);
        else if (at < 0)
            root.items = root.items.concat([item]);
        else
            root.items = root.items.slice(0, at).concat([item], root.items.slice(at + 1));
    }

    function drop(pluginId: string): void {
        if (root.items.some(i => i.pluginId === pluginId))
            root.items = root.items.filter(i => i.pluginId !== pluginId);
    }

    function press(key: string, action: string): void {
        const item = root.items.find(i => i.key === key);
        if (item)
            root.pressed(item.pluginId, item.id, action);
    }
}
