import QtQuick
import Quickshell
import qs.config
import qs.services
import "../system-asks.js" as Asks
import "../../../services/ranking.js" as Ranking
import "../../../services/tailscale.js" as TailscaleLogic

QtObject {
    id: root

    required property var search

    readonly property var settings: Config.values.launcher.systemControls ?? {}
    readonly property bool enabled: root.settings.vpn !== false
    readonly property string text: root.search.text
    readonly property bool typed: root.search.query !== ""

    readonly property var vpnAsked: root.enabled ? Asks.vpnAsk(root.text) : null
    readonly property var tailAsked: root.enabled ? Asks.tailscaleAsk(root.text) : null
    readonly property bool near: root.enabled && !root.vpnAsked && !root.tailAsked && Asks.vpnNear(root.text)
    readonly property bool watching: root.vpnAsked !== null || root.tailAsked !== null || root.near

    readonly property bool intent: root.vpnAsked !== null || root.tailAsked !== null

    onWatchingChanged: {
        Tailscale.setViewing(root, root.watching);
        if (root.watching) {
            ToolInstaller.probe();
            Tunnels.refresh();
        }
    }
    Component.onDestruction: Tailscale.setViewing(root, false)

    readonly property var kinds: ["vpn", "vpnadd", "tailscale", "tailscaleinstall", "tailscaleexit", "tailscalepeer", "tailscalenone"]

    readonly property var phrases: [
        {
            head: "tailscale ",
            picks: ["up", "down", "exit node"]
        }
    ]

    readonly property var caps: ({
            vpn: 10,
            tailscale: 16
        })

    function tunnelDetail(t: var): string {
        const state = t.busy ? (t.on ? "connecting" : "disconnecting") : t.on ? "connected" : "";
        return [state, t.kind === "wireguard" ? "WireGuard" : "VPN", t.trouble].filter(Boolean).join(" · ");
    }

    function tunnelRow(t: var, score: real): var {
        const arming = root.search.armed === `vpnoff:${t.uuid}`;
        return {
            key: `vpn:${t.uuid}`,
            kind: "vpn",
            uuid: t.uuid,
            armed: arming,
            label: arming ? `Press Enter again to disconnect ${t.name}` : t.name,
            detail: arming ? "" : root.tunnelDetail(t),
            icon: t.kind === "wireguard" ? "vpn_key" : "vpn_lock",
            toggle: t.on,
            score: score
        };
    }

    readonly property var vpnRows: {
        const ask = root.vpnAsked;
        if (!root.enabled)
            return [];
        if (!ask) {
            if (root.text.length < 3)
                return [];
            return Tunnels.list.filter(t => Ranking.place(t.name, root.text) > 0).map(t => root.tunnelRow(t, 0.4));
        }
        const rows = Tunnels.list.filter(t => !ask.name || Ranking.place(t.name, ask.name) > 0).map(t => root.tunnelRow(t, Infinity));
        if (!rows.length && !ask.name)
            rows.push({
                key: "vpnadd",
                kind: "vpnadd",
                label: "Add a VPN connection",
                detail: "",
                icon: "add",
                score: Infinity
            });
        return rows;
    }

    function tailscaleRow(score: real): var {
        const arming = root.search.armed === "tailscaleoff";
        const ask = root.tailAsked;
        const running = Tailscale.running;
        const label = arming ? "Press Enter again to turn Tailscale off" : Tailscale.signedOut ? "Sign in to Tailscale" : ask?.kind === "up" ? "Turn Tailscale on" : ask?.kind === "down" ? "Turn Tailscale off" : "Tailscale";
        const self = Tailscale.status?.self;
        const exit = Tailscale.peers.find(p => p.exitActive) ?? null;
        const busy = Tailscale.busy === "up" ? "connecting" : Tailscale.busy === "down" ? "disconnecting" : Tailscale.busy === "operator" ? "asking for permission" : Tailscale.busy === "signin" ? (Tailscale.openedUrl ? "waiting for sign in" : "opening the sign in page") : "";
        return {
            key: "tailscale:status",
            kind: "tailscale",
            armed: arming,
            label: label,
            detail: arming ? "" : [busy || Tailscale.stateText, running ? self?.address ?? "" : "", running && exit ? `through ${exit.name}` : ""].filter(Boolean).join(" · "),
            icon: "hub",
            toggle: running,
            score: score
        };
    }

    function exitRow(peer: var, score: real): var {
        const busy = Tailscale.busy === `exit:${peer.id}` || peer.exitActive && Tailscale.busy === "exit:";
        return {
            key: `tailscale:exit:${peer.id}`,
            kind: "tailscaleexit",
            peerId: peer.id,
            label: peer.name,
            detail: [busy ? "switching" : peer.exitActive ? "exit node in use" : "exit node", peer.online ? "" : "offline", peer.os].filter(Boolean).join(" · "),
            icon: peer.exitActive ? "public" : "public_off",
            toggle: peer.exitActive,
            score: score
        };
    }

    function peerRow(peer: var, score: real): var {
        return {
            key: `tailscale:peer:${peer.id}`,
            kind: "tailscalepeer",
            peerId: peer.id,
            address: peer.address,
            dns: peer.dns,
            online: peer.online,
            label: peer.name,
            detail: [peer.online ? "online" : "offline", peer.os, peer.address].filter(Boolean).join(" · "),
            icon: peer.os === "android" || peer.os === "iOS" ? "devices" : "computer",
            score: score
        };
    }

    readonly property var tailscaleRows: {
        const ask = root.tailAsked;
        const listing = ask !== null || root.vpnAsked !== null && !root.vpnAsked.name;
        if (!root.enabled || !listing && !root.near)
            return [];
        if (!Tailscale.installed)
            return ask && ToolInstaller.probed && ToolInstaller.canInstall("tailscale") ? [
                {
                    key: "tailscaleinstall",
                    kind: "tailscaleinstall",
                    label: ToolInstaller.installLabel("tailscale"),
                    detail: "",
                    icon: "download",
                    score: Infinity
                }
            ] : [];
        const score = root.near ? 0.4 : Infinity;
        const out = [root.tailscaleRow(score)];
        if (!ask || !Tailscale.running || ask.kind === "up" || ask.kind === "down")
            return out;
        const exits = Tailscale.exitNodes.filter(p => TailscaleLogic.matches(p, ask.name));
        for (const peer of exits)
            out.push(root.exitRow(peer, score));
        if (ask.kind === "exit") {
            if (!exits.length)
                out.push({
                    key: "tailscalenone",
                    kind: "tailscalenone",
                    label: ask.name ? `No exit node called ${ask.name}` : "No device offers an exit node",
                    detail: "",
                    icon: "public_off",
                    score: score
                });
            return out;
        }
        for (const peer of Tailscale.peers.filter(p => !p.exitOption && !p.exitActive && TailscaleLogic.matches(p, ask.name)))
            out.push(root.peerRow(peer, score));
        return out;
    }

    readonly property var groups: [
        {
            key: "vpn",
            title: "VPN",
            items: root.vpnRows
        },
        {
            key: "tailscale",
            title: "Tailscale",
            items: root.tailscaleRows
        }
    ]

    function rowById(id: string): var {
        if (!root.enabled)
            return null;
        if (id === "tailscale:status")
            return Tailscale.installed ? root.tailscaleRow(1) : null;
        if (id.startsWith("vpn:")) {
            const tunnel = Tunnels.list.find(t => `vpn:${t.uuid}` === id);
            return tunnel ? root.tunnelRow(tunnel, 1) : null;
        }
        if (id.startsWith("tailscale:exit:")) {
            const peer = Tailscale.exitNodes.find(p => `tailscale:exit:${p.id}` === id);
            return peer ? root.exitRow(peer, 1) : null;
        }
        return null;
    }

    function setTailscale(on: bool): void {
        if (on)
            Tailscale.up();
        else
            Tailscale.down();
    }

    function activate(row: var): void {
        switch (row.kind) {
        case "vpn":
            {
                const tunnel = Tunnels.list.find(t => t.uuid === row.uuid);
                if (!tunnel)
                    return;
                if (tunnel.on && root.typed && root.search.armed !== `vpnoff:${tunnel.uuid}`) {
                    root.search.armed = `vpnoff:${tunnel.uuid}`;
                    return;
                }
                root.search.armed = "";
                Tunnels.set(tunnel, !tunnel.on);
                return;
            }
        case "vpnadd":
            {
                const screen = root.search.screenName;
                root.search.leave(() => Settings.openAt(screen, "vpn", ""));
                return;
            }
        case "tailscale":
            {
                const kind = root.tailAsked?.kind ?? "";
                const want = kind === "up" ? true : kind === "down" ? false : !Tailscale.running;
                if (want === Tailscale.running && !Tailscale.signedOut)
                    return;
                if (!want && root.typed && root.search.armed !== "tailscaleoff") {
                    root.search.armed = "tailscaleoff";
                    return;
                }
                root.search.armed = "";
                root.setTailscale(want);
                return;
            }
        case "tailscaleinstall":
            ToolInstaller.install("tailscale");
            return;
        case "tailscaleexit":
            {
                const peer = Tailscale.exitNodes.find(p => p.id === row.peerId);
                if (peer)
                    Tailscale.useExitNode(peer.exitActive ? null : peer);
                return;
            }
        case "tailscalepeer":
            {
                const address = row.address;
                root.search.leave(() => Files.copyText(address));
                return;
            }
        }
    }

    function sshInto(name: string): void {
        if (!/^[A-Za-z0-9.-]+$/.test(name))
            return;
        root.search.launch(() => Quickshell.execDetached([`${Quickshell.shellDir}/scripts/in-terminal.sh`, `exec ssh -- '${name}'`]));
    }

    function actionsFor(row: var): var {
        switch (row.kind) {
        case "vpn":
            return [
                {
                    icon: row.toggle ? "link_off" : "vpn_lock",
                    label: row.toggle ? "Disconnect" : "Connect",
                    run: () => root.activate(row)
                }
            ];
        case "vpnadd":
            return [
                {
                    icon: "add",
                    label: "Add",
                    run: () => root.activate(row)
                }
            ];
        case "tailscale":
            {
                const acts = [
                    {
                        icon: Tailscale.running ? "link_off" : "hub",
                        label: Tailscale.signedOut ? "Sign in" : Tailscale.running ? "Turn off" : "Turn on",
                        run: () => root.activate(row)
                    }
                ];
                if (Tailscale.needsOperator)
                    acts.push({
                        icon: "admin_panel_settings",
                        label: "Allow control",
                        run: () => Tailscale.allowOperator()
                    });
                if (Tailscale.running && Tailscale.exitNode)
                    acts.push({
                        icon: "public_off",
                        label: "Stop exit node",
                        run: () => Tailscale.useExitNode(null)
                    });
                return acts;
            }
        case "tailscaleinstall":
            return [
                {
                    icon: "download",
                    label: "Install",
                    run: () => root.activate(row)
                }
            ];
        case "tailscaleexit":
            {
                const acts = [
                    {
                        icon: row.toggle ? "public_off" : "public",
                        label: row.toggle ? "Stop using it" : "Use as exit node",
                        run: () => root.activate(row)
                    }
                ];
                if (Tailscale.needsOperator)
                    acts.push({
                        icon: "admin_panel_settings",
                        label: "Allow control",
                        run: () => Tailscale.allowOperator()
                    });
                return acts;
            }
        case "tailscalepeer":
            {
                const acts = [
                    {
                        icon: "content_copy",
                        label: "Copy address",
                        short: "Copy",
                        run: () => root.activate(row)
                    }
                ];
                const dns = row.dns;
                if (dns)
                    acts.push({
                        icon: "content_copy",
                        label: "Copy name",
                        tucked: true,
                        run: () => root.search.leave(() => Files.copyText(dns))
                    });
                if (row.online && dns)
                    acts.push({
                        icon: "terminal",
                        label: "SSH",
                        run: () => root.sshInto(dns)
                    });
                return acts;
            }
        }
        return [];
    }
}
