pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    readonly property int backlog: 32

    property var pending: []
    property bool busy: false

    readonly property var modCodes: ({
            ctrl: 29,
            shift: 42,
            alt: 56,
            altgr: 100,
            super: 125
        })

    readonly property var codes: ({

            "1": 2,
            "2": 3,
            "3": 4,
            "4": 5,
            "5": 6,
            "6": 7,
            "7": 8,
            "8": 9,
            "9": 10,
            "0": 11,
            "-": 12,
            "=": 13,

            q: 16,
            w: 17,
            e: 18,
            r: 19,
            t: 20,
            y: 21,
            u: 22,
            i: 23,
            o: 24,
            p: 25,
            "[": 26,
            "]": 27,
            a: 30,
            s: 31,
            d: 32,
            f: 33,
            g: 34,
            h: 35,
            j: 36,
            k: 37,
            l: 38,
            ";": 39,
            "'": 40,
            "`": 41,
            "\\": 43,
            z: 44,
            x: 45,
            c: 46,
            v: 47,
            b: 48,
            n: 49,
            m: 50,
            ",": 51,
            ".": 52,
            "/": 53,
            " ": 57,

            Escape: 1,
            BackSpace: 14,
            Tab: 15,
            Return: 28,
            F1: 59,
            F2: 60,
            F3: 61,
            F4: 62,
            F5: 63,
            F6: 64,
            F7: 65,
            F8: 66,
            F9: 67,
            F10: 68,
            F11: 87,
            F12: 88,
            Home: 102,
            Up: 103,
            Prior: 104,
            Left: 105,
            Right: 106,
            End: 107,
            Down: 108,
            Next: 109,
            Insert: 110,
            Delete: 111,
            Print: 99
        })

    readonly property var hardMods: ["ctrl", "alt", "altgr", "super"]

    function hard(mods: var): var {
        if (!mods || !mods.length)
            return [];
        return mods.filter(m => root.hardMods.includes(m));
    }

    function type(text: string, mods: var): void {
        if (!text)
            return;
        if (root.hard(mods).length) {
            root.chord(text, mods);
            return;
        }

        root.send(["wtype", "--", text]);
    }

    function press(sym: string, mods: var): void {
        if (!sym)
            return;
        if (root.hard(mods).length) {
            root.chord(sym, mods);
            return;
        }
        root.send(["wtype", "-k", sym]);
    }

    function chord(token: string, mods: var): void {
        const code = root.codes[token];
        if (code === undefined) {

            console.warn(`Keystrokes: no keycode for "${token}", sending it without modifiers.`);
            root.send(["wtype", "--", token]);
            return;
        }

        const held = (mods ?? []).map(m => root.modCodes[m]).filter(c => c !== undefined);

        const argv = ["ydotool", "key"];
        for (const m of held)
            argv.push(`${m}:1`);
        argv.push(`${code}:1`, `${code}:0`);
        for (const m of held.slice().reverse())
            argv.push(`${m}:0`);

        root.send(argv);
    }

    function send(argv: var): void {
        if (root.pending.length >= root.backlog) {
            console.warn("Keystrokes: backlog full, dropping a keystroke.");
            return;
        }
        root.pending = [...root.pending, argv];
        root.pump();
    }

    function pump(): void {
        if (root.busy || !root.pending.length)
            return;
        const next = root.pending[0];
        root.pending = root.pending.slice(1);
        root.busy = true;

        sender.command = next;
        sender.running = true;
    }

    Process {
        id: sender

        onExited: {
            root.busy = false;
            root.pump();
        }

        stderr: SplitParser {

            onRead: line => console.warn("Keystrokes:", line)
        }
    }
}
