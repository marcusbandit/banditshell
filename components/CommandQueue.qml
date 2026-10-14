import QtQuick
import Quickshell.Io

Item {
    id: root

    property var pending: []
    property string output: ""
    property bool began: false

    readonly property bool busy: worker.running || root.pending.length > 0

    signal finished(bool ok, string output, string error)

    function run(commands: var): void {
        if (root.busy || !commands.length)
            return;
        root.pending = commands.slice();
        root.output = "";
        root.advance();
    }

    function advance(): void {
        const next = root.pending[0];
        root.pending = root.pending.slice(1);
        root.began = false;
        worker.exec(next);
    }

    function settle(code: int, said: string, complained: string): void {
        if (code !== 0) {
            root.pending = [];
            root.finished(false, root.output + said, complained);
            return;
        }
        root.output += said;
        if (root.pending.length > 0)
            root.advance();
        else
            root.finished(true, root.output, "");
    }

    Process {
        id: worker

        stdout: StdioCollector {
            id: said
        }

        stderr: StdioCollector {
            id: complained
        }

        onStarted: root.began = true

        onExited: code => root.settle(code, said.text, complained.text)

        onRunningChanged: {
            if (!worker.running && !root.began)
                root.settle(-1, "", "the command did not start");
        }
    }
}
