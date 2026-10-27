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

    property var coins: ({})
    property real coinsFetched: 0
    readonly property real coinsStaleAfter: 10 * 60 * 1000

    readonly property var codes: ["EUR", ...Object.keys(root.rates)].sort()
    readonly property var known: [...root.codes, ...Object.keys(Money.COINS)]
    readonly property var every: Object.assign({}, root.rates, root.coins)
    readonly property string home: Config.values.launcher.currency
    readonly property bool linked: Network.connected

    function answer(text: string, evaluate: var): var {
        const ask = Money.parse(text, root.known, root.home, evaluate);
        if (!ask)
            return null;
        const value = Money.total(ask, root.every);
        if (!isFinite(value))
            return Money.coinsIn(ask) ? {
                text: coinFetcher.running ? "Fetching the price…" : "No price for that yet",
                work: 1,
                firm: false,
                icon: "currency_bitcoin"
            } : null;
        const amount = n => Number(parseFloat(n.toPrecision(12))).toLocaleString(Qt.locale(), "f", Number.isInteger(n) ? 0 : Money.places(n));
        const first = ask.terms[0];
        const one = Money.convert(1, first.from, ask.to, root.every);
        const rate = `1 ${first.from} = ${one.toLocaleString(Qt.locale(), "f", one >= 1000 ? 2 : Math.max(4, Money.places(one)))} ${ask.to}`;
        const said = ask.terms.length > 1 ? ask.terms.map((t, i) => `${i ? (t.amount < 0 ? "− " : "+ ") : ""}${amount(i ? Math.abs(t.amount) : t.amount)} ${t.from}`).join(" ") : ask.worked ? `${amount(first.amount)} ${first.from} · ${rate}` : rate;
        const when = Money.coinsIn(ask) ? `CoinGecko ${TimeFormat.clock(new Date(root.coinsFetched).getHours(), new Date(root.coinsFetched).getMinutes())}` : root.date;
        return {
            value: value,
            text: `${value.toLocaleString(Qt.locale(), "f", Money.places(value))} ${ask.to}`,
            detail: `${said} · ${when}`,
            work: 1,
            firm: true,
            money: true
        };
    }

    function stale(): bool {
        return Money.stale(root.fetched, Date.now(), root.staleAfter);
    }

    function refresh(): void {
        if (!fetcher.running)
            fetcher.running = true;
    }

    property double coinsTried: 0

    function wake(text: string, evaluate: var): void {
        const ask = Money.parse(text, root.known, root.home, evaluate);
        const now = Date.now();
        if (Money.coinsIn(ask) && Money.stale(root.coinsFetched, now, root.coinsStaleAfter) && now - root.coinsTried > 30000 && !coinFetcher.running) {
            root.coinsTried = now;
            coinFetcher.running = true;
        }
    }

    function keep(): void {
        store.setText(JSON.stringify({
            date: root.date,
            fetched: root.fetched,
            rates: root.rates,
            coins: root.coins,
            coinsFetched: root.coinsFetched
        }));
    }

    onLinkedChanged: if (root.linked && root.stale())
        root.refresh()

    Timer {
        interval: 3600 * 1000
        repeat: true
        running: true
        onTriggered: if (root.stale())
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
                root.keep();
            }
        }

        onExited: code => {
            if (code !== 0)
                retry.restart();
        }
    }

    Process {
        id: coinFetcher

        command: ["curl", "-fsSL", "--max-time", "15", Money.coinFeed()]

        stdout: StdioCollector {
            onStreamFinished: {
                const got = Money.readCoins(text);
                if (!got)
                    return;
                root.coins = got;
                root.coinsFetched = Date.now();
                root.keep();
            }
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
                root.coins = kept.coins ?? {};
                root.coinsFetched = kept.coinsFetched ?? 0;
            } catch (e) {}
            if (root.stale())
                root.refresh();
        }
        onLoadFailed: root.refresh()
    }
}
