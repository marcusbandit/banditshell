import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import "../system-asks.js" as Asks
import "../../../services/ranking.js" as Ranking
import "../../../services/wifilist.js" as WifiList

QtObject {
    id: root

    required property var search

    readonly property var settings: Config.values.launcher.systemControls ?? {}
    readonly property var names: Network.networks.map(n => n.name)
    readonly property bool usable: root.settings.wifi !== false && Network.available
    readonly property var asked: root.usable ? Asks.wifiAsk(root.search.text, root.names) : null
    readonly property var pasted: root.usable && !root.asked ? WifiList.parseCard(root.search.text) : null

    readonly property bool listsWifi: root.asked !== null
    readonly property bool intent: root.asked !== null || root.pasted !== null

    property var order: null
    property var handoff: null

    readonly property bool opening: !!root.handoff

    readonly property Component page: Component {
        WifiPage {
            source: root
            order: root.order
        }
    }

    function present(order: var, title: string): void {
        if (!root.search.presents || root.search.presenting)
            return;
        root.order = order;
        root.search.present({
            component: root.page,
            name: "wifi",
            text: title
        });
    }

    function openPage(): void {
        const handoff = root.handoff;
        root.handoff = null;
        if (handoff)
            root.present(handoff, handoff.card?.ssid ?? "Join with a QR code");
    }

    function openNetwork(name: string): void {
        root.present({
            mode: "join",
            name: name
        }, name);
    }

    function openShare(): void {
        root.present({
            mode: "share"
        }, `Share ${Network.activeName}`);
    }

    function openScan(): void {
        root.present({
            mode: "scan"
        }, "Join with a QR code");
    }

    function openCard(card: var): void {
        root.present({
            mode: "join",
            card: card
        }, card.ssid);
    }

    function scanScreen(): void {
        const screen = root.search.screenName;
        root.search.leave(() => {
            screenReader.screen = screen;
            screenReader.command = [Quickshell.shellPath("scripts/wifi-qr.sh"), "screen", screen];
            screenReader.running = true;
        });
    }

    function screenRead(code: int, text: string): void {
        const card = WifiList.cardIn(text);
        const found = WifiList.codesIn(text).length;
        root.handoff = card ? {
            mode: "join",
            card: card
        } : {
            mode: "scan",
            note: code === 4 ? "Reading a code needs zxing-cpp" : code !== 0 ? "Could not take a picture of the screen" : found ? "The code on the screen is not a Wi-Fi network" : "No code on the screen"
        };
        Panels.open("launcher", {
            screen: screenReader.screen,
            text: "wifi qr"
        });
        Qt.callLater(() => root.search.openPending());
    }

    readonly property Process screenReader: Process {
        property string screen: ""

        stdout: StdioCollector {
            id: screenSaid
        }

        onExited: code => root.screenRead(code, screenSaid.text)
    }

    readonly property bool viewing: root.intent && root.search.active

    onViewingChanged: Qt.callLater(root.viewNetworks)

    function viewNetworks(): void {
        Network.setViewing(root, root.viewing);
    }
    Component.onDestruction: Network.setViewing(root, false)

    readonly property var kinds: ["wifipower", "wifinet", "wifiscan", "wifishare", "wifiqr", "wificode"]

    readonly property var caps: ({
            wifi: 14
        })

    readonly property var strengthIcons: ["wifi_1_bar", "wifi_2_bar", "wifi"]

    function iconFor(n: var): string {
        if (Network.secured(n) && !n.known)
            return "wifi_lock";
        const steps = root.strengthIcons.length;
        return root.strengthIcons[Math.min(steps - 1, Math.floor(Network.percent(n) / 100 * steps))];
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

    readonly property bool shareable: Network.connected && !Network.enterprise(Network.active)

    function shareRow(): var {
        return {
            key: "wifishare",
            kind: "wifishare",
            label: `Share ${Network.activeName}`,
            detail: Network.secured(Network.active) ? "QR code and password" : "QR code",
            icon: "qr_code_2",
            score: Infinity
        };
    }

    function scanRow(): var {
        return {
            key: "wifiqr",
            kind: "wifiqr",
            label: "Join with a QR code",
            detail: "",
            icon: "qr_code_scanner",
            score: Infinity
        };
    }

    function codeRow(card: var): var {
        const security = WifiList.qrSecurity(card.security);
        return {
            key: `wificode:${card.ssid}`,
            kind: "wificode",
            code: card,
            label: `Join ${card.ssid}`,
            detail: security === "open" ? "open network" : card.password ? "password included" : "no password in the code",
            icon: "qr_code",
            score: Infinity
        };
    }

    readonly property bool paging: root.search.presents

    readonly property var rows: {
        if (root.pasted)
            return root.paging && Network.enabled ? [root.codeRow(root.pasted)] : [];
        const ask = root.asked;
        if (!ask)
            return [];
        const out = [];
        if (ask.qr) {
            if (!Network.enabled)
                return [root.powerRow()];
            if (ask.qr !== "scan" && root.shareable)
                out.push(root.shareRow());
            if (ask.qr !== "share" && root.paging)
                out.push(root.scanRow());
            if (!out.length)
                out.push({
                    key: "wifiscan",
                    kind: "wifiscan",
                    label: Network.connected ? `${Network.activeName} signs in with a profile, and a code cannot carry one` : "Not on Wi-Fi, so there is nothing to share",
                    detail: "",
                    icon: "qr_code_2",
                    score: Infinity
                });
            return out;
        }
        if (!ask.name || ask.power !== undefined)
            out.push(root.powerRow());
        if (!Network.enabled || ask.power !== undefined)
            return out;
        if (!ask.name && root.shareable && root.paging)
            out.push(root.shareRow());
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
        if (!wanted && root.paging)
            out.push(root.scanRow());
        return out;
    }

    readonly property var prefixes: !root.usable ? [] : [
            {
                section: "System",
                word: "wifi",
                example: "wifi home",
                about: "Wi-Fi networks",
                icon: "wifi",
                also: ["wlan", "wireless"]
            }
        ]

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
        if (root.paging) {
            root.openNetwork(name);
            return;
        }
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
        case "wifishare":
            root.openShare();
            return;
        case "wifiqr":
            root.openScan();
            return;
        case "wificode":
            root.openCard(row.code);
            return;
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
                } else if (n.connected && !root.paging) {
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
        if (row.kind === "wifishare")
            return [
                {
                    icon: "qr_code_2",
                    label: "Show the code",
                    run: () => root.activate(row)
                }
            ];
        if (row.kind === "wifiqr" || row.kind === "wificode")
            return [
                {
                    icon: row.kind === "wifiqr" ? "qr_code_scanner" : "wifi",
                    label: row.kind === "wifiqr" ? "Scan" : "Join",
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
        if (n.connected && root.paging)
            acts.push({
                icon: "info",
                label: "Show details",
                run: () => root.openNetwork(name)
            }, {
                icon: "link_off",
                label: "Disconnect",
                run: () => root.search.armed = `wifioff:${name}`
            });
        else if (n.connected)
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
                alarm: true,
                tucked: true,
                run: () => root.search.armed = `wififorget:${name}`
            });
        return acts;
    }
}
