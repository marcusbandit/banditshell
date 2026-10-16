pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "dev-utilities.js" as Logic

Singleton {
    id: root

    readonly property int passwordLength: Config.values.launcher.utilities.passwordLength

    property var pool: []
    property var drawn: ({})
    property var waiting: []
    property string revealed: ""
    property bool sensitiveCopy: false
    property string pasted: ""
    property bool pasting: false
    property bool again: false

    readonly property int poolSize: 1024
    readonly property int refillBelow: 384
    readonly property int clipboardLimit: 262144

    readonly property var latest: Clipboard.entries.find(e => e.id === Clipboard.current) ?? null
    readonly property string clipboardText: root.latest && !root.latest.file && root.latest.text ? (root.latest.text.length <= root.clipboardLimit ? root.latest.text : "") : root.pasted

    function want(key: string): void {
        if (!key || root.drawn[key] !== undefined || root.take(key))
            return;
        if (root.waiting.indexOf(key) < 0)
            root.waiting = root.waiting.concat([key]);
        root.refill();
    }

    function redraw(key: string): void {
        const kept = Object.assign({}, root.drawn);
        delete kept[key];
        root.drawn = kept;
        root.want(key);
    }

    function take(key: string): bool {
        const got = Logic.draw(key, root.pool, 0);
        if (!got)
            return false;
        root.pool = root.pool.slice(got.next);
        const next = Object.assign({}, root.drawn);
        next[key] = got.value;
        root.drawn = next;
        if (root.pool.length < root.refillBelow)
            root.refill();
        return true;
    }

    function refill(): void {
        if (filler.running)
            root.again = true;
        else
            filler.running = true;
    }

    function forget(): void {
        root.drawn = ({});
        root.waiting = [];
        root.revealed = "";
        root.pasted = "";
    }

    function readClipboard(): void {
        if (root.latest?.text || root.pasting)
            return;
        root.pasting = true;
        paster.running = true;
    }

    function reveal(key: string): void {
        root.revealed = root.revealed === key ? "" : key;
    }

    function copySecret(text: string): void {
        Clipboard.offer(root.sensitiveCopy ? ["wl-copy", "--sensitive", "-n"] : ["wl-copy", "-n"], text);
    }

    Process {
        id: filler

        command: ["od", "-An", "-v", "-tu1", "-N", `${root.poolSize}`, "/dev/urandom"]
        stdout: StdioCollector {
            onStreamFinished: {
                const fresh = Logic.readBytes(text);
                if (!fresh.length)
                    return;
                root.pool = root.pool.concat(fresh);
                const waiting = root.waiting;
                root.waiting = [];
                for (const key of waiting)
                    if (root.drawn[key] === undefined && !root.take(key))
                        root.waiting = root.waiting.concat([key]);
                if (root.waiting.length)
                    root.refill();
            }
        }
        onExited: if (root.again) {
            root.again = false;
            filler.running = true;
        }
    }

    Process {
        id: paster

        command: ["wl-paste", "-n", "-t", "text"]
        stdout: StdioCollector {
            onStreamFinished: root.pasted = text.length <= root.clipboardLimit ? text : ""
        }
        onExited: root.pasting = false
    }

    Process {
        id: prober

        command: ["sh", "-c", "wl-copy --help 2>&1 | grep -q -- --sensitive && echo sensitive; true"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.sensitiveCopy = text.trim() === "sensitive"
        }
    }

    Component.onCompleted: root.refill()
}
