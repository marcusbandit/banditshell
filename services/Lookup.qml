import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property int delay: 400
    property int keep: 120
    property real retryAfter: 60 * 1000
    property real freshFor: Infinity
    property string file: ""

    property var commandFor: key => []
    property var read: (text, key) => null

    property var answers: ({})
    property var failures: ({})
    property var stamps: ({})
    property var order: []

    property string wanted: ""
    property string asking: ""
    property QtObject running: null

    readonly property bool busy: root.running !== null

    function answerFor(key: string): var {
        return root.answers[key];
    }

    function failedOn(key: string): bool {
        return root.failures[key] !== undefined;
    }

    function pendingOn(key: string): bool {
        return !!key && root.answers[key] === undefined && root.failures[key] === undefined;
    }

    function want(key: string): void {
        if (!key) {
            root.wanted = "";
            root.wait.stop();
            root.cancel();
            return;
        }
        if (key === root.wanted && (root.busy || root.wait.running))
            return;
        root.wanted = key;
        const known = root.answers[key] !== undefined;
        const stale = known && Date.now() - (root.stamps[key] ?? 0) > root.freshFor;
        if (root.running && root.running.key !== key)
            root.cancel();
        if (known && !stale) {
            root.wait.stop();
            return;
        }
        const failed = root.failures[key];
        if (failed !== undefined && Date.now() - failed < root.retryAfter) {
            root.wait.stop();
            return;
        }
        root.wait.restart();
    }

    function cancel(): void {
        const run = root.running;
        root.running = null;
        root.asking = "";
        if (!run)
            return;
        run.dropped = true;
        run.running = false;
        run.destroy();
    }

    function again(key: string): void {
        root.stamps = ({});
        root.failures = ({});
        if (!key)
            return;
        root.wanted = "";
        root.want(key);
    }

    function forget(key: string): void {
        const answers = Object.assign({}, root.answers);
        delete answers[key];
        root.answers = answers;
    }

    function store(key: string, value: var): void {
        const answers = Object.assign({}, root.answers);
        answers[key] = value;
        const stamps = Object.assign({}, root.stamps);
        stamps[key] = Date.now();
        const order = root.order.filter(k => k !== key).concat([key]);
        while (order.length > root.keep) {
            const old = order.shift();
            delete answers[old];
            delete stamps[old];
        }
        root.answers = answers;
        root.stamps = stamps;
        root.order = order;
        if (root.failures[key] !== undefined) {
            const failures = Object.assign({}, root.failures);
            delete failures[key];
            root.failures = failures;
        }
        if (root.file)
            root.saving.restart();
    }

    function fail(key: string): void {
        const failures = Object.assign({}, root.failures);
        failures[key] = Date.now();
        root.failures = failures;
    }

    function start(key: string): void {
        if (!key || key !== root.wanted)
            return;
        const command = root.commandFor(key);
        if (!command || !command.length)
            return;
        root.cancel();
        root.asking = key;
        root.running = root.runner.createObject(root, {
            key: key,
            command: command
        });
        root.running.running = true;
    }

    function finish(run: var, code: int, text: string): void {
        if (root.running === run) {
            root.running = null;
            root.asking = "";
        }
        if (run.dropped)
            return;
        const value = code === 0 ? root.read(text, run.key) : null;
        if (value === null || value === undefined)
            root.fail(run.key);
        else
            root.store(run.key, value);
    }

    property Timer wait: Timer {
        interval: root.delay
        onTriggered: root.start(root.wanted)
    }

    property Timer saving: Timer {
        interval: 2000
        onTriggered: root.memory.setText(JSON.stringify({
            answers: root.answers,
            stamps: root.stamps,
            order: root.order
        }))
    }

    property Component runner: Component {
        Process {
            id: run

            property string key: ""
            property bool dropped: false
            property int code: -1
            property bool heard: false

            function settle(): void {
                if (run.code < 0 || !run.heard)
                    return;
                root.finish(run, run.code, said.text);
                if (!run.dropped)
                    run.destroy();
            }

            stdout: StdioCollector {
                id: said

                onStreamFinished: {
                    run.heard = true;
                    run.settle();
                }
            }

            onExited: code => {
                run.code = code;
                run.settle();
            }
        }
    }

    property FileView memory: FileView {
        path: root.file
        printErrors: false

        onLoaded: {
            try {
                const kept = JSON.parse(root.memory.text());
                root.answers = Object.assign({}, kept.answers ?? {}, root.answers);
                root.stamps = Object.assign({}, kept.stamps ?? {}, root.stamps);
                root.order = (kept.order ?? []).filter(k => root.order.indexOf(k) < 0).concat(root.order);
            } catch (e) {}
        }
    }
}
