pragma Singleton

import QtQuick
import Quickshell
import qs.config

Singleton {
    id: root

    readonly property bool enabled: Config.values.sidebar.enabled

    readonly property var perScreen: Config.values.sidebar.perScreen ?? ({})

    function visibleOn(screen: string): bool {
        if (!screen)
            return root.enabled;
        return root.perScreen[screen] ?? root.enabled;
    }

    function setOn(screen: string, on: bool): void {
        if (!screen) {
            root.setAll(on);
            return;
        }

        const next = Object.assign({}, root.perScreen);
        if (on === root.enabled)
            delete next[screen];
        else
            next[screen] = on;
        Config.set("sidebar.perScreen", next);
    }

    function setAll(on: bool): void {
        Config.setMany([["sidebar.perScreen", {}], ["sidebar.enabled", on]]);
    }
}
