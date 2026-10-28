pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool sleeping: false
    property bool logind: true

    signal lockRequested

    function requestLock(): void {
        root.lockRequested();
    }

    function lacksLogind(what: string): bool {
        if (root.logind)
            return false;
        Notify.post({
            summary: `${what} needs logind`,
            body: "elogind or systemd-logind does this, and neither is running here",
            kind: "session"
        });
        return true;
    }

    Process {
        running: true
        command: ["sh", "-c", "test -d /run/systemd/seats"]
        onExited: code => root.logind = code === 0
    }
}
