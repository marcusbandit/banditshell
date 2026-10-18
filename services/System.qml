pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME") ?? "/home"

    signal revealRequested(string path)

    function copyText(text: string): void {
        copier.createObject(root, {
            input: text,
            stdinEnabled: text !== "",
            running: true
        });
    }

    function openWith(path: string): void {
        opener.command = ["xdg-open", path];
        opener.startDetached();
    }

    function reveal(path: string): void {
        root.revealRequested(path);
    }

    Process {
        id: opener
    }

    Component {
        id: copier

        Process {
            id: task

            property string input: ""
            property bool begun: false

            command: ["wl-copy"]

            onStarted: {
                task.begun = true;
                if (task.input !== "") {
                    task.write(task.input);
                    task.stdinEnabled = false;
                }
            }

            onRunningChanged: if (!task.running && !task.begun)
                task.destroy()

            onExited: task.destroy()
        }
    }
}
