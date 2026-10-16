pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services
import qs.modules.controls
import "search.js" as Search

LauncherConcept {
    id: root

    surface: panel
    input: query
    view: list
    rowPitch: Math.max(Appearance.sizes.rowHeight, Appearance.sizes.launcherIcon + Appearance.padding.small * 2)
    travel: panel.implicitHeight

    readonly property int resultCount: results.length
    readonly property string scrollInfo: `row ${root.selected} of ${root.results.length}, at ${Math.round(list.contentY)}/${Math.round(list.maxScroll)}`

    readonly property real panelWidth: Appearance.sizes.launcherWidth

    property bool collapseToCentre: false

    property var capture: null
    property string beforeCapture: ""

    readonly property var results: root.capture ? search.keyed([Object.assign({}, root.capture.row, {
                    detail: root.capture.said || root.capture.row.detail
                })]) : search.rows
    property int selected: 0

    readonly property real headerPitch: Appearance.font.line.small + Appearance.padding.normal + Appearance.padding.small

    readonly property int buttonLimit: 3

    property bool symbolsOpen: false

    readonly property var symbolKeys: Search.SYMBOL_KEYS

    function insert(text: string): void {
        root.input.insert(root.input.cursorPosition, text);
        root.input.forceActiveFocus();
    }

    function back(): void {
        if (root.symbolsOpen)
            root.symbolsOpen = false;
        else
            root.hide();
    }

    answerless: search.intent || !!root.capture

    LauncherSearch {
        id: search

        query: root.input?.text ?? ""
        screenName: root.screenName
        quiet: !!root.capture
        target: root.restoreTo

        onLaunch: what => root.launch(what)
        onLeave: what => {
            root.hide();
            what();
        }
        onRetype: text => {
            root.input.text = text;
            root.input.cursorPosition = text.length;
        }
    }

    readonly property int pinnedLimit: 12
    readonly property int tileColumns: Math.ceil(root.pinnedLimit / 2)

    readonly property var pinnedApps: Config.values.launcher.list.pinned ? Apps.starredApps.slice(0, root.pinnedLimit) : []
    readonly property var recentApps: Config.values.launcher.list.recents ? Apps.recent(root.tileColumns, root.pinnedApps) : []

    readonly property int pinnedRows: Math.ceil(root.pinnedApps.length / root.tileColumns)

    readonly property var tiles: {
        const out = [];
        const place = (apps, pinned, firstRow) => apps.forEach((entry, i) => {
                const row = Math.floor(i / root.tileColumns);
                const across = Math.min(root.tileColumns, apps.length - row * root.tileColumns);
                out.push({
                    entry: entry,
                    pinned: pinned,
                    row: firstRow + row,
                    slot: i % root.tileColumns - (across - 1) / 2
                });
            });
        place(root.pinnedApps, true, 0);
        place(root.recentApps, false, root.pinnedRows);
        return out;
    }

    readonly property bool quick: !root.capture && !query.text && root.tiles.length > 0
    property int tile: 0

    readonly property bool asking: sheet.open

    property Item tipHost: null

    function tip(item: Item, text: string, drop: real, on: bool): void {
        if (!on) {
            if (root.tipHost === item)
                root.tipHost = null;
            return;
        }
        root.tipHost = item;
        hint.text = text;
        const at = item.mapToItem(panel, item.width / 2, drop);
        hint.x = Math.round(at.x - hint.width / 2);
        hint.y = Math.round(at.y + Appearance.padding.small);
    }

    readonly property real longestFrame: 1 / 60

    property real wave: 0
    readonly property real waveTarget: (root.shown || root.dragging) && root.quick ? root.tiles.length : 0

    onQuickChanged: root.tile = 0
    onTilesChanged: root.tile = Math.min(root.tile, Math.max(0, root.tiles.length - 1))

    onShowing: {
        root.collapseToCentre = false;
        root.unsized = true;
        root.symbolsOpen = false;
        FileSearch.forget();
    }

    onCleared: {
        root.selected = 0;
        root.tile = 0;
        if (root.unsized) {
            root.unsized = false;
            grow.value = panel.implicitHeight;
            gridIn.snap();
        }
    }

    onHidden: {
        sheet.close();
        root.capture = null;
        search.armed = "";
        root.collapseToCentre = !panel.bottomAnchored;
    }

    onDropped: stayedOpen => {
        if (!stayedOpen)
            root.collapseToCentre = false;
    }

    function accept(): void {
        if (root.capture)
            return;
        if (root.copyAnswer())
            return;

        if (root.quick) {
            const entry = root.tiles[root.tile]?.entry;
            if (entry)
                root.launch(() => Apps.launch(entry));
            return;
        }

        const row = root.results[root.selected];
        if (row?.ask)
            root.startCapture("ask", row);
        else if (row && !row.header)
            search.activate(row);
        else
            root.hide();
    }

    function move(delta: int): void {
        root.answerHolds = false;
        if (root.quick) {
            root.tile = (root.tile + delta + root.tiles.length) % root.tiles.length;
            return;
        }
        const at = Search.nextPickable(root.results, root.selected + delta, delta < 0 ? -1 : 1);
        if (at >= 0)
            root.moveTo(at);
    }

    function page(rows: int): void {
        if (!root.quick)
            root.moveTo(root.selected + rows);
    }

    function stepRow(direction: int): void {
        const from = root.tiles[root.tile];
        let best = -1;
        root.tiles.forEach((t, i) => {
            if (t.row === from.row + direction && (best < 0 || Math.abs(t.slot - from.slot) < Math.abs(root.tiles[best].slot - from.slot)))
                best = i;
        });
        if (best >= 0)
            root.tile = best;
    }

    function shiftTile(step: int): void {
        const t = root.tiles[root.tile];
        if (t?.pinned && Apps.moveStarred(t.entry, step))
            root.tile += step;
    }

    function claimTileKey(event: var): bool {
        const held = event.modifiers & Qt.ControlModifier;
        switch (event.key) {
        case Qt.Key_Left:
            if (held)
                root.shiftTile(-1);
            else
                root.move(-1);
            return true;
        case Qt.Key_Right:
            if (held)
                root.shiftTile(1);
            else
                root.move(1);
            return true;
        case Qt.Key_Up:
            root.stepRow(-1);
            return true;
        case Qt.Key_Down:
            root.stepRow(1);
            return true;
        case Qt.Key_Home:
            root.tile = 0;
            return true;
        case Qt.Key_End:
            root.tile = root.tiles.length - 1;
            return true;
        }
        return false;
    }

    function startCapture(kind: string, row: var): void {
        root.beforeCapture = root.capture ? root.beforeCapture : query.text;
        search.armed = "";
        root.capture = {
            kind: kind,
            row: Object.assign({}, row, {
                key: row.id ?? row.key,
                label: search.nameOf(row)
            }),
            said: ""
        };
        query.text = kind === "alias" ? search.aliasOf[row.id ?? row.key] ?? "" : kind === "ask" ? row.ask.suggestion ?? "" : "";
        query.selectAll();
        Qt.callLater(query.forceActiveFocus);
    }

    function endCapture(text: string): void {
        root.capture = null;
        query.text = text;
        query.cursorPosition = text.length;
    }

    function commitAlias(): void {
        const row = root.capture.row;
        const alias = Search.cleanAlias(query.text);
        Config.set("launcher.aliases", Search.withAlias(Config.values.launcher.aliases, row.key, alias, row.label));
        root.endCapture(alias || root.beforeCapture);
    }

    function commitAsk(): void {
        const typed = query.text.trim();
        if (!typed)
            return;
        const after = root.capture.row.ask.take(typed);
        root.endCapture(typeof after === "string" ? after : root.beforeCapture);
    }

    function takeHotkey(event: var): bool {
        const got = LauncherHotkeys.chordFrom(event);
        if (got.waiting)
            return true;
        const row = root.capture.row;
        const holder = got.chord ? LauncherHotkeys.holderOf(got.chord, row.key) : "";
        if (got.said || holder) {
            root.capture = Object.assign({}, root.capture, {
                said: got.said || `taken by ${holder}`
            });
            return true;
        }
        LauncherHotkeys.set(row.key, got.chord, row.label);
        root.endCapture(root.beforeCapture);
        return true;
    }

    function claimCaptureKey(event: var): bool {
        if (event.key === Qt.Key_Escape && !(event.modifiers & (Qt.MetaModifier | Qt.ControlModifier | Qt.AltModifier))) {
            root.endCapture(root.beforeCapture);
            return true;
        }
        if (root.capture.kind === "hotkey")
            return root.takeHotkey(event);
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (root.capture.kind === "ask")
                root.commitAsk();
            else
                root.commitAlias();
            return true;
        }
        return event.key === Qt.Key_Up || event.key === Qt.Key_Down || event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab;
    }

    function claimKey(event: var): bool {
        if (root.capture)
            return root.claimCaptureKey(event);

        if (sheet.open) {
            switch (event.key) {
            case Qt.Key_Down:
                sheet.move(1);
                break;
            case Qt.Key_Up:
                sheet.move(-1);
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
                sheet.activate(sheet.selected);
                break;
            default:
                sheet.close();
                break;
            }
            return true;
        }

        if (event.key === Qt.Key_Escape && search.armed) {
            search.armed = "";
            return true;
        }

        if (event.key === Qt.Key_Menu) {
            const item = root.quick ? tileRepeater.itemAt(root.tile) : list.itemAtIndex(root.selected);
            if (item)
                root.ask(item, root.quick ? root.tiles[root.tile].entry : root.results[root.selected], item.width / 2, item.height / 2);
            return true;
        }

        if (root.quick)
            return root.claimTileKey(event);

        const row = root.results[root.selected];
        if (event.key === Qt.Key_Tab && (search.complete(row) || search.complete(root.results.find(r => r.kind === "suggest"))))
            return true;
        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && (event.modifiers & Qt.ControlModifier) && row && !row.header && !root.answerHolds) {
            root.actionsFor(row).slice(1).find(a => !a.tucked)?.run();
            return true;
        }

        switch (event.key) {
        case Qt.Key_Home:
            root.moveTo(0);
            return true;
        case Qt.Key_End:
            root.moveTo(root.results.length - 1);
            return true;
        }
        return false;
    }

    function steer(id: string): void {
        const at = root.results.findIndex(r => r.id === id);
        if (at < 0)
            return;
        root.steered = true;
        root.selected = at;
    }

    function shortcutActions(row: var): var {
        if (!search.runnable(row))
            return [];
        const id = row.id ?? row.key;
        const alias = search.aliasOf[id] ?? "";
        const hotkey = LauncherHotkeys.chordOf(id);
        const acts = [
            {
                icon: "label",
                label: alias ? `Change alias · ${alias}` : "Add alias",
                tucked: true,
                run: () => root.startCapture("alias", row)
            }
        ];
        if (LauncherHotkeys.possible && search.keyable(row))
            acts.push({
                icon: "keyboard",
                label: hotkey ? `Change hotkey · ${Search.chordText(hotkey)}` : "Set hotkey",
                tucked: true,
                run: () => root.startCapture("hotkey", row)
            });
        if (alias)
            acts.push({
                icon: "label_off",
                label: "Remove alias",
                tucked: true,
                run: () => Config.set("launcher.aliases", Search.withAlias(Config.values.launcher.aliases, id, "", ""))
            });
        if (hotkey)
            acts.push({
                icon: "keyboard_hide",
                label: "Remove hotkey",
                tucked: true,
                run: () => LauncherHotkeys.clear(id)
            });
        return acts;
    }

    function actionsFor(what: var): var {
        if (what?.kind && what.kind !== "app")
            return search.actionsFor(what).concat(root.shortcutActions(what));
        const entry = what?.kind === "app" ? what.entry : what;
        const kept = Apps.isStarred(entry);
        const acts = [
            {
                icon: "rocket_launch",
                label: "Open",
                run: () => root.launch(() => Apps.launch(entry))
            }
        ];

        acts.push({
            icon: "push_pin",
            fill: kept,
            label: kept ? "Unpin" : "Pin",
            run: () => Apps.setStarred(entry, !kept)
        });

        acts.push(...search.appActions(entry));

        for (const action of entry.actions ?? [])
            acts.push({
                icon: "open_in_new",
                label: action.name,
                run: () => root.launch(() => Apps.launchAction(entry, action))
            });

        const at = root.quick ? root.pinnedApps.indexOf(entry) : -1;
        if (at > 0)
            acts.push({
                icon: "arrow_back",
                label: "Move left",
                run: () => root.shiftTile(-1)
            });
        if (at >= 0 && at < root.pinnedApps.length - 1)
            acts.push({
                icon: "arrow_forward",
                label: "Move right",
                run: () => root.shiftTile(1)
            });

        const row = what?.kind === "app" ? what : search.appRow(entry);
        acts.push(...root.shortcutActions(row));

        if (!root.quick)
            acts.push({
                icon: "delete",
                label: "Uninstall",
                tucked: true,
                run: () => {
                    search.armUninstall(entry);
                    root.steer(`app:${entry.id}`);
                }
            });

        return acts;
    }

    function ask(item: Item, entry: var, x: real, y: real): void {
        if (!entry || entry.header)
            return;
        root.answerHolds = false;
        const at = item.mapToItem(panel, x, y);
        sheet.popup(at.x, at.y, root.actionsFor(entry));
    }

    function chooseRow(index: int): void {
        if (root.capture)
            return;
        root.answerHolds = false;
        root.selected = index;
        root.accept();
    }

    function moveTo(index: int): void {
        root.answerHolds = false;
        const n = root.results.length;
        if (n <= 0)
            return;
        const at = Math.max(0, Math.min(index, n - 1));
        root.steered = true;
        root.selected = root.results[at].header ? Math.max(0, Search.nextPickable(root.results, at, 1)) : at;
        list.reveal(root.selected);
    }

    property bool settled: true

    Timer {
        id: settle

        interval: 160
        onTriggered: root.settled = true
    }

    Connections {
        target: root.input

        function onTextChanged(): void {
            root.settled = false;
            settle.restart();
        }
    }

    property string listedQuery: ""
    property string selectedKey: ""
    property bool steered: false

    onSelectedChanged: root.selectedKey = root.results[root.selected]?.id ?? ""

    onResultsChanged: {
        if (search.query !== root.listedQuery) {
            root.listedQuery = search.query;
            root.steered = false;
        }
        const kept = root.steered ? root.results.findIndex(r => r.id === root.selectedKey) : -1;
        if (kept >= 0) {
            root.selected = kept;
            return;
        }
        root.steered = false;
        root.selected = Math.max(0, Search.nextPickable(root.results, 0, 1));
        root.selectedKey = root.results[root.selected]?.id ?? "";
        list.reset();
    }

    Follow {
        id: grow

        target: panel.implicitHeight
        speed: Appearance.animation.resizeSpeed
        epsilon: 0.5
        longestFrame: root.longestFrame
    }

    Follow {
        id: gridIn

        target: root.quick ? 1 : 0
        speed: Appearance.animation.resizeSpeed
        epsilon: 0.002
        longestFrame: root.longestFrame
    }

    FrameAnimation {
        running: root.wave !== root.waveTarget

        onTriggered: {
            const step = Math.min(frameTime, root.longestFrame) * 1000 / Math.max(1, Appearance.animation.normal) * Math.max(1, root.tiles.length);
            root.wave = Appearance.lessMotion ? root.waveTarget : root.wave < root.waveTarget ? Math.min(root.waveTarget, root.wave + step) : Math.max(root.waveTarget, root.wave - step);
        }
    }

    property bool unsized: false

    Item {
        id: panel

        readonly property real barOffset: Appearance.padding.large + field.height / 2

        readonly property real restY: root.height / 2 - barOffset

        readonly property real bandY: root.height - root.inset
        readonly property bool bottomAnchored: restY + grow.value >= bandY - 1

        x: (root.width - width) / 2

        y: root.collapseToCentre ? restY + (grow.value - height) / 2 : bandY + (restY - bandY) * root.revealed

        width: root.panelWidth

        implicitHeight: Math.min(root.height - restY - root.inset, Appearance.padding.large * 2 + field.height + Appearance.padding.normal * 2 + separator.height + answerRow.height + (answerRow.visible ? Appearance.padding.normal : 0) + (symbols.visible ? symbols.height + Appearance.padding.normal : 0) + (root.quick ? quickLaunch.full : list.needed))

        height: grow.value * root.revealed

        visible: height > 0

        Item {
            anchors.fill: parent
            clip: true

            Column {
                id: layout

                x: Appearance.padding.large
                y: Appearance.padding.large
                width: root.panelWidth - Appearance.padding.large * 2
                spacing: Appearance.padding.normal

                Item {
                    id: field

                    width: parent.width
                    implicitHeight: Math.max(searchGlyph.implicitHeight, query.implicitHeight)
                    height: implicitHeight

                    Icon {
                        id: searchGlyph

                        anchors.left: parent.left
                        anchors.leftMargin: Appearance.padding.normal
                        anchors.verticalCenter: parent.verticalCenter
                        width: Appearance.sizes.launcherIcon
                        size: Appearance.font.size.normal
                        name: !root.capture ? "search" : root.capture.kind === "ask" ? root.capture.row.ask.icon : root.capture.kind === "alias" ? "label" : "keyboard"
                        color: Appearance.colour.textFaint
                    }

                    TextInput {
                        id: query

                        anchors.left: searchGlyph.right
                        anchors.leftMargin: Appearance.padding.normal
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter

                        font.family: Appearance.font.family
                        font.pixelSize: Appearance.font.size.normal
                        renderType: Text.NativeRendering
                        color: Appearance.colour.text
                        selectionColor: Appearance.colour.accent
                        selectedTextColor: Appearance.colour.accentText
                        clip: true

                        Keys.onPressed: event => root.pressKey(event)

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !query.text

                            text: !root.capture ? "Search" : root.capture.kind === "ask" ? root.capture.row.ask.prompt : root.capture.kind === "alias" ? `Alias for ${root.capture.row.label}` : `Press the keys for ${root.capture.row.label}`
                            font.pixelSize: Appearance.font.size.normal
                            color: Appearance.colour.textFaint
                        }
                    }
                }

                Separator {
                    id: separator

                    width: parent.width
                }

                AnswerRow {
                    id: answerRow

                    width: parent.width
                    iconSize: Appearance.sizes.launcherIcon
                    rowHeight: root.rowPitch
                    labelSize: Appearance.font.size.normal

                    result: root.answer
                    expression: query.text
                    holds: root.answerHolds

                    offersSymbols: true
                    symbolsOpen: root.symbolsOpen
                    onSymbols: root.symbolsOpen = !root.symbolsOpen

                    onCopied: {
                        root.answerHolds = true;
                        root.accept();
                    }
                }

                Flow {
                    id: symbols

                    width: parent.width
                    spacing: Appearance.padding.small
                    visible: root.symbolsOpen && !!root.input.text

                    Repeater {
                        model: root.symbolKeys

                        delegate: Button {
                            id: key

                            required property var modelData

                            text: key.modelData.label
                            style: "tonal"

                            onClicked: root.insert(key.modelData.insert)
                            onHoveredChanged: root.tip(key, key.modelData.tip ?? key.modelData.insert, key.height, key.hovered && !!key.modelData.tip)
                        }
                    }

                }

                Item {
                    id: body

                    width: parent.width
                    height: Math.max(0, panel.height - y - Appearance.padding.large)

                    Item {
                        id: quickLaunch

                        readonly property real icon: Math.round(Appearance.sizes.launcherIcon * 1.75)
                        readonly property real cell: quickLaunch.icon + Appearance.padding.large * 2
                        readonly property real gap: root.pinnedApps.length && root.recentApps.length ? Appearance.padding.normal * 2 + separator.height : 0
                        readonly property real full: (root.tiles.length ? root.tiles[root.tiles.length - 1].row + 1 : 0) * quickLaunch.cell + quickLaunch.gap

                        width: parent.width
                        height: quickLaunch.full
                        visible: gridIn.value > 0.002
                        enabled: root.quick
                        opacity: gridIn.value * gridIn.value

                        Separator {
                            visible: quickLaunch.gap > 0
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: root.pinnedRows * quickLaunch.cell + (quickLaunch.gap - height) / 2
                            width: root.tileColumns * quickLaunch.cell - Appearance.padding.large * 2
                        }

                        Repeater {
                            id: tileRepeater

                            model: root.tiles

                            delegate: Item {
                                id: cell

                                required property var modelData
                                required property int index

                                readonly property bool chosen: cell.index === root.tile

                                x: quickLaunch.width / 2 + (cell.modelData.slot - 0.5) * quickLaunch.cell
                                y: cell.modelData.row * quickLaunch.cell + (cell.modelData.pinned ? 0 : quickLaunch.gap)
                                width: quickLaunch.cell
                                height: quickLaunch.cell

                                opacity: pop.value
                                scale: 0.6 + 0.4 * pop.value

                                Follow {
                                    id: pop

                                    target: root.wave > cell.index ? 1 : 0
                                    speed: Appearance.animation.revealSpeed
                                    epsilon: 0.002
                                    longestFrame: root.longestFrame
                                }

                                SquircleRect {
                                    anchors.centerIn: parent
                                    width: quickLaunch.icon + Appearance.padding.card * 2
                                    height: width
                                    radius: Appearance.rounding.normal
                                    color: Appearance.colour.fill
                                    opacity: cell.chosen || pointer.containsMouse ? 1 : 0

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: Appearance.animation.fade.fast
                                        }
                                    }
                                }

                                Image {
                                    id: art

                                    anchors.centerIn: parent
                                    width: quickLaunch.icon
                                    height: quickLaunch.icon
                                    sourceSize.width: width * Screen.devicePixelRatio
                                    sourceSize.height: height * Screen.devicePixelRatio
                                    source: cell.modelData.entry.icon ? Quickshell.iconPath(cell.modelData.entry.icon, true) : ""
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    smooth: true
                                    visible: status === Image.Ready
                                }

                                Icon {
                                    anchors.centerIn: parent
                                    visible: art.status !== Image.Ready
                                    size: quickLaunch.icon * 0.6
                                    name: "apps"
                                    color: cell.chosen ? Appearance.colour.text : Appearance.colour.textDim
                                }

                                MouseArea {
                                    id: pointer

                                    anchors.fill: parent
                                    enabled: !root.asking
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                                    onContainsMouseChanged: root.tip(cell, cell.modelData.entry.name ?? "", (cell.height + quickLaunch.icon) / 2 + Appearance.padding.card, pointer.containsMouse)

                                    onClicked: mouse => {
                                        root.tile = cell.index;
                                        if (mouse.button === Qt.RightButton)
                                            root.ask(cell, cell.modelData.entry, mouse.x, mouse.y);
                                        else
                                            root.accept();
                                    }
                                }
                            }
                        }
                    }

                    GlideList {
                        id: list

                        readonly property real needed: Math.max(root.rowPitch, root.results.reduce((sum, r) => sum + (r.header ? root.headerPitch : root.rowPitch), 0))

                        y: (quickLaunch.full + Appearance.padding.large) * gridIn.value
                        width: parent.width
                        height: gridIn.value > 0 ? root.height : Math.max(0, body.height - y)
                        enabled: !root.quick
                        opacity: 1 - gridIn.value
                        clip: true

                        model: ScriptModel {
                            values: root.results
                            objectProp: "key"
                        }

                        cacheBuffer: root.rowPitch * 4

                        delegate: Item {
                            id: line

                            required property var modelData
                            required property int index

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
                                id: row

                                visible: !line.modelData.header
                                width: parent.width
                                height: line.height
                                iconSize: Appearance.sizes.launcherIcon
                                rowHeight: root.rowPitch

                                labelSize: Appearance.font.size.normal
                                inlineDetail: true

                                iconSource: line.modelData.iconSource ?? ""
                                glyph: line.modelData.glyph ?? ""
                                icon: line.modelData.icon ?? "apps"
                                label: line.modelData.label ?? ""
                                detail: line.modelData.detail ?? ""

                                selected: line.index === root.selected && !root.answerHolds

                                askable: true
                                onActivated: root.chooseRow(line.index)
                                onAsked: (x, y) => {
                                    root.steered = true;
                                    root.selected = line.index;
                                    root.ask(row, line.modelData, x, y);
                                }

                                Row {
                                    spacing: Appearance.padding.small

                                    Repeater {
                                        model: line.modelData.armed ? [] : [line.modelData.alias, Search.chordText(line.modelData.hotkey ?? "")].filter(Boolean)

                                        delegate: Item {
                                            id: tag

                                            required property string modelData

                                            anchors.verticalCenter: parent?.verticalCenter
                                            width: tagText.implicitWidth + Appearance.padding.normal * 2
                                            height: tagText.implicitHeight + Appearance.padding.small

                                            SquircleRect {
                                                anchors.fill: parent
                                                radius: Appearance.rounding.small
                                                color: Appearance.colour.fill
                                            }

                                            StyledText {
                                                id: tagText

                                                anchors.centerIn: parent
                                                text: tag.modelData
                                                font.pixelSize: Appearance.font.size.small
                                                color: Appearance.colour.textDim
                                            }
                                        }
                                    }

                                    Repeater {
                                        model: line.shownButtons

                                        delegate: Button {
                                            id: button

                                            required property var modelData
                                            required property int index

                                            icon: button.modelData.icon
                                            iconFill: button.modelData.fill ? 1 : 0
                                            text: button.modelData.short ?? button.modelData.label
                                            style: "outlined"
                                            alarm: button.modelData.alarm ?? false
                                            size: 0

                                            onClicked: (line.buttons[button.index] ?? button.modelData).run()
                                        }
                                    }

                                    Toggle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: line.modelData.toggle !== undefined
                                        checked: !!line.modelData.toggle
                                        onToggled: search.activate(line.modelData)
                                    }
                                }
                            }

                            HoverHandler {
                                id: lineHover
                            }

                            readonly property bool opened: !line.modelData.header && !root.asking && !root.capture && (line.index === root.selected && !root.answerHolds && root.settled || lineHover.hovered)

                            property var shownButtons: []
                            property string shownSignature: ""

                            function showButtons(): void {
                                const signature = line.buttons.map(b => `${b.icon}|${b.short ?? b.label}|${b.fill ? 1 : 0}|${b.alarm ? 1 : 0}`).join(",");
                                if (signature === line.shownSignature)
                                    return;
                                line.shownSignature = signature;
                                line.shownButtons = line.buttons;
                            }

                            onButtonsChanged: line.showButtons()
                            Component.onCompleted: line.showButtons()

                            readonly property var buttons: {
                                if (!line.opened)
                                    return [];
                                if (line.modelData.armed)
                                    return search.confirmActions(line.modelData);
                                const acts = root.actionsFor(line.modelData).slice(1);
                                const shown = acts.filter(a => !a.tucked);
                                return shown.length === acts.length && shown.length <= root.buttonLimit ? shown : [...shown.slice(0, root.buttonLimit - 1), {
                                        icon: "more_horiz",
                                        label: "More",
                                        run: () => root.ask(row, line.modelData, row.width - Appearance.padding.large, row.height / 2)
                                    }];
                            }
                        }

                        StyledText {
                            id: empty

                            visible: !root.results.length && !root.answer
                            text: query.text ? "nothing matches" : "no applications found"
                            color: Appearance.colour.textFaint
                            font.pixelSize: Appearance.font.size.small
                        }
                    }
                }
            }
        }

        FloatingTooltip {
            id: hint

            shown: !!root.tipHost && !root.asking
        }

        ShortcutInhibitor {
            window: root.QsWindow.window
            enabled: root.open && root.capture?.kind === "hotkey"
        }

        ActionSheet {
            id: sheet

            anchors.fill: parent

            Connections {
                target: list

                function onContentYChanged(): void {
                    sheet.close();
                }
            }

            onClosed: if (root.open)
                Qt.callLater(query.forceActiveFocus)
        }
    }
}
