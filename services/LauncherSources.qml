pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    property var added: []

    property int stamp: 0

    function add(id: string, component: Component, properties: var): void {
        root.stamp++;
        root.added = root.added.filter(a => a.id !== id).concat([
            {
                id: id,
                component: component,
                properties: properties ?? {},
                stamp: root.stamp
            }
        ]);
    }

    function remove(id: string): void {
        if (root.added.some(a => a.id === id))
            root.added = root.added.filter(a => a.id !== id);
    }

    function has(id: string): bool {
        return root.added.some(a => a.id === id);
    }
}
