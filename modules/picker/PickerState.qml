pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Scope {
    id: root

    property bool open: false
    property bool freeze: false
    property bool clipboardOnly: false

    property var frozenByScreen: ({})

    property bool hiding: false

    property bool freezing: false

    function show(doFreeze: bool, clipOnly: bool): void {
        if (root.open || root.freezing)
            return;
        root.freeze = doFreeze;
        root.clipboardOnly = clipOnly;
        root.frozenByScreen = ({});
        root.hiding = false;

        if (!doFreeze) {
            root.open = true;
            return;
        }

        const names = [];
        for (const s of Quickshell.screens)
            if (s.name)
                names.push(s.name);
        freezer.command = ["sh", "-c", `
            for n in "$@"; do
                f=$(mktemp /tmp/banditshell-freeze-XXXXXX.png) || continue
                grim -o "$n" "$f" && printf '%s\\t%s\\n' "$n" "$f" || rm -f "$f"
            done
        `, "sh", ...names];
        root.freezing = true;
        freezer.running = true;
    }

    function close(): void {
        root.open = false;
        root.hiding = false;
        root.freezing = false;

        const orphans = Object.values(root.frozenByScreen);
        if (orphans.length)
            cleanup.exec(["rm", "-f", ...orphans]);
        root.frozenByScreen = ({});
    }

    function take(name: string): string {
        const path = root.frozenByScreen[name] ?? "";
        const rest = Object.assign({}, root.frozenByScreen);
        delete rest[name];
        root.frozenByScreen = rest;
        return path;
    }

    function capture(screen: var, x: int, y: int, w: int, h: int): void {
        const stamp = Qt.formatDateTime(new Date(), "yyyy-MM-dd-hhmmss");
        const out = `${Config.values.picker.dir.replace("~", Quickshell.env("HOME"))}/banditshell-${stamp}.png`;

        if (root.freeze) {
            const frozen = root.take(screen.name);

            if (!frozen)
                return root.close();

            const dpr = screen.devicePixelRatio;
            const cw = Math.round(w * dpr);
            const ch = Math.round(h * dpr);
            const cx = Math.round(x * dpr);
            const cy = Math.round(y * dpr);

            crop.exec(["sh", "-c", `mkdir -p "$(dirname "$1")" && ffmpeg -y -loglevel error -i "$2" -vf "crop=${cw}:${ch}:${cx}:${cy}" "$1" && ${root.deliver()}; rm -f "$2"`, "sh", out, frozen]);
            root.close();
            return;
        }

        root.hiding = true;
        liveDelay.pending = ["sh", "-c", `mkdir -p "$(dirname "$1")" && grim -g "${x + screen.x},${y + screen.y} ${w}x${h}" "$1" && ${root.deliver()}`, "sh", out];
        liveDelay.restart();
    }

    function deliver(): string {
        if (root.clipboardOnly)
            return `wl-copy --type image/png < "$1" && notify-send -a banditshell -i "$1" 'Screenshot copied' "$1"`;
        return `${Config.values.picker.editor} "$1"`;
    }

    Process {
        id: cleanup
    }
    Process {
        id: crop
    }
    Process {
        id: live
    }

    Timer {
        id: liveDelay

        property var pending: null

        interval: Appearance.animation.fade.fast
        onTriggered: {
            if (pending)
                live.exec(pending);
            pending = null;
            root.close();
        }
    }

    Process {
        id: freezer

        stdout: StdioCollector {
            onStreamFinished: {
                const next = {};
                for (const line of text.trim().split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab > 0)
                        next[line.slice(0, tab)] = line.slice(tab + 1);
                }
                if (!root.freezing) {
                    const late = Object.values(next);
                    if (late.length)
                        cleanup.exec(["rm", "-f", ...late]);
                    return;
                }
                root.freezing = false;
                root.frozenByScreen = next;
                root.open = true;
            }
        }
    }
}
