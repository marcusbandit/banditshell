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
import "../../../services/dictation-events.js" as DictationEvents
import "../../../services/link-facts.js" as Links

Item {
    id: root

    property string typed: ""
    property string query: ""
    property string selection: ""
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
    property bool reading: false

    readonly property bool undoable: !root.dictating && Clipboard.shelved > 0
    property string savedSnippet: ""

    Timer {
        id: savedFade

        interval: 4000
        onTriggered: root.savedSnippet = ""
    }

    function saveSnippet(): void {
        root.savedSnippet = root.source.saveAsSnippet(root.entry);
        savedFade.restart();
    }

    readonly property string note: {
        if (root.savedSnippet)
            return `Saved as snippet “${root.savedSnippet}”`;
        if (!root.undoable)
            return "";
        const gone = Clipboard.shelfKind === "delete" ? Clipboard.shelved === 1 ? "Deleted" : `${Clipboard.shelved} deleted` : Clipboard.shelfKept > 0 ? `${Clipboard.shelved} cleared, ${Clipboard.shelfKept} pinned kept` : `${Clipboard.shelved} cleared`;
        return `${gone} · Ctrl Z or click to undo`;
    }
    readonly property bool telling: !root.dictating && !!Clipboard.recovery
    readonly property var told: Clipboard.recovery ?? ({})
    property bool toldOnce: false

    onTellingChanged: if (root.telling)
        root.toldOnce = true
    Component.onDestruction: {
        Clipboard.releaseShelf(root);
        if (root.toldOnce)
            Clipboard.recoverySeen();
    }

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
    readonly property string address: root.shape === "link" ? String(root.entry?.text ?? "").trim() : ""
    readonly property var linkInfo: root.address ? Links.describe(root.address) : null
    readonly property var linkPage: root.address ? LinkPreviews.pages[root.address] ?? null : null

    onAddressChanged: if (root.address && !root.currentRow?.secret)
        LinkPreviews.look(root.address)

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
        const out = root.linkInfo ? Links.factsOf(root.linkInfo) : Page.facts(root.entry, root.shape, root.colour, Colours.FORMS);
        if (root.masked)
            out.splice(1);
        if (root.entry.app)
            out.push({
                label: "Source",
                value: Apps.nameFor(root.entry.app)
            });
        const size = root.linkInfo ? "" : Clipboard.size(root.entry.bytes);
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

    onQueryChanged: root.keptId = ""
    onViewChanged: {
        const at = root.view?.choice ? root.choices.findIndex(c => c.key === root.view.choice) : -1;
        if (at >= 0)
            root.choose(at);
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

    property int clickedAt: -1
    property double clickedWhen: 0

    function clicked(index: int): void {
        const now = Date.now();
        const twice = index === root.clickedAt && now - root.clickedWhen <= Qt.styleHints.mouseDoubleClickInterval;
        root.clickedAt = twice ? -1 : index;
        root.clickedWhen = now;
        root.select(index);
        if (twice)
            root.useIt();
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

    function fileUrl(path: string): string {
        return `file://${String(path).split("/").map(encodeURIComponent).join("/")}`;
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
            {
                const tidy = Links.clean(text);
                const title = Links.bestTitle(root.linkInfo, root.linkPage) || text;
                out.push({
                    icon: "open_in_new",
                    label: "Open in the browser",
                    run: () => root.openOut(text)
                });
                if (tidy !== text)
                    out.push({
                        icon: "link_off",
                        label: "Copy without tracking",
                        run: () => root.copyAs(tidy)
                    });
                out.push({
                    icon: "markdown",
                    label: "Copy as a Markdown link",
                    run: () => root.copyAs(`[${title.replace(/[\[\]]/g, "")}](${tidy})`)
                }, {
                    icon: "language",
                    label: "Copy the site",
                    run: () => root.copyAs(root.linkInfo?.host ?? text)
                });
            }
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
                        run: () => root.openOut(root.fileUrl(first))
                    }, {
                        icon: "folder_open",
                        label: "Show in its folder",
                        run: () => root.openOut(root.fileUrl(first.slice(0, first.lastIndexOf("/")) || "/"))
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
                    icon: root.source?.pasting ? "content_paste_go" : "content_copy",
                    label: root.source?.pasting ? "Paste" : "Copy",
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
            }) : a.label === "Save as snippet" ? Object.assign({}, a, {
                run: () => root.saveSnippet()
            }) : a);
        own.splice(own.findIndex(a => a.icon === "push_pin") >= 0 ? own.findIndex(a => a.icon === "push_pin") : own.length, 0, {
            icon: root.reading ? "close_fullscreen" : "open_in_full",
            label: root.reading ? "Back to the list" : "View it whole",
            run: () => root.reading = !root.reading
        });
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
    }

    function askClear(): void {
        const n = Clipboard.unpinned;
        const pinned = Clipboard.entries.length - n;
        Qt.callLater(() => root.asks(footer, [
                {
                    icon: "delete_sweep",
                    label: `Clear ${n === 1 ? "1 item" : `${n} items`}${pinned ? `, ${pinned} pinned stay` : ""}`,
                    alarm: true,
                    run: () => root.source.clear()
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

    function claimEscape(): bool {
        if (!root.reading)
            return false;
        root.reading = false;
        return true;
    }

    function claimKey(event: var): bool {
        const ctrl = event.modifiers & Qt.ControlModifier;
        const empty = root.query === "";
        switch (event.key) {
        case Qt.Key_C:
            if (!ctrl || root.selection !== "" || !root.entry)
                return false;
            root.actions().find(a => a.label === "Copy")?.run();
            return true;
        case Qt.Key_P:
            if (!ctrl || root.dictating || !root.entry)
                return false;
            Clipboard.setPinned(root.entry, !root.entry.pinned);
            return true;
        case Qt.Key_Right:
            if (!empty || root.reading || !root.entry)
                return false;
            root.reading = true;
            return true;
        case Qt.Key_Left:
            if (!root.reading)
                return false;
            root.reading = false;
            return true;
        case Qt.Key_Home:
            if (!empty)
                return false;
            root.select(root.firstFrom(0, 1));
            return true;
        case Qt.Key_End:
            if (!empty)
                return false;
            root.select(root.firstFrom(root.rows.length - 1, -1));
            return true;
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
            if (!ctrl || !root.undoable)
                return false;
            Clipboard.undo();
            return true;
        case Qt.Key_Delete:
            if (!empty && !(event.modifiers & Qt.ShiftModifier))
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

    implicitHeight: root.rowPitch * 14 + footer.implicitHeight

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onWheel: wheel => wheel.accepted = true
    }

    Item {
        id: banner

        width: list.width
        height: root.telling ? bannerText.implicitHeight + (bannerCopy.visible ? bannerCopy.height + Appearance.padding.small : 0) + Appearance.padding.normal * 2 : 0
        visible: root.telling && !root.reading

        SquircleRect {
            anchors.fill: parent
            radius: Appearance.rounding.normal
            color: Appearance.colour.warningFill
        }

        StyledText {
            id: bannerText

            x: Appearance.padding.normal
            y: Appearance.padding.normal
            width: parent.width - Appearance.padding.normal * 2
            text: root.told.of > root.told.kept ? `The history file was damaged. Kept ${root.told.kept} of ${root.told.of} entries.` : `The history file was damaged. Kept ${root.told.kept === 1 ? "1 entry" : `${root.told.kept ?? 0} entries`}.`
            font.pixelSize: Appearance.font.size.small
            color: Appearance.colour.warning
            wrapMode: Text.Wrap
        }

        Button {
            id: bannerCopy

            visible: !!root.told.copy
            x: Appearance.padding.small
            y: bannerText.y + bannerText.height + Appearance.padding.small
            style: "bare"
            size: 0
            icon: "content_copy"
            text: "Copy the damaged file's path"
            onClicked: Clipboard.offer(["wl-copy", "-n"], root.told.copy, false)
        }
    }

    GlideList {
        id: list

        y: banner.visible ? banner.height + Appearance.padding.small : 0
        width: Math.round(root.width * 0.4)
        height: root.height - footer.height - Appearance.padding.small - y
        visible: !root.reading
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
            readonly property string address: line.shaped?.shape === "link" ? String(line.shaped.entry.text ?? "").trim() : ""
            readonly property var info: line.address ? Links.describe(line.address) : null
            readonly property var site: line.address ? LinkPreviews.pages[line.address] ?? null : null


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
                icon: line.made?.secret ? "visibility_off" : line.info ? line.info.mark : (Page.SHAPES[line.shaped?.shape]?.icon ?? "notes")
                iconSource: line.shaped?.shape === "image" ? line.made?.iconSource ?? "" : line.site?.icon ? `file://${line.site.icon}` : ""
                mark: line.swatch ? swatchMark : null
                inlineDetail: true
                detail: line.info ? line.info.host : ""
                label: line.shaped?.shape === "image" ? `Image${line.shaped.entry.w > 0 ? ` (${line.shaped.entry.w}×${line.shaped.entry.h})` : ""}` : line.info ? Links.bestTitle(line.info, line.site) : line.made?.label ?? ""
                selected: line.index === root.selected
                askable: true
                tips: false
                onActivated: root.clicked(line.index)
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
                    color: Page.swatchOf(line.swatch)
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
        text: {
            if (root.query)
                return root.dictating ? `Nothing dictated matches “${root.query}”` : `Nothing copied matches “${root.query}”`;
            if (root.dictating) {
                const key = DictationEvents.startKey(HyprConfig.binds);
                return key ? `Nothing has been dictated yet. ${key} starts it.` : "Nothing has been dictated yet.";
            }
            if (!Clipboard.entries.length)
                return Clipboard.wasCleared ? "History cleared." : "Nothing has been copied yet.";
            return `No ${(root.choices[root.choice]?.label ?? "").toLowerCase()} copied yet`;
        }
        font.pixelSize: Appearance.font.size.normal
        color: Appearance.colour.textFaint
        wrapMode: Text.Wrap
    }

    Rectangle {
        visible: !root.reading
        x: list.width + Appearance.padding.normal
        width: Appearance.stroke.line
        height: root.height - footer.height - Appearance.padding.small
        color: Appearance.colour.separator
    }

    Item {
        id: pane

        x: root.reading ? 0 : list.width + Appearance.padding.normal * 2
        width: root.width - x
        height: root.height - footer.height - Appearance.padding.small
        visible: !!root.entry

        Item {
            id: stage

            width: pane.width
            height: root.reading ? pane.height : Math.max(Appearance.font.line.large * 3, infoHead.y - Appearance.padding.large)
            clip: true

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
                    color: Page.swatchOf(root.colour)
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
                visible: !root.masked && (root.shape === "email" || (root.shape === "file" || root.shape === "files") && !root.picture)
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

            Column {
                id: linkCard

                readonly property string shot: root.linkPage?.image ?? ""
                readonly property string icon: root.linkPage?.icon ?? ""

                y: Math.max(0, Math.round((stage.height - implicitHeight) / 2))
                width: parent.width
                visible: !root.masked && root.shape === "link" && !!root.linkInfo
                spacing: Appearance.padding.normal

                SquircleImage {
                    id: linkShot

                    width: parent.width
                    height: linkCard.shot ? Math.min(Math.round(stage.height * 0.45), Math.round(width / 1.91)) : 0
                    visible: height > 0 && status !== Image.Error
                    source: linkCard.shot ? `file://${linkCard.shot}` : ""
                    fillMode: Image.PreserveAspectCrop
                    radius: Appearance.rounding.normal
                }

                Row {
                    width: parent.width
                    spacing: Appearance.padding.normal

                    Item {
                        width: Appearance.icon.huge
                        height: width

                        Image {
                            id: favicon

                            anchors.fill: parent
                            visible: status === Image.Ready
                            source: linkCard.icon ? `file://${linkCard.icon}` : ""
                            sourceSize.width: width * 2
                            sourceSize.height: height * 2
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            smooth: true
                        }

                        Icon {
                            anchors.centerIn: parent
                            visible: favicon.status !== Image.Ready
                            name: root.linkInfo?.mark ?? "link"
                            size: Appearance.icon.large
                            color: Appearance.colour.textDim
                        }
                    }

                    Column {
                        width: parent.width - Appearance.icon.huge - parent.spacing
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Appearance.padding.hair

                        StyledText {
                            width: parent.width
                            text: Links.bestTitle(root.linkInfo, root.linkPage)
                            font.pixelSize: Appearance.font.size.large
                            font.weight: Font.DemiBold
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }

                        StyledText {
                            width: parent.width
                            text: `${root.linkInfo?.kind ?? ""} · ${root.linkInfo?.host ?? ""}`
                            font.pixelSize: Appearance.font.size.small
                            color: Appearance.colour.textFaint
                            elide: Text.ElideRight
                        }
                    }
                }

                StyledText {
                    width: parent.width
                    visible: text !== ""
                    text: root.linkPage?.description ?? ""
                    font.pixelSize: Appearance.font.size.small
                    color: Appearance.colour.textDim
                    wrapMode: Text.Wrap
                    maximumLineCount: linkShot.visible ? 2 : 4
                    elide: Text.ElideRight
                }

                StyledText {
                    width: parent.width
                    text: Links.masked(root.address)
                    font.pixelSize: Appearance.font.size.small
                    color: Appearance.colour.textFaint
                    wrapMode: Text.WrapAnywhere
                    maximumLineCount: 2
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

            visible: !root.reading
            y: factList.y - height - Appearance.padding.small
            x: Appearance.padding.small
            text: "Information"
            font.pixelSize: Appearance.font.size.small
            color: Appearance.colour.textFaint
        }

        Column {
            id: factList

            visible: !root.reading
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
        onNoteTapped: Clipboard.undo()
        onNoteHoveredChanged: if (footer.noteHovered)
            Clipboard.holdShelf(root);
        else
            Clipboard.releaseShelf(root)
        primary: root.entry ? root.source?.pasting ? "Paste" : "Copy" : ""
        onPrimed: root.useIt()
        onAsked: root.openActions()
    }
}
