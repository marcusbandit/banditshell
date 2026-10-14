pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "pacman.js" as Packages

Singleton {
    id: root

    readonly property real interval: Math.max(0, Config.values.packages.interval) * 60 * 1000
    readonly property string upgradeCommand: Config.values.packages.upgrade

    property bool present: false

    property string kernel: ""
    property string running: ""
    property string installed: ""

    property bool stale: false

    property var updates: []
    property real checkedAt: 0

    property bool probing: false
    property bool fetching: false
    property bool queued: false
    property bool remembered: false

    readonly property var kernelUpdate: {
        const found = Packages.pending(root.updates, root.kernel);
        if (!found || root.stale || found.to === root.installed)
            return null;
        return root.installed && found.from !== root.installed ? null : found;
    }

    readonly property bool restartNeeded: root.stale

    readonly property bool upgrading: kept.upgradingSince > 0

    readonly property real upgradeWatch: 10 * 60 * 1000

    readonly property string statePath: `${Config.stateDir}/packages.json`

    function pretty(version: string): string {
        return Packages.pretty(version);
    }

    function due(): bool {
        if (root.interval <= 0 || !root.present)
            return false;
        const since = Date.now() - root.checkedAt;
        return since < 0 || since >= root.interval;
    }

    function probe(fetch: bool): void {
        if (root.probing) {
            root.queued = root.queued || fetch;
            return;
        }
        root.probing = true;
        root.fetching = fetch;
        prober.command = ["sh", "-c", `
            export LC_ALL=C
            command -v pacman >/dev/null 2>&1 || { echo present=0; exit 0; }
            echo present=1
            running=$(uname -r)
            printf 'running=%s\\n' "$running"
            kernel=
            if [ -e "/usr/lib/modules/$running/vmlinuz" ]; then
                echo stale=0
                kernel=$(pacman -Qqo "/usr/lib/modules/$running/vmlinuz" 2>/dev/null)
            elif ls /usr/lib/modules/*/vmlinuz >/dev/null 2>&1; then
                echo stale=1
                kernel=$1
            else
                echo stale=0
            fi
            [ -n "$kernel" ] || kernel=linux
            printf 'kernel=%s\\n' "$kernel"
            printf 'installed=%s\\n' "$(pacman -Q -- "$kernel" 2>/dev/null | cut -d' ' -f2)"
            [ "$2" = fetch ] || exit 0
            if ! command -v checkupdates >/dev/null 2>&1; then
                echo code=missing
                exit 0
            fi
            out=$(timeout -k 10 120 checkupdates 2>&1)
            printf 'code=%s\\n' "$?"
            printf '%s\\n' "$out" | sed 's/^/|/'
        `, "sh", root.kernel, fetch ? "fetch" : "local"];
        prober.running = true;
    }

    function take(text: string): void {
        const got = Packages.report(text);
        const v = got.values;

        root.present = v.present === "1";
        if (!root.present)
            return;

        root.running = v.running ?? "";
        root.stale = v.stale === "1";
        root.kernel = v.kernel ?? root.kernel;
        root.installed = v.installed ?? "";

        if (root.stale)
            kept.upgradingSince = 0;

        if (!root.fetching)
            return;

        if (v.code === "missing") {
            console.info("Pacman: checkupdates is not installed (pacman-contrib), so new kernels are not looked for.");
            root.checkedAt = Date.now();
            return;
        }

        if (v.code !== "0" && v.code !== "2") {
            console.warn(`Pacman: checkupdates failed (${v.code}): ${got.lines.filter(l => l).join(" / ")}`);
            retry.restart();
            return;
        }

        root.updates = v.code === "0" ? Packages.updates(got.lines) : [];
        root.checkedAt = Date.now();
        memory.setText(JSON.stringify({
            checkedAt: root.checkedAt,
            kernel: root.kernel,
            updates: root.updates
        }));
    }

    function upgrade(): void {
        if (!root.present)
            return;
        kept.upgradingSince = Date.now();
        Quickshell.execDetached(["sh", "-c", `
            script="$1"'; status=$?; echo; if [ "$status" -eq 0 ]; then echo "Done. Press Enter to close."; else echo "pacman stopped with an error ($status). Press Enter to close."; fi; read -r _'
            for term in "\${TERMINAL%% *}" kitty foot ghostty alacritty wezterm konsole gnome-terminal xterm; do
                [ -n "$term" ] && command -v "$term" >/dev/null 2>&1 && break
                term=
            done
            [ -n "$term" ] || exit 127
            case \${term##*/} in
                kitty | foot) exec "$term" sh -c "$script" ;;
                wezterm) exec "$term" start -- sh -c "$script" ;;
                gnome-terminal) exec "$term" -- sh -c "$script" ;;
                *) exec "$term" -e sh -c "$script" ;;
            esac
        `, "sh", root.upgradeCommand]);
    }

    PersistentProperties {
        id: kept

        reloadableId: "packages"

        property real upgradingSince: 0
    }

    Process {
        id: prober

        stdout: StdioCollector {
            onStreamFinished: {
                root.probing = false;
                root.take(text);
                if (root.queued) {
                    root.queued = false;
                    root.probe(true);
                }
            }
        }
    }

    FileView {
        id: memory

        path: root.statePath
        printErrors: false

        onLoaded: {
            try {
                const data = JSON.parse(text());
                root.checkedAt = Number(data?.checkedAt) || 0;
                root.kernel = `${data?.kernel ?? ""}`;
                root.updates = Array.isArray(data?.updates) ? data.updates.filter(u => u && u.name && u.from && u.to) : [];
            } catch (e) {
                console.warn(`Pacman: ${root.statePath} is not valid JSON; checking as if never checked.`);
            }
            root.remembered = true;
        }

        onLoadFailed: root.remembered = true
    }

    Timer {
        interval: 2000
        running: root.remembered
        onTriggered: root.probe(false)
    }

    Timer {
        interval: 60 * 1000
        running: root.remembered
        onTriggered: if (root.due())
            root.probe(true)
    }

    Timer {
        interval: 5 * 60 * 1000
        repeat: true
        running: root.remembered && root.present
        onTriggered: root.probe(root.due())
    }

    Timer {
        id: retry

        interval: 30 * 60 * 1000
        onTriggered: root.probe(true)
    }

    Timer {
        interval: 5000
        repeat: true
        running: root.upgrading
        onTriggered: {
            if (Date.now() - kept.upgradingSince > root.upgradeWatch)
                kept.upgradingSince = 0;
            else
                root.probe(false);
        }
    }
}
