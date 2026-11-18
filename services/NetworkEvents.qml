pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "wifilist.js" as WifiList

Singleton {
    id: root

    signal changed

    property var stages: ({})

    function note(line: string): void {
        const found = WifiList.parseDeviceStage(line);
        if (found && root.stages[found.device] !== found.stage)
            root.stages = Object.assign({}, root.stages, {
                [found.device]: found.stage
            });
    }

    Process {
        id: watcher

        running: Network.managerRunning
        command: ["nmcli", "monitor"]
        environment: ({
                LC_ALL: "C"
            })

        stdout: SplitParser {
            onRead: line => {
                root.note(line);
                settle.restart();
            }
        }

        onExited: if (Network.managerRunning)
            rewatch.start()
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
