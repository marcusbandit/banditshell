pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "github.js" as Hub

Singleton {
    id: root

    readonly property bool enabled: (Config.values.launcher.online ?? {}).github !== false

    readonly property string script: `${Quickshell.shellDir}/scripts/github-summary.sh`
    readonly property string installer: `${Quickshell.shellDir}/scripts/install-package.sh`
    readonly property var cliPackages: ["pacman:github-cli", "apt:gh", "dnf:gh", "zypper:gh", "xbps:github-cli", "apk:github-cli"]
    readonly property real staleAfter: 5 * 60 * 1000

    property string state: "unknown"
    property var summary: null
    property real fetchedAt: 0
    property real triedAt: 0
    readonly property real retryAfter: 60 * 1000
    property string installing: ""

    readonly property bool loading: fetcher.running

    function wake(): void {
        const now = Date.now();
        if (fetcher.running || now - root.triedAt < root.retryAfter || now - root.fetchedAt < root.staleAfter && root.state !== "missing" && root.state !== "signedout")
            return;
        root.triedAt = now;
        fetcher.running = true;
    }

    function installCli(): void {
        if (root.installing === "trying")
            return;
        root.installing = "trying";
        Polkit.expect("Install the GitHub CLI", "gh");
        cliInstaller.running = true;
    }

    function signIn(): void {
        signer.running = true;
    }

    Process {
        id: fetcher

        command: [root.script]
        stdout: StdioCollector {
            id: fetched
        }
        onExited: code => {
            if (code === 3) {
                root.state = "missing";
                return;
            }
            if (code === 4) {
                root.state = "signedout";
                return;
            }
            const got = code === 0 ? Hub.readSummary(fetched.text) : null;
            if (!got)
                return;
            root.summary = got;
            root.state = "ready";
            root.fetchedAt = Date.now();
            store.save(JSON.stringify({
                at: root.fetchedAt,
                summary: got
            }));
        }
    }

    Process {
        id: cliInstaller

        command: [root.installer, "--polkit", ...root.cliPackages]
        onExited: code => {
            Polkit.forget();
            if (code === 4 || code === 127) {
                root.installing = "terminal";
                Quickshell.execDetached([`${Quickshell.shellDir}/scripts/in-terminal.sh`, `'${root.installer}' --ask ${root.cliPackages.join(" ")}`]);
                return;
            }
            root.installing = code === 0 || code === 126 ? "" : "failed";
            root.fetchedAt = 0;
            root.triedAt = 0;
            root.wake();
        }
    }

    Process {
        id: signer

        command: [`${Quickshell.shellDir}/scripts/in-terminal.sh`, "gh auth login"]
        onExited: {
            root.fetchedAt = 0;
            root.triedAt = 0;
            root.wake();
        }
    }

    PrivateFile {
        id: store

        path: `${Config.stateDir}/online/github.json`
        onLoaded: text => {
            try {
                const kept = JSON.parse(text);
                if (kept.summary && !root.summary) {
                    root.summary = kept.summary;
                    root.fetchedAt = kept.at ?? 0;
                    root.state = "ready";
                }
            } catch (e) {}
        }
    }
}
