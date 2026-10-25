pragma Singleton

import QtQuick
import Quickshell
import qs.config
import qs.services
import "../../services/hyprland-lua.js" as HyprlandLua

Singleton {
    id: root

    function fromChord(chord: string): string {
        const text = String(chord ?? "");
        const parts = text.indexOf(" + ") >= 0 ? text.split(" + ") : text.replace(/\+\+$/, "+plus").split("+");
        return parts.map(p => p.trim().toLowerCase()).filter(Boolean).map(p => p === "plus" ? "+" : p).join(" ");
    }

    function toChord(combo: string): string {
        return combo.split(" ").filter(Boolean).map(p => p.toUpperCase()).join(" + ");
    }

    function toFilesKey(combo: string): string {
        return combo.split(" ").filter(Boolean).map(p => p.length === 1 ? p.toUpperCase() : p.split("_").map(w => w.charAt(0).toUpperCase() + w.slice(1)).join("")).join("+");
    }

    readonly property var fileActions: {
        const out = [];
        for (const map of [Config.defaults.files.keys, Config.values.files.keys ?? {}])
            for (const k of Object.keys(map))
                if (out.indexOf(String(map[k])) < 0)
                    out.push(String(map[k]));
        return out;
    }

    readonly property var shell: HyprConfig.binds.filter(b => !b.dynamic && b.chord).map(b => ({
                id: b.id,
                name: (b.action || b.expr || "").toLowerCase(),
                combo: root.fromChord(b.chord),
                bind: b
            }))

    readonly property var files: {
        const keys = Config.values.files.keys ?? {};
        return root.fileActions.map(action => {
            const key = Object.keys(keys).find(k => String(keys[k]) === action) ?? "";
            return {
                id: action,
                name: action,
                key,
                combo: key ? root.fromChord(key) : "",
                bind: null
            };
        });
    }

    function combosFor(ref: string): var {
        const at = ref.indexOf(":");
        const id = ref.slice(at + 1);
        if (ref.slice(0, at) === "files") {
            const keys = Config.values.files.keys ?? {};
            return Object.keys(keys).filter(k => String(keys[k]) === id).map(k => root.fromChord(k));
        }
        return root.shell.filter(k => HyprlandLua.bindAction(k.bind.expr) === id).map(k => k.combo);
    }

    function find(pinId: string): var {
        const at = pinId.indexOf(":");
        const set = pinId.slice(0, at);
        const id = pinId.slice(at + 1);
        return (set === "shell" ? root.shell : root.files).find(k => k.id === id) ?? null;
    }

    function rebind(pinId: string, combo: string): string {
        const at = pinId.indexOf(":");
        const set = pinId.slice(0, at);
        const id = pinId.slice(at + 1);
        if (set === "files") {
            const parts = combo.split(" ");
            if (parts.indexOf("ctrl") < 0 && parts.indexOf("alt") < 0)
                return "files keys need ctrl or alt";
            if (parts.indexOf("super") >= 0)
                return "files cannot see super";
            const keys = Object.assign({}, Config.values.files.keys ?? {});
            const next = root.toFilesKey(combo);
            const clash = keys[next] !== undefined && String(keys[next]) !== id ? String(keys[next]) : "";
            for (const k of Object.keys(keys))
                if (String(keys[k]) === id)
                    delete keys[k];
            keys[next] = id;
            Config.set("files.keys", keys);
            return clash ? `${combo} moved here from ${clash}` : "";
        }
        const entry = root.shell.find(k => k.id === id);
        if (!entry)
            return "";
        if (!Config.values.sourceEdits?.acknowledged) {
            SettingsState.refused("turn on Edit Hyprland files first", "shell");
            return "";
        }
        const clash = root.shell.find(k => k.combo === combo && k.id !== id);
        const b = entry.bind;
        HyprConfig.updateBind(b.id, {
            chord: root.toChord(combo),
            expr: b.expr,
            locked: b.locked,
            repeating: b.repeating,
            description: b.description
        });
        return clash ? `${combo} is also on ${clash.name} · change that one too` : "";
    }
}
