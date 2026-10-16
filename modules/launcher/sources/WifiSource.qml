import QtQuick
import qs.config
import qs.services
import "../system-asks.js" as Asks
import "../../../services/ranking.js" as Ranking

QtObject {
    id: root

    required property var search

    readonly property var settings: Config.values.launcher.systemControls ?? {}
    readonly property var names: Network.networks.map(n => n.name)
    readonly property var asked: root.settings.wifi !== false && Network.available ? Asks.wifiAsk(root.search.text, root.names) : null

    readonly property bool listsWifi: root.asked !== null
    readonly property bool intent: root.asked !== null

    onIntentChanged: Network.setViewing(root, root.intent)
    Component.onDestruction: Network.setViewing(root, false)

    readonly property var kinds: ["wifipower", "wifinet", "wifiscan"]

    readonly property var caps: ({
            wifi: 14
        })

    readonly property var barIcons: ["signal_wifi_0_bar", "network_wifi_1_bar", "network_wifi_2_bar", "network_wifi_3_bar", "signal_wifi_4_bar"]
    readonly property var lockedIcons: ["signal_wifi_0_bar", "network_wifi_1_bar_locked", "network_wifi_2_bar_locked", "network_wifi_3_bar_locked", "network_wifi_locked"]

    function iconFor(n: var): string {
        const bars = Math.max(0, Math.min(4, Math.ceil(Network.percent(n) / 25)));
        return (Network.secured(n) && !n.known ? root.lockedIcons : root.barIcons)[bars];
    }

    function detailFor(n: var): string {
        const state = Network.stateLabel(n);
        return [state, n.known && !n.connected ? "saved" : "", Network.securityLabel(n), `${Network.percent(n)}%`].filter(Boolean).join(" · ");
    }

    function powerRow(): var {
        const ask = root.asked;
        const arming = root.search.armed === "wifipower";
        const on = Network.enabled;
        const label = arming ? "Press Enter again to turn Wi-Fi off" : ask?.power === true ? "Turn Wi-Fi on" : ask?.power === false ? "Turn Wi-Fi off" : "Wi-Fi";
        return {
            key: "wifipower",
            kind: "wifipower",
            power: ask?.power,
            armed: arming,
            label: label,
            detail: arming ? "" : on ? Network.activeName || "not connected" : "off",
            icon: Network.wifiIcon(),
            toggle: on,
            score: Infinity
        };
    }

    function networkRow(n: var): var {
        const arming = root.search.armed === `wifioff:${n.name}` || root.search.armed === `wififorget:${n.name}`;
        const forgetting = root.search.armed === `wififorget:${n.name}`;
        return {
            key: `wifinet:${n.name}`,
            kind: "wifinet",
            name: n.name,
            armed: arming,
            label: !arming ? n.name : forgetting ? `Press Enter again to forget ${n.name}` : `Press Enter again to disconnect from ${n.name}`,
            detail: arming ? "" : root.detailFor(n),
            icon: root.iconFor(n),
            toggle: !!n.connected,
            score: Infinity
        };
    }

    readonly property var rows: {
        const ask = root.asked;
        if (!ask)
            return [];
        const out = [];
        if (!ask.name || ask.power !== undefined)
            out.push(root.powerRow());
        if (!Network.enabled || ask.power !== undefined)
            return out;
        const wanted = ask.name;
        const found = Network.networks.filter(n => !wanted || Ranking.place(n.name, wanted) > 0);
        for (const n of found)
            out.push(root.networkRow(n));
        if (!found.length)
            out.push({
                key: "wifiscan",
                kind: "wifiscan",
                label: wanted ? `No network called ${wanted} in range` : "Looking for networks",
                detail: "",
                icon: "wifi_find",
                score: Infinity
            });
        return out;
    }

    readonly property var groups: [
        {
            key: "wifi",
            title: "Wi-Fi",
            items: root.rows
        }
    ]

    function needsCard(n: var): bool {
        return !!n && !n.known && Network.secured(n);
    }

    function join(name: string): void {
        const n = Network.find(name);
        const screen = root.search.screenName;
        if (root.needsCard(n))
            root.search.leave(() => WifiJoin.join(name, screen));
        else
            WifiJoin.join(name, screen);
    }

    function activate(row: var): void {
        switch (row.kind) {
        case "wifipower":
            {
                const want = row.power ?? !Network.enabled;
                if (want === Network.enabled)
                    return;
                if (want) {
                    Network.setEnabled(true);
                } else if (root.search.armed === "wifipower") {
                    root.search.armed = "";
                    Network.setEnabled(false);
                } else {
                    root.search.armed = "wifipower";
                }
                return;
            }
        case "wifinet":
            {
                const n = Network.find(row.name);
                if (!n)
                    return;
                if (root.search.armed === `wififorget:${row.name}`) {
                    root.search.armed = "";
                    Network.forget(n);
                } else if (root.search.armed === `wifioff:${row.name}`) {
                    root.search.armed = "";
                    n.disconnect();
                } else if (n.connected) {
                    root.search.armed = `wifioff:${row.name}`;
                } else {
                    root.join(row.name);
                }
                return;
            }
        }
    }

    function actionsFor(row: var): var {
        if (row.kind === "wifipower")
            return [
                {
                    icon: (row.power ?? !Network.enabled) ? "wifi" : "wifi_off",
                    label: (row.power ?? !Network.enabled) ? "Turn on" : "Turn off",
                    run: () => root.activate(row)
                }
            ];
        if (row.kind !== "wifinet")
            return [];
        const n = Network.find(row.name);
        if (!n)
            return [];
        const name = row.name;
        const acts = [];
        if (n.connected)
            acts.push({
                icon: "link_off",
                label: "Disconnect",
                run: () => root.activate(row)
            });
        else
            acts.push({
                icon: root.needsCard(n) ? "password" : "wifi",
                label: Network.enterprise(n) && !n.known ? "Sign in" : "Join",
                run: () => root.activate(row)
            });
        if (n.known)
            acts.push({
                icon: "delete",
                label: "Forget",
                tucked: true,
                run: () => root.search.armed = `wififorget:${name}`
            });
        return acts;
    }
}
