import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property string path: ""

    signal loaded(string text)

    function save(text: string): void {
        if (!root.path)
            return;
        root.writer.createObject(root, {
            command: [`${Quickshell.shellDir}/scripts/write-private.sh`, root.path],
            input: text
        }).running = true;
    }

    property FileView reader: FileView {
        path: root.path
        printErrors: false
        onLoaded: root.loaded(root.reader.text())
    }

    property Component writer: Component {
        Process {
            id: run

            property string input: ""

            stdinEnabled: true

            onStarted: {
                run.write(run.input);
                run.stdinEnabled = false;
            }

            onExited: run.destroy()
        }
    }
}
