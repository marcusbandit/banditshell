pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool available: false
    property real checkedAt: 0

    function check(): void {
        if (probe.running || (root.checkedAt > 0 && Date.now() - root.checkedAt < 60000))
            return;
        probe.running = true;
    }

    function missing(): void {
        root.available = false;
        root.checkedAt = Date.now();
    }

    Process {
        id: probe

        command: ["python3", Quickshell.shellPath("scripts/pick-file.py"), "--check"]
        onExited: code => {
            root.available = code === 0;
            root.checkedAt = Date.now();
        }
    }
}
