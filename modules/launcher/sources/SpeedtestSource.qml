import QtQuick
import Quickshell
import qs.services
import "../../../services/speedtest.js" as Speed

QtObject {
    id: root

    required property var search

    readonly property var kinds: ["speedtest"]

    readonly property bool asked: SpeedTest.enabled && Speed.ask(root.search.text)

    onAskedChanged: if (root.asked)
        SpeedTest.probe()

    readonly property bool intent: root.asked

    readonly property var phaseLabels: ({
            starting: "Finding a server",
            pinging: "Finding a server",
            download: "Testing download",
            upload: "Testing upload",
            done: "Finishing"
        })

    readonly property var groups: [
        {
            key: "speedtest",
            title: "Speed test",
            items: root.asked ? [root.rowById("speedtest:run")].filter(Boolean) : []
        }
    ]

    function rowById(id: string): var {
        if (id !== "speedtest:run" || !SpeedTest.enabled)
            return null;
        const base = {
            key: "speedtest:run",
            kind: "speedtest",
            icon: "speed",
            score: Infinity
        };
        if (SpeedTest.probed && !SpeedTest.found)
            return Object.assign(base, {
                label: SpeedTest.installing === "trying" ? "Installing speedtest-cli" : "Install speedtest-cli",
                detail: "",
                icon: "download",
                setup: true
            });
        if (SpeedTest.running)
            return Object.assign(base, {
                label: root.phaseLabels[SpeedTest.state.phase] ?? "Testing",
                detail: Speed.summary(SpeedTest.state) || SpeedTest.state.server,
                running: true
            });
        if (SpeedTest.failed)
            return Object.assign(base, {
                label: "Speed test failed",
                detail: SpeedTest.failed
            });
        const last = SpeedTest.last;
        if (last && Speed.headline(last))
            return Object.assign(base, {
                label: Speed.headline(last),
                detail: `${last.unit} · ping ${Math.round(last.ping)} ms · ${TimeFormat.time(new Date(last.at), false)}`,
                done: true
            });
        return Object.assign(base, {
            label: "Run speed test",
            detail: ""
        });
    }

    function activate(row: var): void {
        if (row.setup)
            SpeedTest.install();
        else if (row.running)
            SpeedTest.stop();
        else
            SpeedTest.start();
    }

    function actionsFor(row: var): var {
        if (row.setup)
            return [
                {
                    icon: "download",
                    label: "Install",
                    run: () => SpeedTest.install()
                }
            ];
        if (row.running)
            return [
                {
                    icon: "stop",
                    label: "Stop",
                    run: () => SpeedTest.stop()
                }
            ];
        return [
            {
                icon: row.done ? "refresh" : "play_arrow",
                label: row.done ? "Run again" : "Run",
                run: () => SpeedTest.start()
            }
        ].concat(row.done ? [
                {
                    icon: "content_copy",
                    label: "Copy",
                    run: () => {
                        const text = Speed.summary(SpeedTest.last);
                        root.search.leave(() => System.copyText(text));
                    }
                }
            ] : []);
    }
}
