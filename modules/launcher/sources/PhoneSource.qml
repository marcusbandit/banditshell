import QtQuick
import Quickshell
import qs.services
import "../../../services/ranking.js" as Ranking
import "../../../services/phone.js" as Logic
import "../search.js" as Search

QtObject {
    id: root

    required property var search

    readonly property var kinds: ["phone"]

    readonly property var asked: Phone.enabled ? Logic.ask(root.search.text) : null

    onAskedChanged: {
        if (!root.asked) {
            Phone.drop();
            return;
        }
        Phone.want();
        if (root.asked.action === "list" || root.asked.action === "send" || root.asked.action === "file")
            LatestFiles.refresh("downloads");
    }

    readonly property var found: root.asked ? Logic.matching(Phone.devices, root.asked, Ranking.place) : []
    readonly property bool intent: !!root.asked && (root.asked.generic || root.found.length > 0)

    readonly property var caps: ({
            phone: 10
        })

    readonly property var clipboardTop: Clipboard.entries[0] ?? null

    function suggestedFile(): string {
        const copied = (root.clipboardTop?.paths ?? [])[0] ?? "";
        const latest = (LatestFiles.lists.downloads ?? []).find(f => !f.dir)?.path ?? "";
        return Search.shortPath(copied || latest, Files.home);
    }

    function suggestedLink(): string {
        const text = String(root.clipboardTop?.text ?? "").trim();
        return /^https?:\/\/\S+$/i.test(text) && text.length < 2000 ? text : "";
    }

    function made(device: var, action: string, label: string, icon: string, extra: var): var {
        return Object.assign({
            key: `phone:${action}:${device.id}`,
            kind: "phone",
            device: device,
            action: action,
            label: label,
            detail: Logic.detailOf(device),
            icon: icon,
            score: 100
        }, extra ?? {});
    }

    function deviceRow(device: var): var {
        return root.made(device, "device", device.name, Logic.iconOf(device), {});
    }

    function ringRow(device: var): var {
        return root.made(device, "ring", `Ring ${device.name}`, "mobile_vibrate", {
            detail: Logic.batteryText(device)
        });
    }

    function pingRow(device: var): var {
        return root.made(device, "ping", `Ping ${device.name}`, "notifications_active", {
            detail: ""
        });
    }

    function clipboardRow(device: var): var {
        return root.made(device, "clipboard", `Send clipboard to ${device.name}`, "content_paste_go", {
            detail: ""
        });
    }

    function batteryRow(device: var): var {
        return root.made(device, "battery", device.charge >= 0 ? `${device.name} is at ${device.charge}%` : `${device.name} battery`, device.charging ? "battery_charging_full" : "battery_full", {
            detail: device.charge >= 0 ? (device.charging ? "charging" : "not charging") : "no battery reading"
        });
    }

    function fileRow(device: var): var {
        return root.made(device, "file", `Send a file to ${device.name}`, "upload_file", {
            detail: "",
            ask: {
                prompt: `File to send to ${device.name}`,
                icon: "upload_file",
                suggestion: root.suggestedFile(),
                take: text => {
                    const path = Logic.expandPath(text.trim(), Files.home);
                    const id = device.id;
                    root.search.launch(() => Phone.run(id, "share", {
                            kind: "file",
                            value: path
                        }));
                }
            }
        });
    }

    function linkRow(device: var): var {
        return root.made(device, "link", `Share a link with ${device.name}`, "link", {
            detail: "",
            ask: {
                prompt: `Link to share with ${device.name}`,
                icon: "link",
                suggestion: root.suggestedLink(),
                take: text => {
                    const payload = Logic.linkFrom(text);
                    const id = device.id;
                    root.search.launch(() => Phone.run(id, "share", payload));
                }
            }
        });
    }

    function shareRow(device: var, payload: var): var {
        const shown = Logic.payloadLabel(payload);
        const value = payload.kind === "file" ? Logic.expandPath(payload.value, Files.home) : payload.value;
        return root.made(device, "share", payload.kind === "link" ? `Share ${shown} with ${device.name}` : payload.kind === "file" ? `Send ${shown} to ${device.name}` : `Send “${shown}” to ${device.name}`, payload.kind === "link" ? "link" : payload.kind === "file" ? "upload_file" : "text_fields", {
            key: `phone:share:${device.id}:${payload.kind}`,
            detail: "",
            payload: {
                kind: payload.kind,
                value: value
            }
        });
    }

    function unreachableRow(device: var): var {
        return root.made(device, "away", device.name, "mobile_off", {});
    }

    function note(key: string, label: string, icon: string, extra: var): var {
        return Object.assign({
            key: `phone:${key}`,
            kind: "phone",
            action: key,
            label: label,
            detail: "",
            icon: icon,
            score: Infinity
        }, extra ?? {});
    }

    function rowsFor(device: var, asked: var): var {
        switch (asked.action) {
        case "ring":
            return [root.ringRow(device)];
        case "ping":
            return [root.pingRow(device)];
        case "battery":
            return [root.batteryRow(device)];
        case "clipboard":
            return [root.clipboardRow(device)];
        case "file":
            return [root.fileRow(device)];
        case "link":
            return [root.linkRow(device)];
        case "send":
            return [root.clipboardRow(device), root.fileRow(device), root.linkRow(device)];
        case "share":
            return Logic.shareable(asked.payload) ? [root.shareRow(device, asked.payload)] : [];
        }
        return [root.deviceRow(device), root.fileRow(device), root.linkRow(device)];
    }

    readonly property var rows: {
        const asked = root.asked;
        if (!asked)
            return [];
        if (!Phone.installed)
            return asked.generic ? [root.note("install", Phone.installing === "trying" ? "Installing KDE Connect" : "Install KDE Connect", "download", {})] : [];
        if (!Phone.read)
            return asked.generic ? [root.note("reading", "Looking for your phone", "hourglass_top", {})] : [];
        const reachable = root.found.filter(d => d.reachable);
        const away = root.found.filter(d => !d.reachable);
        if (!root.found.length)
            return asked.generic ? [root.note("none", "No paired phone", "mobile_off", {})] : [];
        const out = [];
        for (const device of reachable)
            out.push(...root.rowsFor(device, asked));
        for (const device of away)
            out.push(root.unreachableRow(device));
        return out.map((r, i) => Object.assign(r, {
                    score: i === 0 ? Infinity : 100 - i * 0.01
                }));
    }

    readonly property var groups: [
        {
            key: "phone",
            title: "Phone",
            items: root.rows
        }
    ]

    function rowById(id: string): var {
        const m = /^phone:(ring|ping|clipboard|battery|device):([A-Za-z0-9_-]+)$/.exec(id);
        if (!m)
            return null;
        const device = Phone.devices.find(d => d.id === m[2]) ?? {
            id: m[2],
            name: Phone.nameOf(m[2]),
            reachable: true,
            type: "phone",
            charge: -1,
            charging: false
        };
        switch (m[1]) {
        case "ring":
            return root.ringRow(device);
        case "ping":
            return root.pingRow(device);
        case "battery":
            return root.batteryRow(device);
        case "device":
            return root.deviceRow(device);
        }
        return root.clipboardRow(device);
    }

    function send(device: var, action: string, payload: var): void {
        const id = device.id;
        root.search.leave(() => Phone.run(id, action, payload));
    }

    function activate(row: var): void {
        const first = root.actionsFor(row)[0];
        if (first)
            first.run();
    }

    function actionsFor(row: var): var {
        switch (row.action) {
        case "install":
            return [
                {
                    icon: "download",
                    label: "Install KDE Connect",
                    short: "Install",
                    run: () => Phone.install()
                }
            ];
        case "none":
            return [
                {
                    icon: "open_in_new",
                    label: "Open KDE Connect",
                    short: "Open",
                    run: () => root.search.launch(() => Phone.openApp())
                },
                {
                    icon: "refresh",
                    label: "Look again",
                    run: () => Phone.lookAgain()
                }
            ];
        case "reading":
            return [];
        case "away":
            return [
                {
                    icon: "refresh",
                    label: `Look for ${row.device.name} again`,
                    short: "Look again",
                    run: () => Phone.lookAgain()
                },
                {
                    icon: "open_in_new",
                    label: "Open KDE Connect",
                    short: "Open",
                    run: () => root.search.launch(() => Phone.openApp())
                }
            ];
        }
        const device = row.device;
        const ring = {
            icon: "mobile_vibrate",
            label: `Ring ${device.name}`,
            short: "Ring",
            button: row.action === "device",
            run: () => root.send(device, "ring", null)
        };
        const ping = {
            icon: "notifications_active",
            label: `Ping ${device.name}`,
            short: "Ping",
            run: () => root.send(device, "ping", null)
        };
        const clipboard = {
            icon: "content_paste_go",
            label: `Send clipboard to ${device.name}`,
            short: "Clipboard",
            run: () => root.send(device, "clipboard", null)
        };
        switch (row.action) {
        case "ring":
            return [ring];
        case "ping":
            return [ping];
        case "clipboard":
            return [clipboard];
        case "battery":
            return [
                {
                    icon: "check",
                    label: "Close",
                    run: () => root.search.leave(() => {})
                }
            ];
        case "share":
            return [
                {
                    icon: row.icon,
                    label: row.label,
                    short: "Send",
                    run: () => root.send(device, "share", row.payload)
                }
            ];
        case "file":
        case "link":
            return [];
        }
        return [ring, ping, clipboard];
    }

    function complete(row: var): bool {
        if (!row.device || row.action !== "ring" && row.action !== "ping")
            return false;
        root.search.retype(`${row.action} ${row.device.name}`);
        return true;
    }
}
