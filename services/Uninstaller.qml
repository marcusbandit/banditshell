pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string script: `${Quickshell.shellDir}/scripts/uninstall-app.sh`

    property var plans: ({})

    property string busy: ""

    readonly property var sources: ({
            pacman: "pacman",
            apt: "apt",
            dnf: "dnf",
            zypper: "zypper",
            xbps: "xbps",
            apk: "apk",
            "flatpak-user": "Flatpak",
            "flatpak-system": "Flatpak",
            snap: "Snap",
            steam: "Steam",
            appimage: "AppImage",
            entry: "launcher shortcut"
        })

    readonly property var refusals: ({
            1: "no desktop file",
            3: "not from a package"
        })

    function store(id: string, plan: var): void {
        const next = Object.assign({}, root.plans);
        if (plan)
            next[id] = plan;
        else
            delete next[id];
        root.plans = next;
    }

    function plan(entry: var): void {
        if (!entry || root.plans[entry.id]?.how)
            return;
        root.store(entry.id, {
            looking: true
        });
        finder.createObject(root, {
            entryId: entry.id,
            command: [root.script, "find", entry.id],
            running: true
        });
    }

    function detailFor(id: string): string {
        const plan = root.plans[id];
        if (!plan || plan.looking)
            return "";
        if (plan.refused)
            return plan.refused;
        if (plan.how === "entry")
            return root.sources.entry;
        return `${root.sources[plan.how] ?? plan.how} · ${plan.how === "appimage" ? plan.package.split("/").pop() : plan.package}`;
    }

    function ready(id: string): bool {
        return !!root.plans[id]?.how && !root.busy;
    }

    function remove(entry: var): void {
        const plan = root.plans[entry?.id];
        if (!plan?.how || root.busy)
            return;
        root.busy = entry.id;
        Polkit.expect(`Uninstall ${entry.name}`, plan.package);
        remover.entryId = entry.id;
        remover.name = entry.name;
        remover.icon = entry.icon ?? "";
        remover.how = plan.how;
        remover.command = [root.script, "remove", entry.id];
        remover.begin();
    }

    function notify(icon: string, summary: string, body: string): void {
        Quickshell.execDetached(["notify-send", "-a", "banditshell", "-i", icon || "delete", summary, body]);
    }

    Component {
        id: finder

        Process {
            id: run

            property string entryId: ""
            property int code: -1
            property bool read: false

            function settle(): void {
                if (run.code < 0 || !run.read)
                    return;
                const parts = found.text.trim().split("\t");
                root.store(run.entryId, run.code === 0 && parts.length >= 3 ? {
                    how: parts[0],
                    package: parts[1],
                    file: parts[2]
                } : {
                    refused: root.refusals[run.code] ?? "could not look it up"
                });
                run.destroy();
            }

            stdout: StdioCollector {
                id: found

                onStreamFinished: {
                    run.read = true;
                    run.settle();
                }
            }

            onExited: code => {
                run.code = code;
                run.settle();
            }
        }
    }

    Process {
        id: remover

        property string entryId: ""
        property string name: ""
        property string icon: ""
        property string how: ""
        property int code: -1
        property int streams: 0

        function begin(): void {
            remover.code = -1;
            remover.streams = 0;
            remover.running = true;
        }

        function settle(): void {
            if (remover.code < 0 || remover.streams < 2)
                return;
            const code = remover.code;
            remover.code = -1;
            Polkit.forget();
            root.busy = "";
            root.store(remover.entryId, null);
            const last = (complained.text || said.text).trim().split("\n").pop() ?? "";
            if (code === 0) {
                if (remover.how !== "steam")
                    root.notify(remover.icon, `${remover.name} is uninstalled`, "");
            } else if (code === 5) {
                root.notify(remover.icon, `${remover.name} stays`, said.text.trim());
            } else if (code === 4 || code === 127) {
                Quickshell.execDetached([`${Quickshell.shellDir}/scripts/in-terminal.sh`, `'${root.script}' ask '${remover.entryId.replace(/'/g, "'\\''")}'`]);
            } else if (code !== 126) {
                root.notify(remover.icon, `${remover.name} did not uninstall`, last);
            }
        }

        stdout: StdioCollector {
            id: said

            onStreamFinished: {
                remover.streams += 1;
                remover.settle();
            }
        }

        stderr: StdioCollector {
            id: complained

            onStreamFinished: {
                remover.streams += 1;
                remover.settle();
            }
        }

        onExited: code => {
            remover.code = code;
            remover.settle();
        }
    }
}
