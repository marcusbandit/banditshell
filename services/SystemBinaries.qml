pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "system-binaries.js" as Logic

Singleton {
    id: root

    readonly property var tools: ["pkexec", "kill", "fuser", "systemctl"]

    property var paths: ({})
    property bool probed: false

    function has(tool: string): bool {
        return !!root.paths[tool];
    }

    function elevated(tool: string, args: var): var {
        return Logic.elevated(root.paths, tool, args);
    }

    Process {
        running: true
        command: Logic.probeCommand(root.tools)
        stdout: StdioCollector {
            id: found
        }
        onExited: {
            root.paths = Logic.readPaths(found.text);
            root.probed = true;
        }
    }
}
