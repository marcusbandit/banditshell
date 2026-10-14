import QtQuick
import Quickshell.Io

Item {
    id: root

    property var pending: []
    property string output: ""
    property bool began: false
    property string input: ""

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
        root.input = Array.isArray(next) ? "" : next.input ?? "";
        worker.stdinEnabled = root.input !== "";
        worker.exec(Array.isArray(next) ? next : next.command);
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

        onStarted: {
            root.began = true;
            if (root.input === "")
                return;
            worker.write(root.input);
            root.input = "";
            worker.stdinEnabled = false;
        }

        onExited: code => root.settle(code, said.text, complained.text)

        onRunningChanged: {
            if (!worker.running && !root.began)
                root.settle(-1, "", "the command did not start");
        }
    }
}
