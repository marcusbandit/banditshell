pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "packages.js" as Packages

Singleton {
    id: root

    readonly property bool enabled: (Config.values.launcher.online ?? {}).packages !== false

    readonly property string searcher: `${Quickshell.shellDir}/scripts/package-search.sh`
    readonly property string installer: `${Quickshell.shellDir}/scripts/install-package.sh`
    readonly property string indexFile: `${Config.cacheDir}/online/flatpak-apps.json`

    property var tools: ({})
    property bool probed: false
    readonly property bool arch: !!root.tools.pacman
    readonly property bool flatpak: !!root.tools.flatpak
    readonly property string aurHelper: root.tools.paru ? "paru" : root.tools.yay ? "yay" : root.tools.pikaur ? "pikaur" : ""

    property var flatpakIndex: []
    property var flatpakInstalled: ({})
    property bool indexed: false

    property var jobs: ({})
    property string armed: ""
    property string term: ""

    property Lookup system: Lookup {
        delay: 250
        keep: 30
        freshFor: 10 * 60 * 1000
        commandFor: term => [root.searcher, "system", term]
        read: text => Packages.readSystem(text)
    }

    property Lookup aur: Lookup {
        delay: 500
        keep: 30
        freshFor: 30 * 60 * 1000
        commandFor: term => root.arch ? [root.searcher, "aur", term] : []
        read: text => Packages.readAur(text)
    }

    function wake(): void {
        if (!root.probed && !prober.running)
            prober.running = true;
        if (root.probed && root.flatpak && !root.indexed) {
            root.indexed = true;
            indexer.running = true;
            installedLister.running = true;
        }
    }

    function want(term: string): void {
        root.wake();
        if (!term)
            return;
        root.term = term;
        root.system.want(term);
        if (term.length >= 2)
            root.aur.want(term);
    }

    function closest(lookup: var, term: string): var {
        const exact = lookup.answers[term];
        if (exact !== undefined)
            return exact;
        for (let i = lookup.order.length - 1; i >= 0; i--) {
            const key = lookup.order[i];
            if (term.indexOf(key) === 0)
                return lookup.answers[key];
        }
        return [];
    }

    function narrowed(list: var, term: string): var {
        const want = term.toLowerCase();
        return (list ?? []).filter(p => p.name.toLowerCase().indexOf(want) >= 0 || p.title.toLowerCase().indexOf(want) >= 0 || p.description.toLowerCase().indexOf(want) >= 0);
    }

    function results(term: string): var {
        if (!term)
            return [];
        const flatpaks = Packages.searchFlatpaks(root.flatpakIndex, term, root.flatpakInstalled);
        return Packages.rank([root.narrowed(root.closest(root.system, term), term), root.narrowed(root.closest(root.aur, term), term), flatpaks], term);
    }

    function searching(term: string): bool {
        return root.system.pendingOn(term) || root.arch && term.length >= 2 && root.aur.pendingOn(term);
    }

    function setJob(token: string, state: string): void {
        const next = Object.assign({}, root.jobs);
        if (state)
            next[token] = state;
        else
            delete next[token];
        root.jobs = next;
    }

    function installable(entry: var): bool {
        return entry.source !== "aur" || !!root.aurHelper;
    }

    readonly property bool busy: Uninstaller.busy !== "" || Object.keys(root.jobs).some(token => ["installing", "building", "removing"].indexOf(root.jobs[token]) >= 0)

    function install(entry: var): void {
        const token = Packages.installToken(entry);
        root.armed = "";
        if (root.busy)
            return;
        if (entry.source === "aur") {
            if (!root.aurHelper)
                return;
            root.setJob(token, "building");
            builder.createObject(root, {
                token: token,
                command: [`${Quickshell.shellDir}/scripts/in-terminal.sh`, `'${root.installer}' --ask '${token.replace(/'/g, "'\\''")}'`]
            }).running = true;
            return;
        }
        root.setJob(token, "installing");
        Polkit.expect(`Install ${entry.title}`, entry.name);
        runner.createObject(root, {
            token: token,
            title: entry.title,
            icon: entry.icon,
            command: [root.installer, "--polkit", token]
        }).running = true;
    }

    function uninstall(entry: var): void {
        const token = Packages.installToken(entry);
        const removal = Packages.removalOf(entry);
        root.armed = "";
        if (root.busy)
            return;
        root.setJob(token, "removing");
        Uninstaller.removePackage(removal.how, removal.package, entry.title, entry.icon, done => {
            root.setJob(token, done ? "removed" : "");
            if (done)
                root.refresh();
        });
    }

    function refresh(): void {
        root.system.again(root.term);
        if (root.arch && root.term.length >= 2)
            root.aur.again(root.term);
        if (root.flatpak)
            installedLister.running = true;
    }

    function notify(icon: string, summary: string, body: string): void {
        Quickshell.execDetached(["notify-send", "-a", "banditshell", "-i", icon || "system-software-install", summary, body]);
    }

    Process {
        id: prober

        command: [root.searcher, "tools"]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = {};
                text.split("\n").filter(Boolean).forEach(t => found[t] = true);
                root.tools = found;
                root.probed = true;
                root.wake();
            }
        }
    }

    Process {
        id: indexer

        command: ["python3", "-I", `${Quickshell.shellDir}/scripts/flatpak-index.py`, root.indexFile]
        stdout: StdioCollector {
            onStreamFinished: if (text.trim() !== "unchanged")
                index.reload()
        }
    }

    Process {
        id: installedLister

        command: [root.searcher, "flatpak"]
        stdout: StdioCollector {
            onStreamFinished: root.flatpakInstalled = Packages.readFlatpakInstalled(text)
        }
    }

    FileView {
        id: index

        path: root.indexed ? root.indexFile : ""
        printErrors: false
        onLoaded: root.flatpakIndex = Packages.readFlatpakIndex(text())
    }

    Component {
        id: builder

        Process {
            id: build

            property string token: ""

            onExited: code => {
                root.setJob(build.token, "");
                if (code === 127)
                    root.notify("", "No terminal to build in", build.token.slice(4));
                root.refresh();
                build.destroy();
            }
        }
    }

    Component {
        id: runner

        Process {
            id: run

            property string token: ""
            property string title: ""
            property string icon: ""
            property int code: -1
            property int streams: 0

            function settle(): void {
                if (run.code < 0 || run.streams < 2)
                    return;
                Polkit.forget();
                const code = run.code;
                const last = (complained.text || said.text).trim().split("\n").pop() ?? "";
                if (code === 0) {
                    root.setJob(run.token, "installed");
                    root.notify(run.icon, `${run.title} is installed`, "");
                    root.refresh();
                } else if (code === 4 || code === 127) {
                    root.setJob(run.token, "");
                    Quickshell.execDetached([`${Quickshell.shellDir}/scripts/in-terminal.sh`, `'${root.installer}' --ask '${run.token.replace(/'/g, "'\\''")}'`]);
                } else if (code === 126) {
                    root.setJob(run.token, "");
                } else {
                    root.setJob(run.token, "failed");
                    root.notify(run.icon, `${run.title} did not install`, last);
                }
                run.destroy();
            }

            stdout: StdioCollector {
                id: said

                onStreamFinished: {
                    run.streams += 1;
                    run.settle();
                }
            }

            stderr: StdioCollector {
                id: complained

                onStreamFinished: {
                    run.streams += 1;
                    run.settle();
                }
            }

            onExited: code => {
                run.code = code;
                run.settle();
            }
        }
    }
}
