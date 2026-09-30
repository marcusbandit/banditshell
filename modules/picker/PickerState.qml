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

    readonly property string stamp: Qt.formatDateTime(new Date(), "yyyy-MM-dd-hhmmss")

    function show(doFreeze: bool, clipOnly: bool): void {
        if (root.open)
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
        freezer.running = true;
    }

    function close(): void {
        root.open = false;
        root.hiding = false;

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
        const out = `${Config.values.picker.dir.replace("~", Quickshell.env("HOME"))}/banditshell-${root.stamp}.png`;

        if (root.freeze) {

            const frozen = root.take(screen.name);

            if (!frozen)
                return root.close();

            const dpr = screen.devicePixelRatio;
            const cw = Math.round(w * dpr);
            const ch = Math.round(h * dpr);
            const cx = Math.round(x * dpr);
            const cy = Math.round(y * dpr);

            crop.exec(["sh", "-c", `mkdir -p "$(dirname '${out}')" && ffmpeg -y -loglevel error -i '${frozen}' -vf "crop=${cw}:${ch}:${cx}:${cy}" '${out}' && ${root.deliver(out)}; rm -f '${frozen}'`]);
            root.close();
            return;
        }

        root.hiding = true;
        liveDelay.pending = ["sh", "-c", `mkdir -p "$(dirname '${out}')" && grim -g '${x + screen.x},${y + screen.y} ${w}x${h}' '${out}' && ${root.deliver(out)}`];
        liveDelay.restart();
    }

    function deliver(path: string): string {
        if (root.clipboardOnly)
            return `wl-copy --type image/png < '${path}' && notify-send -a banditshell -i '${path}' 'Screenshot copied' '${path}'`;
        return `${Config.values.picker.editor} '${path}'`;
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

        interval: Appearance.anim.fast
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
                root.frozenByScreen = next;
                root.open = true;
            }
        }
    }
}
