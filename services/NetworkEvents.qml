pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    signal changed

    Process {
        id: watcher

        running: true
        command: ["nmcli", "monitor"]

        stdout: SplitParser {
            onRead: settle.restart()
        }

        onExited: rewatch.start()
    }

    Timer {
        id: settle

        interval: 400
        onTriggered: root.changed()
    }

    Timer {
        id: rewatch

        interval: 5000
        onTriggered: watcher.running = true
    }
}
