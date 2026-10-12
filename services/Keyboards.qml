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

    property var board: null

    property string error: ""

    property string pending: ""

    readonly property var template: KeyboardsJs.TEMPLATE

    readonly property string variant: root.board ? root.board.variant : KeyboardsJs.TEMPLATE_VARIANT

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

    function fail(said: string): void {
        root.error = said;
        console.warn(`Keyboards: ${said}`);
    }

    function read(): void {
        if (!root.path) {
            root.board = null;
            return;
        }
        if (keeper.path === root.path)
            keeper.reload();
        else
            keeper.path = root.path;
    }

    onPathChanged: root.read()

    Component.onCompleted: root.read()

    FileView {
        id: reader

        watchChanges: false
        printErrors: false

        onLoaded: {
            const parsed = KeyboardsJs.parseVia(reader.text());
            if (parsed.error)
                return root.fail(parsed.error);

            const base = (parsed.name || reader.path.split("/").pop().replace(/\.json$/i, "")).replace(/[^a-zA-Z0-9 ._()-]/g, " ").trim();
            root.pending = `${base || "keyboard"}.json`;
            writer.path = `${root.dir}/${root.pending}`;
            writer.setText(reader.text());
        }

        onLoadFailed: root.fail(`could not read ${reader.path}`)
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
            root.board = KeyboardsJs.alignBoard(parsed);
            root.error = "";
        }

        onLoadFailed: {
            if (!root.stored)
                return;
            root.board = null;
            root.fail(`${root.stored} is missing from ${root.dir}`);
        }
    }

    FileView {
        id: writer

        watchChanges: false
        printErrors: false

        onSaved: Config.set("cheatsheet.keyboard", root.pending)

        onSaveFailed: root.fail(`could not write ${writer.path}`)
    }
}
