pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// PRESSING A KEY IN SOMEBODY ELSE'S WINDOW.
//
// NAMED `Keystrokes` AND NOT `Keys`, WHICH IS NOT A STYLE CHOICE. `Keys` is
// QML's own attached type, the one every `Keys.onPressed` in this repo is
// written against. A singleton of that name in qs.services shadows it in every
// file that imports the module, and the failure is not a warning about a clash:
// it is "Non-existent attached object" at whichever line happens to be first,
// and the whole shell stops loading. It cost one debugging round to find, so the
// rule is written down here rather than rediscovered.
//
// Every other input this shell has runs the other way: something is typed AT the
// shell and the shell answers. This is the one place it types outward, into
// whatever window happens to have the focus, which makes it the only service
// whose whole job is to have no effect on the shell at all.
//
// IT GOES THROUGH THE SAME DOORS A REAL KEYBOARD DOES, rather than posting
// synthetic events into a toolkit: that would work in the toolkits it knew about
// and fail silently in a terminal, and the whole point of a tablet-mode keyboard
// is that it works in the thing you actually opened. Which door depends on
// whether the keystroke is a character or a command; see the two-transports note
// on `hardMods` below, which is the most important paragraph in this file.
//
// THE SHELL MUST NOT HOLD THE KEYBOARD WHILE THIS IS USED. wtype sends to
// whatever the compositor considers focused, so if the shell's own layer surface
// has taken exclusive focus, the shell types into itself. That is why the
// on-screen keyboard is deliberately absent from ShellWindow's `keyboardFocus`
// expression: it is the one panel that must never be in it. See
// modules/keyboard/OnScreenKeyboard.qml.
//
// A QUEUE, NOT A FIRE-AND-FORGET. Each keystroke is a process, and two of them
// alive at once are two virtual keyboards racing: the compositor is free to
// deliver their events in either order, so a fast "th" can arrive as "ht". One
// process at a time, in the order asked, costs a few milliseconds nobody can
// feel at tapping speed and removes a class of bug that would be blamed on the
// touchscreen.
Singleton {
    id: root

    // How many keystrokes may be waiting before new ones are dropped. A held
    // finger on a repeating key while the machine is thrashing could otherwise
    // build an unbounded backlog that goes on typing long after the finger came
    // off, which is worse than a dropped repeat.
    readonly property int backlog: 32

    property var pending: []
    property bool busy: false

    // THE MODIFIERS, AS THE KERNEL NUMBERS THEM. linux/input-event-codes.h.
    // Left-hand variants throughout, because a chord does not care which side it
    // came from and a board with two of each would be claiming a distinction it
    // cannot make.
    readonly property var modCodes: ({
            ctrl: 29,
            shift: 42,
            alt: 56,
            altgr: 100,
            super: 125
        })

    // AND THE KEYS. Also evdev codes, and therefore US-layout POSITIONS rather
    // than characters: code 30 is the key where a US map puts `a`. That is
    // exactly right for a chord, because a bind is written against a position
    // too (SUPER + 1 means the key left of 2, whatever the layout paints on it),
    // and exactly wrong for typing, which is why characters never come here.
    //
    // ONLY WHAT A CHORD PLAUSIBLY USES. Every letter, every digit, the ASCII
    // punctuation and the named keys. The second page's accented letters and
    // symbols are deliberately absent: there is no keycode for them, and `chord`
    // says what it does when it cannot find one.
    readonly property var codes: ({
            // Digit row.
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
            // Letters, in the order the rows run rather than alphabetically, so
            // this reads as a keyboard and a missing one is visible.
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
            // Named keys, under the same xkb names Layouts uses for them, so one
            // spelling serves both transports.
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

    // TWO TRANSPORTS, AND THE REASON IS THAT NEITHER ONE CAN DO BOTH JOBS.
    //
    // MEASURED, not assumed. With SUPER held, `wtype -M logo -- "2"` and
    // `wtype -M logo -k 2` both leave the workspace exactly where it was;
    // `ydotool key 125:1 3:1 3:0 125:0` switches it. So:
    //
    //   wtype   speaks the virtual-keyboard Wayland protocol. The focused client
    //           receives the keys, and the COMPOSITOR DOES NOT ACT ON THEM: a
    //           keybind is never triggered, whichever form the key is sent in.
    //           That is deliberate on Hyprland's side and there is no option to
    //           change it (input:virtualkeyboard has share_states and
    //           release_pressed_on_close, and nothing else). What it is good at
    //           is CHARACTERS: it types a literal string through a keymap it
    //           builds itself, so "æ" arrives as æ no matter which xkb layout
    //           the window is using.
    //
    //   ydotool writes to /dev/uinput, so what it makes is a KERNEL KEYBOARD.
    //           The compositor cannot tell it from the one on the desk, which
    //           means binds fire. What it cannot do is characters: uinput speaks
    //           key CODES, so what arrives depends entirely on the active xkb
    //           layout, and there is no keycode at all for æ on a US map.
    //
    // So the rule is: a chord goes through uinput, a character goes through the
    // protocol. Nothing else divides cleanly, and getting it backwards produces
    // exactly the two bugs this shell would otherwise ship with, which are a
    // SUPER+1 that does nothing and a Danish keyboard that types the wrong
    // letter.
    //
    // `shift` DOES NOT COUNT as a chord, because it never needs to: the board
    // already knows which character a shifted key produces and sends that
    // directly. Only ctrl, alt, altgr and super mean "the compositor or the app
    // should treat this as a command".
    readonly property var hardMods: ["ctrl", "alt", "altgr", "super"]

    function hard(mods: var): var {
        if (!mods || !mods.length)
            return [];
        return mods.filter(m => root.hardMods.includes(m));
    }

    // TYPE A LITERAL STRING, which is how every ordinary printable key on the
    // board is sent. Not as a keysym: the board's data already says which
    // character the key produces in the state it is in, and a keysym would then
    // be re-mapped through whatever xkb layout the window happens to be using,
    // so a board showing "æ" would type whatever sits on that physical key in
    // the CURRENT layout instead. Sending the character means the board is the
    // truth.
    function type(text: string, mods: var): void {
        if (!text)
            return;
        if (root.hard(mods).length) {
            root.chord(text, mods);
            return;
        }
        // `--` because the text may itself begin with a dash, and wtype reads
        // everything before it as options. A board with a "-" key that silently
        // did nothing would be a strange bug to find.
        root.send(["wtype", "--", text]);
    }

    // PRESS A NAMED KEY: Return, BackSpace, Tab, Escape, Left, F5. These have no
    // character to send, so they go as keysyms and libxkbcommon resolves them.
    function press(sym: string, mods: var): void {
        if (!sym)
            return;
        if (root.hard(mods).length) {
            root.chord(sym, mods);
            return;
        }
        root.send(["wtype", "-k", sym]);
    }

    // A CHORD, THROUGH THE KERNEL. Modifiers down in the order given, the key
    // pressed and released, then the modifiers up in reverse: a real keyboard
    // never releases ctrl before the key it was modifying, and a compositor
    // watching the modifier state would see a bare keypress if we did.
    function chord(token: string, mods: var): void {
        const code = root.codes[token];
        if (code === undefined) {
            // FALLS BACK RATHER THAN DROPPING. A character with no keycode
            // (every accented letter, every symbol on the second page) simply
            // cannot be sent this way, and typing it without the modifier is a
            // far better answer than typing nothing: ctrl+æ is not a bind
            // anybody has, so the modifier was almost certainly a stray latch.
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
        // The argv arrives WHOLE, program included, because which program it is
        // is the decision `type` and `press` just made. See the two-transports
        // note above.
        sender.command = next;
        sender.running = true;
    }

    Process {
        id: sender

        // ON EXIT RATHER THAN ON A TIMER. The next keystroke goes the instant
        // this one's process is reaped, so the queue costs exactly one process
        // lifetime per key and nothing more; a timer would have to guess that
        // number and would be wrong on both sides of it.
        onExited: {
            root.busy = false;
            root.pump();
        }

        stderr: SplitParser {
            // The failure worth hearing about is the compositor refusing the
            // virtual-keyboard protocol, which presents as every key silently
            // doing nothing: exactly the symptom that would otherwise be blamed
            // on the touchscreen or on the layout data.
            onRead: line => console.warn("Keystrokes:", line)
        }
    }
}
