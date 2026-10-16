import QtQuick
import Quickshell
import qs.services
import "../../../services/ranking.js" as Ranking
import "../../../services/ssh-hosts.js" as Logic

QtObject {
    id: root

    required property var search

    readonly property var kinds: ["ssh"]

    readonly property bool usable: SshHosts.enabled && SshHosts.installed
    readonly property var asked: root.usable ? Logic.ask(root.search.text) : null
    readonly property bool intent: root.asked !== null
    readonly property bool started: root.search.started

    onStartedChanged: if (root.started && root.usable)
        SshHosts.refresh()
    onAskedChanged: if (root.asked)
        SshHosts.refresh()

    readonly property var caps: ({
            ssh: root.asked ? 14 : 2
        })

    function keyOf(host: var): string {
        return host.known && host.port ? `${host.name}:${host.port}` : host.name;
    }

    function row(host: var, score: real, label: string): var {
        return {
            key: `ssh:${root.keyOf(host)}`,
            kind: "ssh",
            host: host,
            label: label,
            detail: Logic.detailOf(host),
            icon: "dns",
            score: score
        };
    }

    function remembered(hosts: var): var {
        const now = Date.now();
        return hosts.map((host, at) => ({
                    host: host,
                    at: at,
                    used: LauncherMemory.bonusOf(`ssh:${root.keyOf(host)}`, now)
                })).sort((a, b) => b.used - a.used || a.at - b.at).map(h => h.host);
    }

    readonly property var rows: {
        const asked = root.asked;
        if (!asked) {
            if (!root.usable || root.search.text.length < 3)
                return [];
            return Logic.ambient(SshHosts.hosts, root.search.text).map(host => root.row(host, 0.35, `ssh ${host.name}`));
        }
        const words = asked.words;
        const found = Logic.matching(SshHosts.hosts, words, Ranking.place, 14);
        const ordered = words ? found : root.remembered(found);
        const out = ordered.map((host, i) => root.row(host, i === 0 ? Infinity : 100 - i * 0.01, host.name));
        if (words && Logic.validTarget(words) && (!found.length || /[@.:]/.test(words)) && !found.some(h => h.name.toLowerCase() === words.toLowerCase()))
            out.push(root.row({
                name: words,
                address: "",
                user: "",
                port: "",
                jump: "",
                known: false
            }, out.length ? 99 : Infinity, `Connect to ${words}`));
        return out;
    }

    readonly property var groups: [
        {
            key: "ssh",
            title: "SSH",
            items: root.rows
        }
    ]

    function rowById(id: string): var {
        if (!id.startsWith("ssh:"))
            return null;
        const name = id.slice(4);
        const host = SshHosts.hosts.find(h => root.keyOf(h) === name);
        if (host)
            return root.row(host, 1, host.name);
        return Logic.validTarget(name) ? root.row({
            name: name,
            address: "",
            user: "",
            port: "",
            jump: "",
            known: false
        }, 1, name) : null;
    }

    function activate(row: var): void {
        const host = row.host;
        root.search.launch(() => SshHosts.connect(host));
    }

    function actionsFor(row: var): var {
        const host = row.host;
        const acts = [
            {
                icon: "terminal",
                label: `Connect to ${host.name}`,
                short: "Connect",
                run: () => root.activate(row)
            },
            {
                icon: "content_copy",
                label: "Copy command",
                short: "Copy",
                run: () => root.search.leave(() => Clipboard.copy({
                            text: Logic.commandText(host)
                        }))
            }
        ];
        if (host.address)
            acts.push({
                icon: "alternate_email",
                label: "Copy address",
                tucked: true,
                run: () => root.search.leave(() => Clipboard.copy({
                            text: host.address
                        }))
            });
        return acts;
    }

    function complete(row: var): bool {
        root.search.retype(`ssh ${row.host.name}`);
        return true;
    }
}
