pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

Item {
    id: root

    required property real originX
    required property real inset

    readonly property bool open: shown
    property bool shown: false

    readonly property real panelWidth: Config.values.launcher.niagara.width
    readonly property real railWidth: Config.values.launcher.niagara.rail
    readonly property int favouriteCount: Config.values.launcher.niagara.favourites
    readonly property real iconSize: Config.values.launcher.niagara.icon
    readonly property real bowDepth: Config.values.launcher.niagara.bow
    readonly property real bowSpread: Config.values.launcher.niagara.bowSpread
    readonly property real badgeSize: Config.values.launcher.niagara.badge

    readonly property real gutter: Appearance.font.size.large + Appearance.padding.normal

    readonly property real rowPitch: root.iconSize + Appearance.padding.normal
    readonly property real sectionPitch: Appearance.font.size.large + Appearance.padding.large

    readonly property string star: "favourites"
    readonly property string starIcon: "star"

    readonly property string vault: "hidden"
    readonly property string vaultIcon: "visibility_off"

    function keyIcon(key: string): string {
        if (key === root.star)
            return root.starIcon;
        if (key === root.vault)
            return root.vaultIcon;

        if (key && key === root.opened)
            return "arrow_back";
        return "";
    }

    readonly property Item maskItem: catcher

    readonly property var blobs: panel.height <= 0 ? [] : [
        {
            x: panel.x,
            y: panel.y,
            w: panel.width,
            h: panel.height,
            radius: Appearance.rounding.large,
            smooth: Math.min(Appearance.sizes.melt, Math.min(panel.width, panel.height) / 2)
        }
    ]

    readonly property var byLetter: {
        const out = {};
        for (const entry of Apps.visible) {
            const name = (entry.name ?? "").trim();
            if (!name)
                continue;
            const first = name[0].toUpperCase();
            const key = first >= "A" && first <= "Z" ? first : "#";
            if (!out[key])
                out[key] = [];
            out[key].push(entry);
        }
        for (const key in out)
            out[key] = Apps.byUse(out[key]);
        return out;
    }

    readonly property var letters: Object.keys(root.byLetter).sort()

    readonly property var favourites: Apps.pinned(root.favouriteCount)

    readonly property var keys: root.opened ? [] : [root.star, ...root.letters, ...(Apps.buried.length ? [root.vault] : [])]

    readonly property int moveDelay: Config.values.launcher.niagara.moveDelay

    property var rowKeys: ({})

    function rowFor(key: string, section: string, entry: var, folder: string): var {
        const had = root.rowKeys[key];
        if (had && had.entry === entry && had.section === section && had.folder === folder)
            return had;
        return root.rowKeys[key] = {
            section: section,
            entry: entry,
            folder: folder
        };
    }

    function entryKey(entry: var): string {
        return entry?.id || entry?.name || "";
    }

    function pickable(row: var): bool {
        return !!row && (!!row.entry || !!row.folder);
    }

    readonly property var rows: {

        if (query.text && !root.naming)
            return Apps.search(query.text).map(entry => root.rowFor(`app:${root.entryKey(entry)}`, "", entry, ""));

        if (root.opened) {
            const out = [root.rowFor(`open:${root.opened}`, root.opened, null, "")];
            for (const entry of root.openedApps)
                out.push(root.rowFor(`in:${root.opened}:${root.entryKey(entry)}`, "", entry, ""));
            return out;
        }

        const out = [];
        if (root.favourites.length || Apps.folderKeys.length) {
            out.push(root.rowFor(`section:${root.star}`, root.star, null, ""));
            for (const key of Apps.folderKeys)
                out.push(root.rowFor(`folder:${key}`, "", null, key));
            for (const entry of root.favourites)
                out.push(root.rowFor(`fav:${root.entryKey(entry)}`, "", entry, ""));
        }
        for (const key of root.letters) {
            out.push(root.rowFor(`section:${key}`, key, null, ""));
            for (const entry of root.byLetter[key])
                out.push(root.rowFor(`app:${root.entryKey(entry)}`, "", entry, ""));
        }
        if (Apps.buried.length) {
            out.push(root.rowFor(`section:${root.vault}`, root.vault, null, ""));
            for (const entry of Apps.buried)
                out.push(root.rowFor(`app:${root.entryKey(entry)}`, "", entry, ""));
        }
        return out;
    }

    property string opened: ""

    readonly property var openedFolder: root.opened ? Apps.folders[root.opened] : null

    readonly property var openedApps: root.opened ? Apps.folderApps(root.opened) : []

    function enterFolder(key: string): void {
        if (!key || !Apps.folders[key])
            return;
        sheet.close();
        root.opened = key;
        query.text = "";
        root.marked = "";
        list.reset();
        root.selected = root.firstApp(0, 1);
    }

    function leaveFolder(): void {
        if (!root.opened)
            return;
        sheet.close();
        root.opened = "";
        list.reset();
        root.markSection(root.star);
    }

    onOpenedFolderChanged: if (root.opened && !root.openedFolder)
        root.leaveFolder()

    readonly property var sectionSpan: {
        const out = {};
        let y = 0;
        let key = "";
        for (const row of root.rows) {
            if (row.section) {
                key = row.section;
                out[key] = {
                    y: y,
                    h: root.sectionPitch
                };
                y += root.sectionPitch;
            } else {
                if (key)
                    out[key].h += root.rowPitch;
                y += root.rowPitch;
            }
        }
        return out;
    }

    readonly property real needed: root.rowY(root.rows.length)

    readonly property real tail: {
        if (root.needed <= list.height)
            return 0;
        for (let i = root.rows.length - 1; i >= 0; i--) {
            const key = root.rows[i].section;
            if (!key)
                continue;

            const span = root.sectionSpan[key];
            return span ? Math.max(0, (list.height - span.h) / 2) : 0;
        }
        return 0;
    }

    property string marked: ""
    property real scrubY: 0
    property real depth: 0
    property bool grabbing: false

    property int hovered: -1

    property real hoverY: 0

    function hoverRow(index: int, y: real): void {
        const nothingToLeave = plateShape.opacity <= 0.001;
        root.hovered = index;
        root.hoverY = y;
        if (nothingToLeave)
            plate.snap();
    }

    property bool dragging: false
    property real dragProgress: 0

    function dragTo(fraction: real): void {
        root.dragging = true;
        root.dragProgress = Math.max(0, Math.min(fraction, 1));
    }

    function dragEnd(open: bool): void {
        root.dragging = false;

        rise.value = root.dragProgress;

        if (open) {
            if (!root.shown)
                root.show();
        } else {
            root.hide();
        }

        root.dragProgress = 0;
    }

    property bool scrubbing: false

    function scrubTo(fraction: real): void {
        root.scrubbing = fraction >= 0;
        if (!root.scrubbing)
            return;
        root.scrubY = Math.max(0, Math.min(fraction, 1)) * rail.height;
        root.depth = root.bowDepth * 0.55;
        root.scrubAt(root.scrubY);
    }

    function grabAt(x: real, y: real): void {
        root.scrubY = Math.max(0, Math.min(y, rail.height));
        root.depth = Math.max(0, Math.min(rail.width / 2 - x, root.bowDepth));
        root.scrubAt(root.scrubY);
    }

    property int selected: 0

    readonly property real drawnHeight: panel.height
    readonly property int resultCount: root.rows.filter(r => !!r.entry).length

    readonly property string scrollInfo: `${query.text ? `search "${query.text}"` : root.marked || "top"}, row ${root.selected} of ${root.rows.length}, at ${Math.round(list.contentY)}/${Math.round(list.maxScroll)}, view ${Math.round(list.height)}px, tail ${Math.round(root.tail)}px, section at ${Math.round(root.sectionSpan[root.marked]?.y ?? -1)}+${Math.round(root.sectionSpan[root.marked]?.h ?? 0)}`

    property string restoreTo: ""

    readonly property string screenName: QsWindow.window?.screen?.name ?? ""

    function show(): void {

        if (!root.shown)
            root.restoreTo = Hypr.focusedOn(root.screenName);
        root.shown = true;
        query.text = "";
        root.marked = "";
        root.hovered = -1;
        root.scrubbing = false;
        root.grabbing = false;

        root.opened = "";
        root.naming = "";
        root.selected = root.firstApp(0, 1);
        list.reset();
        Qt.callLater(query.forceActiveFocus);

        Qt.callLater(grow.snap);
    }

    function hide(): void {
        root.shown = false;
        query.focus = false;
        root.scrubbing = false;
        root.grabbing = false;
        root.naming = "";
        sheet.close();
        Hypr.restoreFocus(root.restoreTo);
        root.restoreTo = "";
    }

    function toggle(): void {
        if (root.shown)
            root.hide();
        else
            root.show();
    }

    readonly property var answer: Calc.answer(query.text)
    property bool answerHolds: false

    onAnswerChanged: root.answerHolds = !!root.answer

    function accept(): void {
        if (root.answerHolds && root.answer) {
            Clipboard.copy({
                text: root.answer.text
            });
            root.hide();
            return;
        }

        if (root.naming) {
            root.commitName();
            return;
        }

        const row = root.rows[root.selected];

        if (row?.folder) {
            root.enterFolder(row.folder);
            return;
        }

        const entry = row?.entry;
        if (entry) {
            Apps.launch(entry);
            root.restoreTo = "";
            Hypr.claimNextWindow();
        }
        root.hide();
    }

    property string naming: ""
    property var namingFor: null

    function askName(key: string, entry: var, prefill: string): void {
        sheet.close();
        root.naming = key;
        root.namingFor = entry;
        query.text = prefill;
        query.selectAll();
        Qt.callLater(query.forceActiveFocus);
    }

    function commitName(): void {
        const text = query.text.trim();
        const key = root.naming;
        const entry = root.namingFor;

        root.naming = "";
        root.namingFor = null;
        query.text = "";

        if (!text)
            return;

        if (key === "new")
            Apps.fileInFolder(Apps.createFolder(text), entry);
        else
            Apps.renameFolder(key, text);
    }

    function cancelName(): void {
        root.naming = "";
        root.namingFor = null;
        query.text = "";
    }

    function back(): void {
        if (root.naming)
            root.cancelName();
        else if (root.opened)
            root.leaveFolder();
        else
            root.hide();
    }

    function launch(what: var): void {
        what();
        root.restoreTo = "";
        Hypr.claimNextWindow();
        root.hide();
    }

    function actionsFor(entry: var): var {
        if (!entry)
            return [];

        const away = Apps.isHidden(entry);
        const kept = Apps.isStarred(entry);
        const acts = [
            {

                icon: "rocket_launch",
                label: "Open",
                run: () => root.launch(() => Apps.launch(entry))
            }
        ];

        for (const action of entry.actions ?? [])
            acts.push({
                icon: "open_in_new",
                label: action.name,
                run: () => root.launch(() => Apps.launchAction(entry, action))
            });

        acts.push({
            icon: root.starIcon,
            label: kept ? "Take off favourites" : "Add to favourites",
            run: () => Apps.setStarred(entry, !kept)
        });

        const home = Apps.folderOf(entry.id ?? "");

        if (home)
            acts.push({
                icon: "folder_off",
                label: `Take out of ${Apps.folders[home]?.name ?? "the folder"}`,
                run: () => Apps.takeOutOfFolder(entry)
            });

        for (const key of Apps.folderKeys) {
            if (key === home)
                continue;
            acts.push({
                icon: "folder",
                label: `Move to ${Apps.folders[key].name}`,
                run: () => Apps.fileInFolder(key, entry)
            });
        }

        acts.push({
            icon: "create_new_folder",
            label: "New folder with it",
            run: () => root.askName("new", entry, "")
        });

        acts.push({
            icon: away ? "visibility" : root.vaultIcon,
            label: away ? "Put back in the list" : "Hide from the list",
            run: () => Apps.setHidden(entry, !away)
        });

        return acts;
    }

    function folderActionsFor(key: string): var {
        const folder = Apps.folders[key];
        if (!folder)
            return [];

        return [
            {
                icon: "folder_open",
                label: "Open it",
                run: () => root.enterFolder(key)
            },
            {
                icon: "edit",
                label: "Rename it",
                run: () => root.askName(key, null, folder.name ?? "")
            },
            {
                icon: "folder_delete",
                label: "Break it up",
                run: () => Apps.dissolveFolder(key)
            }
        ];
    }

    function askRow(row: Item, x: real, y: real): void {
        if (!row.entry && !row.folder)
            return;

        root.answerHolds = false;
        root.selected = row.index;
        const at = row.mapToItem(panel, x, y);
        sheet.popup(at.x, at.y, row.folder ? root.folderActionsFor(row.folder) : root.actionsFor(row.entry));
    }

    function firstApp(from: int, step: int): int {
        const n = root.rows.length;
        for (let i = 0; i < n; i++) {
            const at = ((from + i * step) % n + n) % n;
            if (root.pickable(root.rows[at]))
                return at;
        }
        return 0;
    }

    function move(delta: int): void {

        root.answerHolds = false;
        if (root.rows.length)
            root.selectRow(root.firstApp(root.selected + delta, delta >= 0 ? 1 : -1));
    }

    function rowY(index: int): real {
        let y = 0;
        for (let i = 0; i < index && i < root.rows.length; i++)
            y += root.rows[i].section ? root.sectionPitch : root.rowPitch;
        return y;
    }

    function selectRow(index: int): void {
        root.selected = index;

        const top = root.rowY(index);
        const height = root.rows[index]?.section ? root.sectionPitch : root.rowPitch;

        const lead = index > 0 && root.rows[index - 1]?.section ? root.sectionPitch : 0;

        if (top - lead < list.anchor)
            list.scrollTo(top - lead);
        else if (top + height > list.anchor + list.height)
            list.scrollTo(top + height - list.height);
    }

    function markSection(key: string): void {
        root.marked = key;

        const span = root.sectionSpan[key];
        if (!span)
            return;
        list.scrollTo(span.y - Math.max(0, (list.height - span.h) / 2));

        const at = root.rows.findIndex(row => row.section === key);
        if (at >= 0 && root.pickable(root.rows[at + 1]))
            root.selected = at + 1;
    }

    function scrubAt(y: real): void {
        const n = root.keys.length;
        if (n <= 0 || query.text || root.opened)
            return;
        const index = Math.max(0, Math.min(Math.floor(y / rail.height * n), n - 1));
        const key = root.keys[index];
        if (key === root.marked)
            return;
        root.markSection(key);
    }

    function reselect(): void {

        root.hovered = -1;

        if (root.marked && root.sectionSpan[root.marked]) {
            root.markSection(root.marked);
            return;
        }

        root.marked = "";
        root.selectRow(root.firstApp(0, 1));
    }

    onRowsChanged: root.reselect()

    Follow {
        id: rise

        target: root.shown ? 1 : 0
        speed: Appearance.anim.revealSpeed
        epsilon: 0.005
    }

    Follow {
        id: grow

        target: root.needed
        speed: Appearance.anim.resizeSpeed
        epsilon: 0.5
    }

    Follow {
        id: plate

        target: root.hoverY
        speed: Appearance.anim.trackSpeed
    }

    Follow {
        id: bow

        target: root.grabbing || root.scrubbing ? 1 : 0
        speed: Appearance.anim.revealSpeed
        epsilon: 0.005
    }

    MouseArea {
        id: catcher

        anchors.fill: parent
        enabled: root.open
        visible: root.open
        onClicked: root.hide()
    }

    Pull {
        id: putAway

        x: panel.x
        y: panel.y
        width: panel.width
        height: panel.height

        armed: root.open

        dirX: 0
        dirY: 1

        angle: Appearance.sizes.pullAngleEdge

        travel: panel.fullHeight

        onPulled: fraction => root.dragTo(1 - fraction)

        onFinished: gone => root.dragEnd(!gone)
    }

    Item {
        id: panel

        readonly property real bandY: root.height - root.inset
        readonly property real fullHeight: root.height - root.inset * 2

        x: (root.width - width) / 2
        width: root.panelWidth

        height: fullHeight * (root.dragging ? root.dragProgress : rise.value)
        y: bandY - height

        visible: height > 0

        Item {
            anchors.fill: parent
            clip: true

            MouseArea {
                id: rail

                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.rightMargin: Appearance.padding.normal
                anchors.topMargin: Appearance.padding.large
                anchors.bottomMargin: Appearance.padding.large

                width: root.opened ? 0 : root.railWidth
                enabled: !root.opened

                hoverEnabled: true
                preventStealing: true
                cursorShape: Qt.SizeVerCursor

                Behavior on width {
                    NumberAnimation {
                        duration: Appearance.anim.normal
                        easing.type: Easing.OutCubic
                    }
                }

                onPressed: mouse => {

                    root.scrubbing = false;
                    root.grabbing = true;
                    root.grabAt(mouse.x, mouse.y);
                }

                onPositionChanged: mouse => {
                    if (root.grabbing)
                        root.grabAt(mouse.x, mouse.y);
                }

                onReleased: root.grabbing = false
                onCanceled: root.grabbing = false

                onWheel: wheel => wheel.accepted = true

                Repeater {
                    model: root.keys

                    delegate: Item {
                        id: mark

                        required property string modelData
                        required property int index

                        readonly property string glyph: root.keyIcon(modelData)
                        readonly property bool active: modelData === root.marked
                        readonly property color tint: active ? Appearance.colour.accent : rail.containsMouse ? Appearance.colour.textDim : Appearance.colour.textFaint

                        readonly property real slot: rail.height / root.keys.length

                        readonly property real fromCursor: (index + 0.5) * slot - root.scrubY

                        x: -root.depth * bow.value * Math.exp(-Math.pow(fromCursor / (slot * root.bowSpread), 2))
                        y: index * slot
                        width: rail.width
                        height: slot

                        StyledText {
                            id: letter

                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: letter.inkOffsetX
                            anchors.verticalCenterOffset: letter.inkOffsetY
                            visible: !mark.glyph
                            text: mark.modelData
                            font.pixelSize: Appearance.font.size.small
                            color: mark.tint
                        }

                        Icon {
                            id: markGlyph

                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: markGlyph.inkOffsetX
                            anchors.verticalCenterOffset: markGlyph.inkOffsetY
                            visible: !!mark.glyph
                            size: Appearance.font.size.small
                            name: mark.glyph
                            color: mark.tint
                        }
                    }
                }
            }

            G2Rect {
                id: disc

                readonly property string glyph: root.keyIcon(root.marked)

                x: rail.x + rail.width / 2 - (root.depth + width / 2 + Appearance.padding.normal) * bow.value - width / 2
                y: rail.y + root.scrubY - height / 2
                width: root.badgeSize
                height: width
                radius: width / 2

                visible: bow.value > 0.01 && !!root.marked
                opacity: bow.value
                color: Appearance.colour.accent

                StyledText {
                    id: discLetter

                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: discLetter.inkOffsetX
                    anchors.verticalCenterOffset: discLetter.inkOffsetY
                    visible: !disc.glyph
                    text: root.marked
                    font.pixelSize: Appearance.font.size.large
                    color: Appearance.colour.accentText
                }

                Icon {
                    id: discGlyph

                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: discGlyph.inkOffsetX
                    anchors.verticalCenterOffset: discGlyph.inkOffsetY
                    visible: !!disc.glyph
                    size: Appearance.font.size.large
                    name: disc.glyph
                    color: Appearance.colour.accentText
                }
            }

            Item {
                id: field

                anchors.left: parent.left
                anchors.right: rail.left
                anchors.bottom: parent.bottom
                anchors.leftMargin: Appearance.padding.large
                anchors.rightMargin: Appearance.padding.normal
                anchors.bottomMargin: Appearance.padding.large
                height: Appearance.font.size.normal + Appearance.padding.normal

                Icon {
                    id: searchGlyph

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.gutter
                    size: Appearance.font.size.normal
                    name: "search"
                    color: query.text ? Appearance.colour.accent : Appearance.colour.textGhost
                }

                StyledText {
                    anchors.left: searchGlyph.right
                    anchors.leftMargin: Appearance.padding.normal
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !query.text
                    text: root.naming ? (root.naming === "new" ? "Name the folder" : "What is it called?") : "Search, or run the rail"
                    font.pixelSize: Appearance.font.size.normal
                    color: Appearance.colour.textGhost
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

                    onTextChanged: {
                        if (root.naming)
                            return;
                        if (text) {
                            root.marked = "";
                            root.opened = "";
                        }
                        list.reset();
                    }

                    Keys.onPressed: event => {
                        const page = Math.max(1, Math.floor(list.height / root.rowPitch) - 1);

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
                            event.accepted = true;
                            return;
                        }

                        switch (event.key) {
                        case Qt.Key_Escape:
                            root.back();
                            break;

                        case Qt.Key_Right:
                            if (query.text || root.naming)
                                return;
                            root.enterFolder(root.rows[root.selected]?.folder ?? "");
                            break;
                        case Qt.Key_Left:
                            if (query.text || root.naming)
                                return;
                            root.leaveFolder();
                            break;
                        case Qt.Key_Return:
                        case Qt.Key_Enter:
                            root.accept();
                            break;
                        case Qt.Key_Down:
                        case Qt.Key_Tab:
                            root.move(1);
                            break;
                        case Qt.Key_Up:
                        case Qt.Key_Backtab:
                            root.move(-1);
                            break;
                        case Qt.Key_PageDown:
                            root.move(page);
                            break;
                        case Qt.Key_PageUp:
                            root.move(-page);
                            break;
                        default:
                            return;
                        }
                        event.accepted = true;
                    }
                }
            }

            AnswerRow {
                id: answerRow

                anchors.left: parent.left
                anchors.right: rail.left
                anchors.bottom: field.top
                anchors.leftMargin: Appearance.padding.large
                anchors.rightMargin: Appearance.padding.normal

                iconSize: root.gutter
                rowHeight: root.rowPitch
                labelSize: Appearance.font.size.normal

                result: root.answer
                expression: query.text
                holds: root.answerHolds

                onCopied: {
                    root.answerHolds = true;
                    root.accept();
                }
            }

            Item {
                id: well

                anchors.left: parent.left
                anchors.right: rail.left
                anchors.top: parent.top
                anchors.bottom: answerRow.visible ? answerRow.top : field.top
                anchors.leftMargin: Appearance.padding.large
                anchors.rightMargin: Appearance.padding.normal
                anchors.topMargin: Appearance.padding.large
                anchors.bottomMargin: Appearance.padding.large

                StyledText {
                    anchors.centerIn: parent

                    visible: !root.rows.length && !root.answer
                    text: query.text ? "nothing matches" : "no applications found"
                    font.pixelSize: Appearance.font.size.normal
                    color: Appearance.colour.textGhost
                }

                Item {
                    anchors.fill: list
                    clip: true

                    G2Rect {
                        id: plateShape

                        x: root.gutter - Appearance.padding.small
                        y: plate.value - list.contentY
                        width: parent.width - x
                        height: root.rowPitch

                        radius: height / 2
                        color: Appearance.colour.fill

                        opacity: root.hovered >= 0 ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Appearance.anim.fast
                            }
                        }
                    }
                }

                GlideList {
                    id: list

                    width: well.width
                    anchors.verticalCenter: well.verticalCenter

                    height: Math.max(0, Math.min(well.height, grow.value))

                    clip: true
                    model: ScriptModel {
                        values: root.rows
                    }

                    reuseItems: false

                    cacheBuffer: root.rowPitch * 8

                    add: Transition {
                        NumberAnimation {
                            property: "opacity"
                            from: 0
                            to: 1
                            duration: Appearance.anim.fast
                        }
                    }

                    remove: Transition {
                        NumberAnimation {
                            property: "opacity"
                            to: 0
                            duration: Appearance.anim.fast
                            easing.type: Easing.OutCubic
                        }
                    }

                    displaced: Transition {
                        SequentialAnimation {
                            PauseAnimation {
                                duration: root.moveDelay
                            }

                            NumberAnimation {
                                property: "y"
                                duration: Appearance.anim.normal
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    footer: Item {
                        width: list.width
                        height: root.tail
                    }

                    delegate: Item {
                        id: row

                        required property var modelData
                        required property int index

                        readonly property bool isSection: !!modelData.section
                        readonly property var entry: modelData.entry
                        readonly property string glyph: root.keyIcon(modelData.section)
                        readonly property string folder: modelData.folder
                        readonly property var folderData: row.folder ? Apps.folders[row.folder] : null
                        readonly property var inside: row.folder ? Apps.folderApps(row.folder) : []

                        readonly property bool actionable: !!row.entry || !!row.folder

                        readonly property bool isBack: row.isSection && modelData.section === root.opened

                        readonly property bool chosen: index === root.selected
                        readonly property bool under: index === root.hovered
                        readonly property bool away: !!entry && Apps.isHidden(entry)
                        readonly property color ring: Appearance.colour.accent

                        readonly property int unread: row.folder ? AppNotifs.countForAll(row.inside) : row.entry ? AppNotifs.countFor(row.entry) : 0
                        readonly property var newest: row.entry ? AppNotifs.newestFor(row.entry) : null

                        readonly property bool canOpen: !!row.folder
                        readonly property bool canClear: row.unread > 0

                        property real slide: 0
                        property bool swiping: false

                        readonly property real commitAt: Math.max(1, list.width * Appearance.sizes.dragDismissFraction)
                        readonly property bool past: Math.abs(row.slide) >= row.commitAt

                        function armed(dx: real): bool {
                            return dx > 0 ? row.canOpen || row.canClear : row.canClear;
                        }

                        function resist(dx: real): real {
                            if (!row.armed(dx))
                                return 0;
                            const far = Math.abs(dx);
                            const over = far - row.commitAt;
                            const travel = over <= 0 ? far : row.commitAt + over * Appearance.sizes.dragResistance;
                            return dx < 0 ? -travel : travel;
                        }

                        function settleSwipe(): void {
                            const acting = row.past;
                            const open = row.slide > 0 && row.canOpen;
                            const clear = row.canClear && !open;

                            row.swiping = false;
                            row.slide = 0;

                            if (!acting)
                                return;
                            if (open)
                                root.enterFolder(row.folder);
                            else if (clear)
                                row.clear();
                        }

                        function clear(): void {
                            if (row.folder)
                                AppNotifs.dismissForAll(row.inside);
                            else
                                AppNotifs.dismissFor(row.entry);
                        }

                        width: list.width
                        height: isSection ? root.sectionPitch : root.rowPitch

                        MouseArea {
                            id: pointer

                            anchors.fill: parent
                            enabled: row.actionable || row.isBack

                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton

                            property bool held: false

                            property real fromX: 0
                            property real fromY: 0
                            property bool deciding: false

                            onPressed: mouse => {
                                pointer.held = false;
                                pointer.fromX = mouse.x;
                                pointer.fromY = mouse.y;
                                pointer.deciding = true;
                                row.swiping = false;
                            }

                            preventStealing: row.swiping

                            onPositionChanged: mouse => {
                                if (!pointer.pressed)
                                    return;

                                if (pointer.deciding) {
                                    const dx = mouse.x - pointer.fromX;
                                    const dy = mouse.y - pointer.fromY;
                                    if (Math.abs(dx) < Appearance.sizes.dragThreshold)
                                        return;

                                    if (Math.abs(dx) <= Math.abs(dy))
                                        return;
                                    pointer.deciding = false;
                                    row.swiping = true;

                                    pointer.held = true;
                                }

                                row.slide = row.resist(mouse.x - pointer.fromX);
                            }

                            onReleased: row.settleSwipe()
                            onCanceled: row.settleSwipe()

                            onPressAndHold: mouse => {
                                if (row.swiping)
                                    return;
                                pointer.held = true;
                                root.askRow(row, mouse.x, mouse.y);
                            }

                            onClicked: mouse => {

                                if (pointer.held)
                                    return;

                                if (mouse.button === Qt.RightButton) {
                                    root.askRow(row, mouse.x, mouse.y);
                                    return;
                                }
                                if (row.isBack) {
                                    root.leaveFolder();
                                    return;
                                }

                                root.answerHolds = false;
                                root.selected = row.index;
                                root.accept();
                            }
                        }

                        HoverHandler {
                            id: hover

                            enabled: (row.actionable || row.isBack) && !sheet.open

                            onHoveredChanged: {
                                if (hover.hovered)
                                    root.hoverRow(row.index, row.y);
                                else if (root.hovered === row.index)
                                    root.hovered = -1;
                            }
                        }

                        onYChanged: if (row.under)
                            root.hoverY = row.y

                        Item {
                            id: marks

                            anchors.fill: parent

                            readonly property real reach: Math.min(1, Math.abs(sled.x) / row.commitAt)
                            readonly property bool ready: Math.abs(sled.x) >= row.commitAt

                            visible: marks.reach > 0.001

                            Icon {
                                id: leadMark

                                anchors.left: parent.left
                                anchors.leftMargin: root.gutter
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.verticalCenterOffset: leadMark.inkOffsetY

                                visible: sled.x > 0
                                size: root.iconSize / 2
                                name: row.canOpen ? "folder_open" : "clear_all"
                                opacity: marks.reach
                                color: marks.ready ? Appearance.colour.accent : Appearance.colour.textFaint

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Appearance.anim.fast
                                    }
                                }
                            }

                            Icon {
                                id: trailMark

                                anchors.right: parent.right
                                anchors.rightMargin: root.gutter
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.verticalCenterOffset: trailMark.inkOffsetY

                                visible: sled.x < 0
                                size: root.iconSize / 2
                                name: "clear_all"
                                opacity: marks.reach
                                color: marks.ready ? Appearance.colour.accent : Appearance.colour.textFaint

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Appearance.anim.fast
                                    }
                                }
                            }
                        }

                        Item {
                            id: sled

                            x: row.slide
                            width: row.width
                            height: row.height

                            Behavior on x {
                                enabled: !row.swiping

                                NumberAnimation {
                                    duration: Appearance.anim.fast
                                    easing.type: Easing.OutCubic
                                }
                            }

                            StyledText {
                                id: heading

                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.verticalCenterOffset: heading.inkOffsetY
                                width: root.gutter

                                visible: row.isSection && !row.glyph
                                text: row.modelData.section
                                font.pixelSize: Appearance.font.size.large
                                color: row.modelData.section === root.marked ? Appearance.colour.accent : Appearance.colour.textDim

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Appearance.anim.fast
                                    }
                                }
                            }

                            Icon {
                                id: headingGlyph

                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.verticalCenterOffset: headingGlyph.inkOffsetY
                                width: root.gutter

                                visible: row.isSection && !!row.glyph
                                size: Appearance.font.size.large
                                name: row.glyph
                                color: row.isBack && row.under ? Appearance.colour.text : row.modelData.section === root.marked ? Appearance.colour.accent : Appearance.colour.textDim

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Appearance.anim.fast
                                    }
                                }
                            }

                            StyledText {
                                id: headingLabel

                                anchors.left: parent.left
                                anchors.leftMargin: root.gutter
                                anchors.right: parent.right
                                anchors.rightMargin: Appearance.padding.large
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.verticalCenterOffset: headingLabel.inkOffsetY

                                visible: row.isBack
                                text: root.openedFolder?.name ?? ""
                                font.pixelSize: Appearance.font.size.large
                                color: row.under ? Appearance.colour.text : Appearance.colour.textDim
                                elide: Text.ElideRight

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Appearance.anim.fast
                                    }
                                }
                            }

                            G2Rect {
                                id: badge

                                anchors.left: parent.left
                                anchors.leftMargin: root.gutter
                                anchors.verticalCenter: parent.verticalCenter
                                width: root.iconSize
                                height: width

                                radius: width / 2

                                visible: !row.isSection

                                color: art.visible ? "transparent" : row.under ? Appearance.colour.fillStrong : Appearance.colour.fill

                                stroke: row.chosen ? row.ring : Qt.rgba(row.ring.r, row.ring.g, row.ring.b, 0)
                                strokeWidth: 2

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Appearance.anim.fast
                                    }
                                }

                                Behavior on stroke {
                                    ColorAnimation {
                                        duration: Appearance.anim.fast
                                    }
                                }

                                Image {
                                    id: art

                                    anchors.fill: parent
                                    anchors.margins: Appearance.padding.small
                                    source: row.entry?.icon ? Quickshell.iconPath(row.entry.icon, true) : ""
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    visible: status === Image.Ready
                                    sourceSize.width: width * Screen.devicePixelRatio
                                    sourceSize.height: height * Screen.devicePixelRatio
                                }

                                Item {
                                    id: stack

                                    anchors.fill: parent
                                    anchors.margins: Appearance.padding.small
                                    visible: !!row.folder

                                    readonly property var shown: row.inside.slice(0, 4)
                                    readonly property int cols: Math.max(1, Math.ceil(Math.sqrt(stack.shown.length)))
                                    readonly property int lines: Math.max(1, Math.ceil(stack.shown.length / stack.cols))
                                    readonly property real cell: stack.width / stack.cols
                                    readonly property real gridY: (stack.height - stack.cell * stack.lines) / 2

                                    Repeater {
                                        model: stack.shown

                                        delegate: Image {
                                            required property var modelData
                                            required property int index

                                            x: (index % stack.cols) * stack.cell
                                            y: stack.gridY + Math.floor(index / stack.cols) * stack.cell
                                            width: stack.cell
                                            height: stack.cell

                                            source: modelData.icon ? Quickshell.iconPath(modelData.icon, true) : ""
                                            fillMode: Image.PreserveAspectFit
                                            asynchronous: true
                                            sourceSize.width: width * Screen.devicePixelRatio
                                            sourceSize.height: height * Screen.devicePixelRatio
                                        }
                                    }
                                }

                                Icon {
                                    id: fallbackGlyph

                                    anchors.centerIn: parent
                                    anchors.horizontalCenterOffset: fallbackGlyph.inkOffsetX
                                    anchors.verticalCenterOffset: fallbackGlyph.inkOffsetY

                                    visible: row.folder ? stack.shown.length === 0 : !art.visible
                                    size: root.iconSize / 2
                                    name: row.folder ? "folder" : "apps"
                                    color: Appearance.colour.textDim
                                }

                                G2Rect {
                                    id: unread

                                    x: badge.width - width * 0.78
                                    y: -height * 0.22
                                    width: root.iconSize * 0.46
                                    height: width
                                    radius: width / 2

                                    visible: row.unread > 0
                                    color: Appearance.colour.accent

                                    StyledText {
                                        id: unreadCount

                                        anchors.centerIn: parent
                                        anchors.horizontalCenterOffset: unreadCount.inkOffsetX
                                        anchors.verticalCenterOffset: unreadCount.inkOffsetY

                                        text: row.unread > 9 ? "9+" : `${row.unread}`
                                        font.pixelSize: Appearance.font.size.small
                                        color: Appearance.colour.accentText
                                    }
                                }
                            }

                            StyledText {
                                anchors.left: badge.right
                                anchors.leftMargin: Appearance.padding.large

                                anchors.right: notice.left
                                anchors.rightMargin: Appearance.padding.normal
                                anchors.verticalCenter: parent.verticalCenter

                                visible: !row.isSection
                                text: row.folder ? (row.folderData?.name ?? "") : (row.entry?.name ?? "")
                                font.pixelSize: Appearance.font.size.normal
                                color: row.chosen || row.under ? Appearance.colour.text : Appearance.colour.textDim
                                elide: Text.ElideRight

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Appearance.anim.fast
                                    }
                                }
                            }

                            StyledText {
                                id: notice

                                anchors.right: parent.right
                                anchors.rightMargin: Appearance.padding.large
                                anchors.verticalCenter: parent.verticalCenter

                                width: notice.visible ? Math.min(noticeInk.width, list.width * 0.34) : 0
                                horizontalAlignment: Text.AlignRight

                                visible: !row.isSection && !row.folder && !!row.newest
                                text: row.newest?.summary ?? ""
                                font.pixelSize: Appearance.font.size.small
                                color: Appearance.colour.textFaint
                                elide: Text.ElideRight

                                TextMetrics {
                                    id: noticeInk

                                    font: notice.font
                                    text: notice.text
                                }
                            }
                        }
                    }
                }
            }
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
