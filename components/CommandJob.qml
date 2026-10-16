import QtQuick
import Quickshell.Io

Process {
    id: root

    property bool began: false
    property bool settled: false

    signal finished(int code, string output, string error)

    function settle(code: int, output: string, error: string): void {
        if (root.settled)
            return;
        root.settled = true;
        root.finished(code, output, error);
        root.destroy();
    }

    stdout: StdioCollector {
        id: said
    }

    stderr: StdioCollector {
        id: complained
    }

    onStarted: root.began = true
    onExited: code => root.settle(code, said.text, complained.text)
    onRunningChanged: {
        if (!root.running && !root.began)
            root.settle(127, "", "the command did not start");
    }
}
