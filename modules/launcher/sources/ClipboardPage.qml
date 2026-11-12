pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services
import qs.modules.controls
import "../../../services/clipboard-search.js" as ClipboardSearch
import "../../../services/clipboard-page.js" as Page
import "../../../services/colours.js" as Colours

Item {
    id: root

    property string typed: ""
    property string query: ""
    property var view: null

    readonly property var source: root.view?.source ?? null

    signal leave(var what)
    signal launch(var what)
    signal back
    signal retitle(string text)
    signal asks(Item item, var actions, real x, real y)

    readonly property var choices: Dictation.present ? Page.FILTERS.concat([
            {
                key: "speech",
                label: "Dictation",
                icon: "mic"
            }
        ]) : Page.FILTERS
    property int choice: 0
    readonly property string filterKey: root.choices[root.choice]?.key ?? "all"
    readonly property bool dictating: root.filterKey === "speech"

    function choose(index: int): void {
        root.choice = index;
        root.keptId = "";
        root.settle();
    }

    property double now: Date.now()
    property string keptId: ""
    property int selected: -1
    property string note: ""

    readonly property real rowPitch: Math.max(Appearance.sizes.rowHeight, Appearance.sizes.launcherIcon + Appearance.padding.small * 2)
    readonly property real headerPitch: Appearance.font.line.small + Appearance.padding.normal + Appearance.padding.small

    readonly property var pool: root.dictating ? Dictation.entries : Clipboard.entries
    readonly property var indexed: ClipboardSearch.index(root.pool, e => Clipboard.summarise(e))
    readonly property var found: root.query.trim() ? ClipboardSearch.find(root.indexed, root.query, true, 500) : root.pool
    readonly property var shaped: root.found.map(e => ({
                entry: e,
                shape: root.dictating ? "speech" : Page.shapeOf(e, Colours.parseColour)
            })).filter(it => root.dictating || Page.passes(it.shape, root.filterKey))
    readonly property var rows: Page.sections(root.shaped, root.now)

    readonly property var current: root.rows[root.selected]?.entry ? root.rows[root.selected] : null
    readonly property var currentRow: root.current && root.source ? root.source.row(root.current.entry) : null
    readonly property string shape: root.current?.shape ?? ""
    readonly property var entry: root.current?.entry ?? null
    readonly property var colour: root.entry && root.shape === "colour" ? Page.colourOf(root.entry, Colours.parseColour) : null
    readonly property string picture: root.entry && root.shape === "image" ? root.entry.file || (root.entry.paths ?? [])[0] || "" : ""
    readonly property bool masked: !!root.currentRow?.masked

    readonly property string body: {
        if (!root.entry)
            return "";
        if (root.masked)
            return Clipboard.mask;
        if (root.shape === "json")
            return root.pretty(root.entry.text);
        return root.entry.text ?? "";
    }

    function pretty(text: string): string {
        try {
            return JSON.stringify(JSON.parse(text), null, 2);
        } catch (e) {
            return text ?? "";
        }
    }

    readonly property var facts: {
        if (!root.entry)
            return [];
        const out = Page.facts(root.entry, root.shape, root.colour, Colours.FORMS);
        if (root.masked)
            out.splice(1);
        if (root.entry.app)
            out.push({
                label: "Source",
                value: Apps.nameFor(root.entry.app)
            });
        const size = Clipboard.size(root.entry.bytes);
        if (size)
            out.push({
                label: "Size",
                value: size
            });
        const when = new Date(root.entry.recorded);
        out.push({
            label: "Copied",
            value: `${TimeFormat.changed(when)} at ${TimeFormat.time(when, false)}`
        });
        return out;
    }

    onQueryChanged: {
        root.keptId = "";
        root.note = "";
    }
    onRowsChanged: root.settle()
    Component.onCompleted: root.settle()

    function firstFrom(at: int, step: int): int {
        for (let i = at; i >= 0 && i < root.rows.length; i += step)
            if (!root.rows[i].header)
                return i;
        return -1;
    }

    function settle(): void {
        const kept = root.keptId ? root.rows.findIndex(r => !r.header && r.entry.id === root.keptId) : -1;
        if (kept >= 0)
            root.selected = kept;
        else if (root.keptId) {
            const near = root.firstFrom(Math.min(Math.max(0, root.selected), root.rows.length - 1), 1);
            root.selected = near >= 0 ? near : root.firstFrom(root.rows.length - 1, -1);
            root.keptId = root.rows[root.selected]?.entry?.id ?? "";
        } else {
            const fresh = root.query.trim() ? -1 : root.rows.findIndex(r => !r.header && !r.entry.pinned);
            root.selected = fresh >= 0 ? fresh : root.firstFrom(0, 1);
        }
        if (root.selected >= 0)
            list.reveal(root.selected);
    }

    function select(index: int): void {
        if (index < 0 || !root.rows[index] || root.rows[index].header)
            return;
        root.selected = index;
        root.keptId = root.rows[index].entry.id;
        list.reveal(index);
    }

    function move(delta: int): void {
        let at = root.selected;
        const step = delta > 0 ? 1 : -1;
        for (let n = 0; n < Math.abs(delta); n++) {
            const next = root.firstFrom(at + step, step);
            if (next < 0)
                break;
            at = next;
        }
        root.select(at);
    }

    function useIt(): void {
        if (!root.currentRow || !root.source)
            return;
        if (root.dictating)
            Dictation.use(root.entry);
        root.source.activate(root.currentRow);
    }

    function copyAs(text: string): void {
        root.source.search.leave(() => Clipboard.copy({
                text: text
            }));
    }

    function openOut(url: string): void {
        root.source.search.launch(() => Quickshell.execDetached(["xdg-open", url]));
    }

    function extras(): var {
        const entry = root.entry;
        const text = String(entry.text ?? "").trim();
        const out = [];
        switch (root.shape) {
        case "colour":
            for (const form of ["hex", "rgb", "hsl"])
                out.push({
                    icon: "palette",
                    label: `Copy as ${form === "hex" ? "hex" : form.toUpperCase()}`,
                    run: () => root.copyAs(Colours.FORMS[form](root.colour))
                });
            break;
        case "link":
            out.push({
                icon: "open_in_new",
                label: "Open in the browser",
                run: () => root.openOut(text)
            });
            break;
        case "email":
            out.push({
                icon: "mail",
                label: "Write an email",
                run: () => root.openOut(`mailto:${Page.emailOf(text)}`)
            });
            break;
        case "image":
        case "file":
        case "files":
            {
                const paths = Clipboard.pathsOf(entry);
                const first = paths[0] ?? (text.startsWith("/") ? text : "");
                if (first)
                    out.push({
                        icon: "open_in_new",
                        label: paths.length > 1 ? "Open the first" : "Open",
                        run: () => root.openOut(`file://${first}`)
                    }, {
                        icon: "folder_open",
                        label: "Show in its folder",
                        run: () => root.openOut(`file://${first.slice(0, first.lastIndexOf("/")) || "/"}`)
                    });
                if (paths.length)
                    out.push({
                        icon: "content_copy",
                        label: paths.length > 1 ? "Copy the paths" : "Copy the path",
                        run: () => root.source.search.leave(() => Clipboard.copyPath(entry))
                    });
            }
            break;
        case "json":
            {
                const tidy = root.pretty(text);
                if (tidy !== text)
                    out.push({
                        icon: "data_object",
                        label: "Copy formatted",
                        run: () => root.copyAs(tidy)
                    });
                try {
                    const line = JSON.stringify(JSON.parse(text));
                    if (line !== text)
                        out.push({
                            icon: "short_text",
                            label: "Copy on one line",
                            run: () => root.copyAs(line)
                        });
                } catch (e) {}
            }
            break;
        }
        return out;
    }

    function actions(): var {
        const row = root.currentRow;
        if (!row || !root.source)
            return [];
        if (root.dictating)
            return [
                {
                    icon: Typist.found ? "content_paste_go" : "content_copy",
                    label: Typist.found ? "Paste" : "Copy",
                    run: () => root.useIt()
                },
                {
                    icon: "content_copy",
                    label: "Copy",
                    run: () => root.copyAs(root.entry.text ?? "")
                },
                {
                    icon: "delete",
                    label: "Delete",
                    alarm: true,
                    run: () => Dictation.drop(root.entry)
                }
            ];
        const own = root.source.actionsFor(row).map(a => a.label === "Delete" ? Object.assign({}, a, {
                run: () => root.discard()
            }) : a);
        const lead = own.findIndex(a => a.label === "Show" || a.label === "Hide" || a.icon === "push_pin");
        const cut = lead < 0 ? own.length : lead;
        const out = own.slice(0, cut).concat(root.masked ? [] : root.extras(), own.slice(cut));
        if (Clipboard.unpinned > 0)
            out.push({
                icon: "delete_sweep",
                label: "Clear history",
                alarm: true,
                tucked: true,
                run: () => root.askClear()
            });
        return out;
    }

    function discard(): void {
        if (!root.entry)
            return;
        if (root.dictating) {
            Dictation.drop(root.entry);
            return;
        }
        Clipboard.remove(root.entry);
        root.note = "Deleted, Ctrl Z brings it back";
    }

    function askClear(): void {
        const n = Clipboard.unpinned;
        const pinned = Clipboard.entries.length - n;
        Qt.callLater(() => root.asks(footer, [
                {
                    icon: "delete_sweep",
                    label: `Clear ${n === 1 ? "1 item" : `${n} items`}${pinned ? `, ${pinned} pinned stay` : ""}`,
                    alarm: true,
                    run: () => {
                        root.source.clear();
                        root.note = "Cleared, Ctrl Z brings it back";
                    }
                },
                {
                    icon: "close",
                    label: "Keep them",
                    run: () => {}
                }
            ], footer.width - Appearance.padding.large, 0));
    }

    function openActions(): void {
        const acts = root.actions();
        if (!acts.length)
            return;
        const item = list.itemAtIndex(root.selected) ?? footer;
        root.asks(item, acts, item.width / 2, item.height / 2);
    }

    function claimKey(event: var): bool {
        const ctrl = event.modifiers & Qt.ControlModifier;
        switch (event.key) {
        case Qt.Key_Down:
            root.move(1);
            return true;
        case Qt.Key_Up:
            root.move(-1);
            return true;
        case Qt.Key_PageDown:
            root.move(8);
            return true;
        case Qt.Key_PageUp:
            root.move(-8);
            return true;
        case Qt.Key_Tab:
        case Qt.Key_Backtab:
            root.choose((root.choice + (event.key === Qt.Key_Tab ? 1 : root.choices.length - 1)) % root.choices.length);
            return true;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (ctrl) {
                root.actions().slice(1).find(a => !a.tucked)?.run();
                return true;
            }
            root.useIt();
            return true;
        case Qt.Key_K:
            if (!ctrl)
                return false;
            root.openActions();
            return true;
        case Qt.Key_Z:
            if (!ctrl || !Clipboard.shelved)
                return false;
            Clipboard.undo();
            root.note = "";
            return true;
        case Qt.Key_Delete:
            if (!(event.modifiers & Qt.ShiftModifier))
                return false;
            root.discard();
            return true;
        case Qt.Key_Menu:
            root.openActions();
            return true;
        case Qt.Key_Backspace:
            if (root.query !== "")
                return false;
            root.back();
            return true;
        }
        return false;
    }

    implicitHeight: root.rowPitch * 12 + footer.implicitHeight

    GlideList {
        id: list

        width: Math.round(root.width * 0.4)
        height: root.height - footer.height - Appearance.padding.small
        clip: true
        model: ScriptModel {
            values: root.rows
        }

        delegate: Item {
            id: line

            required property var modelData
            required property int index

            readonly property var shaped: line.modelData.header ? null : line.modelData
            readonly property var made: line.shaped && root.source ? root.source.row(line.shaped.entry) : null
            readonly property var swatch: line.shaped?.shape === "colour" ? Page.colourOf(line.shaped.entry, Colours.parseColour) : null

            width: list.width
            height: line.modelData.header ? root.headerPitch : root.rowPitch

            StyledText {
                visible: !!line.modelData.header
                anchors.left: parent.left
                anchors.leftMargin: Appearance.padding.normal
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Appearance.padding.small / 2
                text: line.modelData.title ?? ""
                font.pixelSize: Appearance.font.size.small
                color: Appearance.colour.textFaint
            }

            MenuRow {
                visible: !line.modelData.header
                width: parent.width
                height: parent.height
                iconSize: Appearance.sizes.launcherIcon
                rowHeight: root.rowPitch
                labelSize: Appearance.font.size.normal
                icon: line.made?.secret ? "visibility_off" : (Page.SHAPES[line.shaped?.shape]?.icon ?? "notes")
                iconSource: line.shaped?.shape === "image" ? line.made?.iconSource ?? "" : ""
                mark: line.swatch ? swatchMark : null
                label: line.shaped?.shape === "image" ? `Image${line.shaped.entry.w > 0 ? ` (${line.shaped.entry.w}×${line.shaped.entry.h})` : ""}` : line.made?.label ?? ""
                selected: line.index === root.selected
                askable: true
                onActivated: {
                    root.select(line.index);
                    root.useIt();
                }
                onAsked: (x, y) => {
                    root.select(line.index);
                    root.openActions();
                }
            }

            Component {
                id: swatchMark

                SquircleRect {
                    width: Appearance.sizes.launcherIcon
                    height: Appearance.sizes.launcherIcon
                    radius: Appearance.rounding.small
                    color: line.swatch ? Qt.rgba(line.swatch.r / 255, line.swatch.g / 255, line.swatch.b / 255, line.swatch.a) : "transparent"
                    stroke: Appearance.colour.seam
                    strokeWidth: Appearance.stroke.line
                }
            }
        }
    }

    StyledText {
        visible: !root.rows.length
        x: Appearance.padding.normal
        y: Appearance.padding.normal
        width: list.width - Appearance.padding.normal * 2
        text: root.query ? `Nothing copied matches “${root.query}”` : Clipboard.entries.length ? `No ${(root.choices[root.choice]?.label ?? "").toLowerCase()} copied yet` : "Nothing copied yet"
        font.pixelSize: Appearance.font.size.normal
        color: Appearance.colour.textFaint
        wrapMode: Text.Wrap
    }

    Rectangle {
        x: list.width + Appearance.padding.normal
        width: Appearance.stroke.line
        height: list.height
        color: Appearance.colour.separator
    }

    Item {
        id: pane

        x: list.width + Appearance.padding.normal * 2
        width: root.width - x
        height: list.height
        visible: !!root.entry

        Item {
            id: stage

            width: pane.width
            height: Math.max(Appearance.font.line.large * 3, infoHead.y - Appearance.padding.large)

            SquircleImage {
                anchors.fill: parent
                visible: root.picture !== ""
                source: root.picture ? `file://${root.picture}` : ""
                fillMode: Image.PreserveAspectFit
                radius: Appearance.rounding.normal
            }

            Column {
                anchors.centerIn: parent
                visible: root.shape === "colour" && !!root.colour
                spacing: Appearance.padding.normal

                SquircleRect {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.round(stage.height * 0.62)
                    height: width
                    radius: Appearance.rounding.large
                    color: root.colour ? Qt.rgba(root.colour.r / 255, root.colour.g / 255, root.colour.b / 255, root.colour.a) : "transparent"
                    stroke: Appearance.colour.seam
                    strokeWidth: Appearance.stroke.line
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.colour ? Colours.FORMS.hex(root.colour).toUpperCase() : ""
                    font.pixelSize: Appearance.font.size.large
                    font.weight: Font.DemiBold
                }
            }

            Column {
                anchors.centerIn: parent
                width: parent.width - Appearance.padding.large * 2
                visible: !root.masked && (root.shape === "link" || root.shape === "email" || (root.shape === "file" || root.shape === "files") && !root.picture)
                spacing: Appearance.padding.normal

                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: Page.SHAPES[root.shape]?.icon ?? ""
                    size: Appearance.icon.hero
                    color: Appearance.colour.textDim
                }

                StyledText {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: {
                        const text = String(root.entry?.text ?? "").trim();
                        if (root.shape === "link")
                            return Page.linkParts(text)?.host || text;
                        if (root.shape === "email")
                            return Page.emailOf(text);
                        const paths = Clipboard.pathsOf(root.entry);
                        return paths.length > 1 ? `${paths.length} files` : Clipboard.basename(paths[0] ?? text);
                    }
                    font.pixelSize: Appearance.font.size.large
                    font.weight: Font.DemiBold
                    elide: Text.ElideMiddle
                }

                StyledText {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    visible: root.shape !== "email"
                    text: root.shape === "link" ? String(root.entry?.text ?? "").trim() : Clipboard.pathsOf(root.entry).join("\n") || String(root.entry?.text ?? "").trim()
                    font.pixelSize: Appearance.font.size.small
                    color: Appearance.colour.textFaint
                    wrapMode: Text.WrapAnywhere
                    maximumLineCount: 4
                    elide: Text.ElideRight
                }
            }

            StyledText {
                anchors.centerIn: parent
                visible: root.masked
                text: Clipboard.mask
                font.pixelSize: Appearance.font.size.large
                color: Appearance.colour.textDim
            }

            SquircleRect {
                id: textCard

                anchors.fill: parent
                visible: !root.masked && ["text", "speech", "code", "json"].includes(root.shape)
                radius: Appearance.rounding.normal
                color: Appearance.colour.tile

                CodeBlock {
                    anchors.fill: parent
                    anchors.margins: Appearance.padding.normal
                    text: textCard.visible ? root.body.slice(0, 20000) : ""
                    language: root.shape === "json" ? "json" : ""
                    wrap: root.shape === "text" || root.shape === "speech"
                    gutter: root.shape === "code" || root.shape === "json"
                }
            }
        }

        StyledText {
            id: infoHead

            y: factList.y - height - Appearance.padding.small
            x: Appearance.padding.small
            text: "Information"
            font.pixelSize: Appearance.font.size.small
            color: Appearance.colour.textFaint
        }

        Column {
            id: factList

            y: pane.height - height
            width: pane.width

            Repeater {
                model: root.facts

                delegate: Item {
                    id: fact

                    required property var modelData
                    required property int index

                    width: pane.width
                    height: Appearance.font.line.small + Appearance.padding.normal

                    SquircleRect {
                        anchors.fill: parent
                        visible: fact.index % 2 === 0
                        radius: Appearance.rounding.small
                        color: Appearance.colour.tile
                    }

                    StyledText {
                        anchors.left: parent.left
                        anchors.leftMargin: Appearance.padding.small
                        anchors.verticalCenter: parent.verticalCenter
                        text: fact.modelData.label
                        font.pixelSize: Appearance.font.size.small
                        color: Appearance.colour.textFaint
                    }

                    StyledText {
                        anchors.right: parent.right
                        anchors.rightMargin: Appearance.padding.small
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, parent.width * 0.65)
                        horizontalAlignment: Text.AlignRight
                        text: fact.modelData.value
                        font.pixelSize: Appearance.font.size.small
                        color: Appearance.colour.textDim
                        elide: Text.ElideMiddle
                    }
                }
            }
        }
    }

    PageFooter {
        id: footer

        anchors.bottom: parent.bottom
        width: root.width
        icon: "content_paste"
        title: `${root.dictating ? "Dictation" : "Clipboard history"}${root.rows.length ? ` · ${root.shaped.length === 1 ? "1 item" : `${root.shaped.length} items`}` : ""}`
        note: root.note
        primary: root.entry ? Typist.found ? "Paste" : "Copy" : ""
        onPrimed: root.useIt()
        onAsked: root.openActions()
    }
}
