pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    property var items: []
    property var rail: []
    property var island: []
    property string menuKey: ""
    readonly property var menuItem: root.items.find(i => i.key === root.menuKey) ?? null

    signal pressed(string pluginId, string id, string action)

    function place(items: var): void {
        const rail = items.filter(i => i.place === "rail");
        const island = items.filter(i => i.place === "island");
        root.items = items;
        if (JSON.stringify(rail) !== JSON.stringify(root.rail))
            root.rail = rail;
        if (JSON.stringify(island) !== JSON.stringify(root.island))
            root.island = island;
    }

    function set(item: var): void {
        const at = root.items.findIndex(i => i.key === item.key);
        if (!item.shown)
            root.place(root.items.filter(i => i.key !== item.key));
        else if (at < 0)
            root.place(root.items.concat([item]));
        else
            root.place(root.items.slice(0, at).concat([item], root.items.slice(at + 1)));
    }

    function drop(pluginId: string): void {
        if (root.items.some(i => i.pluginId === pluginId))
            root.place(root.items.filter(i => i.pluginId !== pluginId));
    }

    function press(key: string, action: string): void {
        const item = root.items.find(i => i.key === key);
        if (item)
            root.pressed(item.pluginId, item.id, action);
    }
}
