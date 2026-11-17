pragma Singleton

import QtQuick
import Quickshell
import qs.config
import "hyprland-lua.js" as HyprlandLua
import "chords.js" as Chords

Singleton {
    id: root

    readonly property var keys: Config.values.launcher.hotkeys

    readonly property bool possible: Compositor.isHyprland

    property var applied: ({})
    property var appliedToggle: ({})

    readonly property var named: ({
            [Qt.Key_Space]: "SPACE",
            [Qt.Key_Return]: "RETURN",
            [Qt.Key_Enter]: "RETURN",
            [Qt.Key_Tab]: "TAB",
            [Qt.Key_Backspace]: "BACKSPACE",
            [Qt.Key_Delete]: "DELETE",
            [Qt.Key_Insert]: "INSERT",
            [Qt.Key_Left]: "LEFT",
            [Qt.Key_Right]: "RIGHT",
            [Qt.Key_Up]: "UP",
            [Qt.Key_Down]: "DOWN",
            [Qt.Key_Home]: "HOME",
            [Qt.Key_End]: "END",
            [Qt.Key_PageUp]: "PRIOR",
            [Qt.Key_PageDown]: "NEXT",
            [Qt.Key_Print]: "PRINT",
            [Qt.Key_Slash]: "SLASH",
            [Qt.Key_Backslash]: "BACKSLASH",
            [Qt.Key_Comma]: "COMMA",
            [Qt.Key_Period]: "PERIOD",
            [Qt.Key_Minus]: "MINUS",
            [Qt.Key_Equal]: "EQUAL",
            [Qt.Key_Semicolon]: "SEMICOLON",
            [Qt.Key_Apostrophe]: "APOSTROPHE",
            [Qt.Key_BracketLeft]: "BRACKETLEFT",
            [Qt.Key_BracketRight]: "BRACKETRIGHT",
            [Qt.Key_QuoteLeft]: "GRAVE"
        })

    readonly property var lone: [Qt.Key_Control, Qt.Key_Shift, Qt.Key_Alt, Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R, Qt.Key_AltGr]

    function keyName(event: var): string {
        const k = event.key;
        if (k >= Qt.Key_A && k <= Qt.Key_Z)
            return String.fromCharCode(65 + k - Qt.Key_A);
        if (k >= Qt.Key_0 && k <= Qt.Key_9)
            return String.fromCharCode(48 + k - Qt.Key_0);
        if (k >= Qt.Key_F1 && k <= Qt.Key_F24)
            return `F${k - Qt.Key_F1 + 1}`;
        const scan = event.nativeScanCode ?? 0;
        if (scan >= 10 && scan <= 19)
            return String((scan - 9) % 10);
        return root.named[k] ?? "";
    }

    function pressedChord(event: var): string {
        const m = event.modifiers;
        const key = root.keyName(event);
        return key && m & (Qt.ControlModifier | Qt.AltModifier) && !(m & Qt.MetaModifier) ? [m & Qt.ControlModifier ? "CTRL" : "", m & Qt.AltModifier ? "ALT" : "", m & Qt.ShiftModifier ? "SHIFT" : "", key].filter(Boolean).join("+") : "";
    }

    function chordFrom(event: var): var {
        if (root.lone.includes(event.key))
            return {
                waiting: true
            };
        const key = root.keyName(event);
        if (!key)
            return {
                said: "that key can’t be bound"
            };
        const m = event.modifiers;
        const mods = [m & Qt.MetaModifier ? "SUPER" : "", m & Qt.ControlModifier ? "CTRL" : "", m & Qt.AltModifier ? "ALT" : "", m & Qt.ShiftModifier ? "SHIFT" : ""].filter(Boolean);
        if (!mods.includes("SUPER") && !(mods.includes("CTRL") && mods.includes("ALT")))
            return {
                said: "add super, or ctrl and alt"
            };
        return {
            chord: [...mods, key].join(" + ")
        };
    }

    function chordOf(id: string): string {
        return root.keys[id]?.chord ?? "";
    }

    function liveChord(id: string): string {
        const held = root.keys[id];
        return held && !held.off ? held.chord ?? "" : "";
    }

    function toggles(id: string): bool {
        return !!root.keys[id]?.toggle;
    }

    function setToggle(id: string, on: bool): void {
        const held = root.keys[id];
        if (!held)
            return;
        const next = Object.assign({}, root.keys);
        next[id] = Object.assign({}, held, {
            toggle: on
        });
        Config.set("launcher.hotkeys", next);
    }

    function ownHolderOf(chord: string, id: string): string {
        return Object.keys(root.keys).find(other => other !== id && Chords.sameChord(root.keys[other].chord, chord)) ?? "";
    }

    function holderOf(chord: string, id: string): string {
        const mine = root.ownHolderOf(chord, id);
        if (mine)
            return root.keys[mine].label || mine;
        const bind = HyprConfig.holderOf(chord);
        return bind ? bind.description || bind.action || "another bind" : "";
    }

    function take(id: string, chord: string, label: string): void {
        const next = Object.assign({}, root.keys);
        const from = root.ownHolderOf(chord, id);
        if (from)
            delete next[from];
        next[id] = Object.assign({}, root.keys[id], {
            chord: chord,
            label: label
        });
        Config.set("launcher.hotkeys", next);
    }

    function set(id: string, chord: string, label: string): void {
        const next = Object.assign({}, root.keys);
        next[id] = Object.assign({}, root.keys[id], {
            chord: chord,
            label: label
        });
        Config.set("launcher.hotkeys", next);
    }

    function clear(id: string): void {
        const next = Object.assign({}, root.keys);
        delete next[id];
        Config.set("launcher.hotkeys", next);
    }

    function apply(): void {
        if (!root.possible || !Hypr.parserKnown)
            return;
        const lua = [];
        const legacy = [];
        const now = {};
        const toggled = {};
        for (const id of Object.keys(root.applied)) {
            const chord = root.applied[id];
            if (root.liveChord(id) === chord) {
                now[id] = chord;
                toggled[id] = root.appliedToggle[id];
                continue;
            }
            lua.push(`hl.unbind("${HyprlandLua.luaString(chord)}")`);
            legacy.push(`keyword unbind ${Chords.legacyChord(chord)}`);
        }
        for (const id of Object.keys(root.keys)) {
            const want = root.keys[id];
            if (!want?.chord || want.off || now[id] === want.chord && root.appliedToggle[id] === !!want.toggle)
                continue;
            const command = Chords.hotkeyCommand(id, want.toggle);
            lua.push(`hl.unbind("${HyprlandLua.luaString(want.chord)}")`);
            legacy.push(`keyword unbind ${Chords.legacyChord(want.chord)}`);
            lua.push(HyprlandLua.composeBind(want.chord, `hl.dsp.exec_cmd("${HyprlandLua.luaString(command)}")`, {
                description: want.label
            }));
            legacy.push(`keyword bind ${Chords.legacyChord(want.chord)}, exec, ${command}`);
            now[id] = want.chord;
            toggled[id] = !!want.toggle;
        }
        root.applied = now;
        root.appliedToggle = toggled;
        if (!lua.length)
            return;
        Quickshell.execDetached(Hypr.lua ? ["hyprctl", "eval", lua.join("\n")] : ["hyprctl", "--batch", legacy.join(" ; ")]);
    }

    onKeysChanged: root.apply()

    Connections {
        target: Hypr

        function onParserKnownChanged(): void {
            root.apply();
        }

        function onConfigReloaded(): void {
            root.applied = {};
            root.apply();
        }
    }

    Component.onCompleted: root.apply()
}
