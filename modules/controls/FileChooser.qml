import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

Item {
    id: root

    property Item holder: root
    property string folder: UserFolders.downloads

    readonly property bool available: FileDialogs.available
    readonly property bool running: process.running

    property string title: "Open"
    property string pattern: "*"

    signal picked(string path)
    signal cancelled
    signal missing

    function open(title: string, pattern: string): void {
        if (process.running)
            return;
        root.title = title;
        root.pattern = pattern;
        Prompts.leave(root.holder);
        process.running = true;
    }

    function stop(): void {
        process.running = false;
    }

    width: 0
    height: 0

    onVisibleChanged: {
        if (root.visible)
            FileDialogs.check();
        else if (!Prompts.away.includes(root.holder))
            root.stop();
    }

    Component.onCompleted: FileDialogs.check()

    Component.onDestruction: Prompts.back(root.holder)

    Process {
        id: process

        command: ["python3", Quickshell.shellPath("scripts/pick-file.py"), root.title, root.pattern, root.folder]

        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                if (path)
                    root.picked(path);
            }
        }

        onRunningChanged: if (!process.running)
            Prompts.back(root.holder)

        onExited: code => {
            if (code === 2) {
                FileDialogs.missing();
                root.missing();
            } else if (code !== 0) {
                root.cancelled();
            }
        }
    }
}
