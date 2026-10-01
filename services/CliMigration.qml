pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// THE BIND SCANNER. Every shell start, the user's hyprland config is searched
// for binds that still speak the old noun-first CLI grammar (`volume set 50`,
// `wallpapers toggle`), using services/cli-migration.js - the migration map -
// as the one authority on old and new. What it finds is offered through the
// sidebar's update icon: a click rewrites the file (a .bak beside it), a
// refusal - confirmed, because it means "I will fix the config myself" - is
// kept in config.json and never nagged about again.
//
// The scan is read-only; only `migrate()` writes, and only through the map's
// own rewriter, so a bind can never be half-migrated between two opinions
// about what the new grammar is.
Singleton {
    id: root

    // Where the compositor's config lives, and so where the binds live.
    readonly property string configDir: `${Quickshell.env("HOME")}/.config/hypr`
    readonly property string script: `${Quickshell.shellDir}/services/cli-migration.js`

    // How many old-form binds are out there, and in which files.
    property int deprecated: 0

    property var staleFiles: []

    property bool scanned: false

    property string lastResult: ""

    // The one-way door: a confirmed refusal stops the offer, this session and
    // every one after it, until the config is migrated or the key is cleared.
    readonly property bool declined: Config.values.cli.bindsDeclined === true

    readonly property bool stale: !root.declined && root.deprecated > 0

    function scan(): void {
        if (!nodeAvailable)
            return;
        scanner.command = ["node", root.script, "--scan", root.configDir];
        scanner.running = true;
    }

    function migrate(): string {
        if (root.staleFiles.length === 0)
            return "nothing to migrate";
        migrator.command = ["node", root.script, "--write"].concat(root.staleFiles);
        migrator.running = true;
        return "migrating " + root.staleFiles.join(", ");
    }

    function decline(): void {
        if (root.declined)
            return;
        Config.set("cli.bindsDeclined", true);
    }

    property bool nodeAvailable: false

    Process {
        id: probe

        command: ["node", "--version"]
        property bool ready: false

        stdout: StdioCollector {
            onStreamFinished: {
                probe.ready = true;
                root.nodeAvailable = true;
                root.scan();
            }
        }
    }

    Process {
        id: scanner

        stdout: StdioCollector {
            onStreamFinished: {
                const files = [];
                let n = 0;
                for (const line of text.split("\n")) {
                    if (!line)
                        continue;
                    const tab = line.indexOf("\t");
                    if (tab < 0)
                        continue;
                    const count = Number(line.slice(0, tab)) || 0;
                    files.push(line.slice(tab + 1));
                    n += count;
                }
                root.staleFiles = files;
                root.deprecated = n;
                root.scanned = true;
            }
        }
    }

    Process {
        id: migrator

        stdout: StdioCollector {
            onStreamFinished: {
                root.lastResult = text.trim() || "nothing changed";
                root.scan(); // the truth after the write, not the hope
            }
        }
    }

    // Scan on the way up - every start and every restart - and again when the
    // config lands back from a decline or a migrate.
    Connections {
        target: Config

        function onLoadedChanged(): void {
            if (Config.loaded && !root.scanned)
                probe.running = true;
        }
    }
}
