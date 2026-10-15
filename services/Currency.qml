pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "currency.js" as Money

Singleton {
    id: root

    readonly property string path: `${Config.stateDir}/rates.json`
    readonly property string feed: "https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml"
    readonly property real staleAfter: 12 * 3600 * 1000

    property var rates: ({})
    property string date: ""
    property real fetched: 0

    readonly property var codes: ["EUR", ...Object.keys(root.rates)].sort()
    readonly property string home: Config.values.launcher.currency
    readonly property bool stale: Date.now() - root.fetched > root.staleAfter
    readonly property bool linked: Network.connected

    function answer(text: string): var {
        const ask = Money.parse(text, root.codes, root.home);
        if (!ask)
            return null;
        const value = Money.convert(ask.amount, ask.from, ask.to, root.rates);
        if (!isFinite(value))
            return null;
        const one = Money.convert(1, ask.from, ask.to, root.rates);
        return {
            value: value,
            text: `${Money.money(value)} ${ask.to}`,
            detail: `1 ${ask.from} = ${one.toFixed(4)} ${ask.to} · ${root.date}`,
            work: 1,
            firm: true,
            money: true
        };
    }

    function refresh(): void {
        if (!fetcher.running)
            fetcher.running = true;
    }

    onLinkedChanged: if (root.linked && root.stale)
        root.refresh()

    Timer {
        interval: 3600 * 1000
        repeat: true
        running: true
        onTriggered: if (root.stale)
            root.refresh()
    }

    Timer {
        id: retry

        interval: 10 * 60 * 1000
        onTriggered: root.refresh()
    }

    Process {
        id: fetcher

        command: ["curl", "-fsSL", "--max-time", "20", root.feed]

        stdout: StdioCollector {
            onStreamFinished: {
                const got = Money.readEcb(text);
                if (!got) {
                    retry.restart();
                    return;
                }
                root.rates = got.rates;
                root.date = got.date;
                root.fetched = Date.now();
                store.setText(JSON.stringify({
                    date: root.date,
                    fetched: root.fetched,
                    rates: root.rates
                }));
            }
        }

        onExited: code => {
            if (code !== 0)
                retry.restart();
        }
    }

    FileView {
        id: store

        path: root.path
        printErrors: false

        onLoaded: {
            try {
                const kept = JSON.parse(store.text());
                root.rates = kept.rates ?? {};
                root.date = kept.date ?? "";
                root.fetched = kept.fetched ?? 0;
            } catch (e) {}
            if (root.stale)
                root.refresh();
        }
        onLoadFailed: root.refresh()
    }
}
