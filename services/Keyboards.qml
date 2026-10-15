pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "keyboards.js" as KeyboardsJs

Singleton {
    id: root

    readonly property string dir: `${Config.dir}/keyboards`

    readonly property string stored: Config.values.cheatsheet.keyboard ?? ""

    readonly property string path: root.stored ? `${root.dir}/${root.stored}` : ""

    readonly property string storedKeymap: Config.values.cheatsheet.keymap ?? ""

    readonly property string keymapPath: root.storedKeymap ? `${root.dir}/${root.storedKeymap}` : ""

    property var definition: null

    property var keymap: null

    property var board: null

    property var legends: ({})

    property string error: ""

    property string pending: ""

    property string pendingKeymap: ""

    property var verdict: null

    property string pendingVerdict: ""

    readonly property int keyCount: root.board ? root.board.sections[0].keys.length : 0

    function judge(ok: bool, said: string): void {
        const text = `${ok ? "this is it" : "this is not it"} · ${said}`;
        if (!ok)
            console.warn(`Keyboards: ${text}`);
        root.verdict = {
            ok: ok,
            detail: said,
            text: text,
            serial: (root.verdict?.serial ?? 0) + 1
        };
    }

    readonly property string shape: KeyboardsJs.shapeNamed(Config.values.cheatsheet.shape)

    readonly property var template: KeyboardsJs.templateSections(root.shape)

    readonly property string variant: root.board ? root.board.variant : root.shape

    readonly property var blocked: KeyboardsJs.blockedMap(Config.values.cheatsheet.blocked)

    function blockedNote(cell: var): var {
        const map = root.blocked;
        for (const s of cell.syms ?? [])
            if (map[s.toLowerCase()] !== undefined)
                return map[s.toLowerCase()];
        if (cell.matrix && map[cell.matrix.toLowerCase()] !== undefined)
            return map[cell.matrix.toLowerCase()];
        return null;
    }

    function use(rawPath: string): void {
        const trimmed = String(rawPath ?? "").trim();
        if (!trimmed)
            return root.clear();
        const expanded = trimmed === "~" || trimmed.startsWith("~/") ? `${Quickshell.env("HOME")}${trimmed.slice(1)}` : trimmed;

        root.error = "";
        if (reader.path === expanded)
            reader.reload();
        else
            reader.path = expanded;
    }

    function clear(): void {
        Config.set("cheatsheet.keyboard", "");
        root.error = "";
    }

    function useKeymap(rawPath: string): void {
        const trimmed = String(rawPath ?? "").trim();
        if (!trimmed)
            return root.clearKeymap();
        if (!root.definition)
            return root.judge(false, "import the board's VIA layout first, the keymap is placed on it");
        const expanded = trimmed === "~" || trimmed.startsWith("~/") ? `${Quickshell.env("HOME")}${trimmed.slice(1)}` : trimmed;

        root.error = "";
        if (keymapReader.path === expanded)
            keymapReader.reload();
        else
            keymapReader.path = expanded;
    }

    function clearKeymap(): void {
        Config.set("cheatsheet.keymap", "");
        root.error = "";
    }

    function assemble(): void {
        root.legends = ({});
        if (!root.definition) {
            root.board = null;
            return;
        }
        const aligned = KeyboardsJs.alignBoard(root.definition);
        if (!root.keymap) {
            root.board = aligned;
            return;
        }
        const made = KeyboardsJs.keymapLegends(root.definition, root.keymap);
        if (made.error) {
            root.board = aligned;
            root.clearKeymap();
            return root.fail(made.error);
        }
        root.legends = made.legends;
        root.board = KeyboardsJs.applyLegends(aligned, made.legends);
    }

    function keep(): void {
        Config.set("cheatsheet.keyboard", root.pending);
        root.judge(true, root.pendingVerdict);
    }

    function keepKeymap(): void {
        Config.set("cheatsheet.keymap", root.pendingKeymap);
        root.judge(true, root.pendingVerdict);
    }

    function fail(said: string): void {
        root.error = said;
        console.warn(`Keyboards: ${said}`);
    }

    function read(): void {
        if (!root.path) {
            root.definition = null;
            root.assemble();
            return;
        }
        if (keeper.path === root.path)
            keeper.reload();
        else
            keeper.path = root.path;
    }

    function readKeymap(): void {
        if (!root.keymapPath) {
            root.keymap = null;
            root.assemble();
            return;
        }
        if (mapKeeper.path === root.keymapPath)
            mapKeeper.reload();
        else
            mapKeeper.path = root.keymapPath;
    }

    onPathChanged: root.read()

    onKeymapPathChanged: root.readKeymap()

    Component.onCompleted: {
        root.read();
        root.readKeymap();
    }

    FileView {
        id: reader

        watchChanges: false
        printErrors: false

        onLoaded: {
            const parsed = KeyboardsJs.parseVia(reader.text());
            if (parsed.error)
                return root.judge(false, parsed.error);

            const aligned = KeyboardsJs.alignBoard(parsed);
            const base = (parsed.name || reader.path.split("/").pop().replace(/\.json$/i, "")).replace(/[^a-zA-Z0-9 ._()-]/g, " ").trim();
            root.pending = `${base || "keyboard"}.json`;
            root.pendingVerdict = `${parsed.name || base || "your board"}, ${aligned.sections[0].keys.length} keys, ${String(aligned.variant).toUpperCase()}. The hotkey sheet draws it now.`;
            const target = `${root.dir}/${root.pending}`;
            if (writer.path === target && writer.text() === reader.text())
                return root.keep();
            writer.path = target;
            writer.setText(reader.text());
        }

        onLoadFailed: root.judge(false, `could not read ${reader.path}`)
    }

    FileView {
        id: keeper

        watchChanges: true
        printErrors: false

        onFileChanged: keeper.reload()

        onLoaded: {
            if (!root.stored)
                return;
            const parsed = KeyboardsJs.parseVia(keeper.text());
            if (parsed.error)
                return root.fail(parsed.error);
            root.definition = parsed;
            root.assemble();
            root.error = "";
        }

        onLoadFailed: {
            if (!root.stored)
                return;
            root.definition = null;
            root.assemble();
            root.fail(`${root.stored} is missing from ${root.dir}`);
        }
    }

    FileView {
        id: keymapReader

        watchChanges: false
        printErrors: false

        onLoaded: {
            const parsed = KeyboardsJs.parseKeymap(keymapReader.text());
            if (parsed.error)
                return root.judge(false, parsed.error);
            const made = KeyboardsJs.keymapLegends(root.definition, parsed);
            if (made.error)
                return root.judge(false, made.error);

            root.pendingKeymap = `${root.stored.replace(/\.json$/i, "")}.keymap.json`;
            root.pendingVerdict = `${parsed.name || "The keymap"} names ${Object.keys(made.legends).length} keys. The ones you bind light up on the sheet.`;
            const target = `${root.dir}/${root.pendingKeymap}`;
            if (keymapWriter.path === target && keymapWriter.text() === keymapReader.text())
                return root.keepKeymap();
            keymapWriter.path = target;
            keymapWriter.setText(keymapReader.text());
        }

        onLoadFailed: root.judge(false, `could not read ${keymapReader.path}`)
    }

    FileView {
        id: mapKeeper

        watchChanges: true
        printErrors: false

        onFileChanged: mapKeeper.reload()

        onLoaded: {
            if (!root.storedKeymap)
                return;
            const parsed = KeyboardsJs.parseKeymap(mapKeeper.text());
            if (parsed.error)
                return root.fail(parsed.error);
            root.keymap = parsed;
            root.assemble();
        }

        onLoadFailed: {
            if (!root.storedKeymap)
                return;
            root.keymap = null;
            root.assemble();
            root.fail(`${root.storedKeymap} is missing from ${root.dir}`);
        }
    }

    FileView {
        id: writer

        watchChanges: true
        printErrors: false

        onFileChanged: writer.reload()

        onSaved: root.keep()

        onSaveFailed: root.judge(false, `could not write ${writer.path}`)
    }

    FileView {
        id: keymapWriter

        watchChanges: true
        printErrors: false

        onFileChanged: keymapWriter.reload()

        onSaved: root.keepKeymap()

        onSaveFailed: root.judge(false, `could not write ${keymapWriter.path}`)
    }
}
