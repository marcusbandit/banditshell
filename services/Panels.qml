pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    property var host: null
    property var own: ({})

    function adopt(host: var): void {
        root.host = host;
    }

    function claim(name: string, handler: var): void {
        root.own = Object.assign({}, root.own, {
            [name]: handler
        });
    }

    function open(name: string, args: var): void {
        const handler = root.own[name];
        if (handler)
            handler.open(args ?? {});
        else
            root.host?.openPanel(name, args ?? {});
    }

    function toggle(name: string, args: var): void {
        const handler = root.own[name];
        if (handler)
            handler.toggle(args ?? {});
        else
            root.host?.togglePanel(name, args ?? {});
    }

    function openMenu(key: string, screen: string): bool {
        return root.host?.openMenu(key, screen) ?? false;
    }

    function isOpen(name: string): bool {
        const handler = root.own[name];
        if (handler)
            return handler.isOpen();
        return root.host?.panelOpen(name) ?? false;
    }
}
