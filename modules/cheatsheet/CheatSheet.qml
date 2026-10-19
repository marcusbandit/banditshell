pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.services

Item {
    id: root

    property bool open: false

    property bool board: false

    property real listY: 0
    property real boardY: 0

    property real holeX: 0
    property real holeY: 0
    property real holeWidth: 0
    property real holeHeight: 0

    readonly property Item maskItem: catcher

    property string restoreTo: ""

    readonly property string screenName: QsWindow.window?.screen?.name ?? ""

    property string keymap: ""
    property string kbLayout: ""
    property string kbOptions: ""

    readonly property var modBits: [
        {
            bit: 64,
            name: "SUPER",
            symbol: String.fromCodePoint(0xF31A)
        },
        {
            bit: 4,
            name: "CTRL",
            symbol: ""
        },
        {
            bit: 8,
            name: "ALT",
            symbol: ""
        },
        {
            bit: 1,
            name: "SHIFT",
            symbol: String.fromCodePoint(0xF0636)
        },
        {
            bit: 2,
            name: "CAPS",
            symbol: String.fromCodePoint(0xF0632)
        },
        {
            bit: 16,
            name: "MOD2",
            symbol: ""
        },
        {
            bit: 32,
            name: "MOD3",
            symbol: ""
        },
        {
            bit: 128,
            name: "MOD5",
            symbol: ""
        }
    ]

    readonly property int mouseBase: 272
    readonly property var mouseNames: ["LEFT", "RIGHT", "MIDDLE", "SIDE", "EXTRA", "FORWARD", "BACK", "TASK"]

    function modNames(mask: int): var {
        return root.modBits.filter(m => (mask & m.bit) !== 0).map(m => m.name);
    }

    function modSymbol(bit: int): string {
        for (const m of root.modBits)
            if (m.bit === bit)
                return m.symbol;
        return "";
    }

    function keyName(key: string): string {
        if (key.startsWith("mouse:")) {
            const named = root.mouseNames[parseInt(key.slice(6), 10) - root.mouseBase];
            return named ? `MOUSE ${named}` : key.toUpperCase();
        }
        const side = /^([A-Za-z]+)_([LR])$/.exec(key);
        if (side)
            return `${side[1]} ${side[2]}`.toUpperCase();
        const bare = key.startsWith("XF86") ? key.slice(4).replace(/([a-z0-9])([A-Z])/g, "$1 $2") : key;
        return bare.toUpperCase();
    }

    readonly property real advance: Math.ceil(em.advanceWidth)

    readonly property int symbolCells: Math.ceil(Appearance.font.size.small / root.advance)

    function chordParts(mask: int, key: string): var {
        const out = [];
        const join = () => {
            if (out.length > 0)
                out.push({
                    text: " + ",
                    glyph: "",
                    cells: 3
                });
        };

        for (const m of root.modBits) {
            if ((mask & m.bit) === 0)
                continue;
            join();
            out.push({
                text: m.symbol ? "" : m.name,
                glyph: m.symbol,
                cells: m.symbol ? root.symbolCells : m.name.length
            });
        }

        const named = key ? root.keyName(key) : "";
        if (named) {
            join();
            out.push({
                text: named,
                glyph: "",
                cells: named.length
            });
        }
        return out;
    }

    function partCells(parts: var): int {
        let n = 0;
        for (const p of parts)
            n += p.cells;
        return n;
    }

    function sharedMask(presses: var): int {
        if (presses.length === 0)
            return 0;
        let mask = ~0;
        for (const p of presses)
            mask &= p.mask;
        return mask;
    }

    readonly property bool fallback: (Hypr.parserKnown && !Hypr.lua) || (HyprConfig.ready && (!HyprConfig.configPath.endsWith(".lua") || HyprConfig.binds.length === 0))

    property var hyprRows: []
    property bool hyprRead: false

    readonly property var luaRows: {
        const out = [];
        for (const b of HyprConfig.binds) {
            const woven = !b.chordLiteral;
            const presses = (b.presses ?? []).filter(p => p.key);
            const mask = woven ? root.sharedMask(presses) : b.mask ?? 0;
            const said = (b.expr ?? "").trim();
            out.push({
                mask: mask,
                mods: root.modNames(mask).length,
                key: woven ? "" : (b.key ?? ""),
                presses: presses,
                submap: b.submap ?? "",
                woven: woven,
                action: (woven || !said ? (b.raw ?? "") : said).replace(/\s+/g, " ").trim()
            });
        }
        return out;
    }

    readonly property var rows: root.fallback ? root.hyprRows : root.luaRows

    function rowParts(row: var): var {
        const parts = root.chordParts(row.mask, row.key);
        if (row.mask > 0 && !row.key)
            parts.push({
                text: "…",
                glyph: "",
                cells: 1
            });
        return parts;
    }

    readonly property bool reading: !HyprConfig.ready || (root.fallback && !root.hyprRead)

    readonly property string source: root.fallback ? "hyprctl" : "the Lua config"

    readonly property int woven: root.rows.filter(r => r.woven).length

    function keyOf(bind: var): string {
        const named = (bind.key ?? "").trim();
        if (named)
            return named;
        if (bind.catch_all === true)
            return "any key";
        const code = bind.keycode ?? 0;
        return code > 0 ? `code:${code}` : "";
    }

    function readBinds(text: string): void {
        let raw = [];
        try {
            raw = JSON.parse(text);
        } catch (e) {
            console.warn(`CheatSheet: hyprctl binds did not answer with JSON: ${e}`);
        }
        const out = [];
        for (const b of Array.isArray(raw) ? raw : []) {
            const mask = b.modmask ?? 0;
            const key = root.keyOf(b);
            const dispatcher = (b.dispatcher ?? "").trim();
            const arg = (b.arg ?? "").trim();
            out.push({
                mask: mask,
                mods: root.modNames(mask).length,
                key: key,
                presses: key ? [{
                        mask: mask,
                        key: key
                    }] : [],
                submap: b.submap ?? "",
                woven: false,
                action: (b.description ?? "").trim() || (arg ? `${dispatcher} ${arg}` : dispatcher)
            });
        }
        root.hyprRows = out;
        root.hyprRead = true;
    }

    function refreshBinds(): void {
        if (root.fallback && !query.running)
            query.running = true;
    }

    onFallbackChanged: {
        if (root.fallback && root.open)
            root.refreshBinds();
    }

    function readDevices(text: string): void {
        let devices = {};
        try {
            devices = JSON.parse(text);
        } catch (e) {
            return console.warn(`CheatSheet: hyprctl devices did not answer with JSON: ${e}`);
        }

        const boards = devices.keyboards ?? [];
        let pick = null;
        for (const k of boards) {
            if (k.main === true) {
                pick = k;
                break;
            }
            if (!pick && (k.active_keymap ?? ""))
                pick = k;
        }
        if (!pick)
            return;

        root.keymap = pick.active_keymap ?? "";
        root.kbLayout = pick.layout ?? "";
        root.kbOptions = pick.options ?? "";
    }

    readonly property var sections: {
        const byKey = {};
        const out = [];

        for (const row of root.rows) {

            const key = row.woven ? `woven:${row.submap}` : `${row.submap}:${row.mask}`;
            let group = byKey[key];
            if (!group) {
                group = {
                    mask: row.woven ? 0 : row.mask,
                    mods: row.woven ? 0 : row.mods,
                    submap: row.submap,
                    woven: row.woven,
                    rows: []
                };
                byKey[key] = group;
                out.push(group);
            }
            group.rows.push(row);
        }

        out.sort((a, b) => (a.woven ? 1 : 0) - (b.woven ? 1 : 0) || b.rows.length - a.rows.length || a.mods - b.mods || a.mask - b.mask);
        return out;
    }

    readonly property real areaX: root.holeX + Appearance.sizes.gap
    readonly property real areaY: root.holeY + Appearance.sizes.gap
    readonly property real areaWidth: root.holeWidth - Appearance.sizes.gap * 2
    readonly property real areaHeight: root.holeHeight - Appearance.sizes.gap * 2

    readonly property real gutter: Appearance.padding.large

    readonly property real chordWidth: {
        let n = 0;
        for (const row of root.rows) {
            const c = root.partCells(root.rowParts(row));
            if (c > n)
                n = c;
        }
        return n * root.advance;
    }

    readonly property real contentWidth: root.chordWidth + root.gutter + Math.ceil(luaInk.width)

    readonly property real headWidth: title.implicitWidth + Appearance.padding.large + controls.implicitWidth

    readonly property real wantWidth: Math.min(root.areaWidth, Math.max(Appearance.sizes.menuWidth, root.headWidth, root.board ? keyboard.naturalPitch * keyboard.totalUnits : root.contentWidth) + Appearance.padding.large * 2)

    readonly property real wantHeight: Math.min(root.areaHeight, head.implicitHeight + Appearance.padding.normal + (root.board ? keyboard.implicitHeight : list.implicitHeight) + Appearance.padding.large * 2)

    readonly property real cardWidth: wide.value
    readonly property real cardHeight: tall.value

    readonly property bool arrived: root.open && reveal.settled

    readonly property real restY: root.areaY + (root.areaHeight - root.cardHeight) / 2

    readonly property real presence: root.pushing ? root.pushOut : reveal.value

    property bool pushing: false
    property real pushOut: 0

    readonly property real lift: (root.restY + root.cardHeight) * (1 - root.presence)

    function park(): void {
        if (root.board)
            root.boardY = view.contentY;
        else
            root.listY = view.contentY;
    }

    function restoreScroll(): void {
        view.contentY = root.board ? root.boardY : root.listY;
    }

    onBoardChanged: Qt.callLater(root.restoreScroll)

    function show(): void {
        if (root.open)
            return;
        root.restoreTo = Hypr.focusedOn(root.screenName);

        root.refreshDevices();
        root.refreshBinds();

        view.contentY = 0;
        root.listY = 0;
        root.boardY = 0;

        keyboard.forget();
        wide.snap();
        tall.snap();
        root.open = true;

        Qt.callLater(keys.forceActiveFocus);
    }

    function hide(): void {
        if (!root.open)
            return;
        root.open = false;
        keys.focus = false;
        Hypr.restoreFocus(root.restoreTo);
        root.restoreTo = "";
    }

    function toggle(): void {
        if (root.open)
            root.hide();
        else
            root.show();
    }

    function refreshDevices(): void {
        if (!devices.running)
            devices.running = true;
    }

    function pushTo(fraction: real): void {
        if (!root.open)
            return;
        root.pushing = true;
        root.pushOut = 1 - Math.max(0, Math.min(fraction, 1));
    }

    function pushEnd(gone: bool): void {

        if (!root.pushing)
            return;
        root.pushing = false;

        reveal.value = root.pushOut;
        root.pushOut = 0;
        if (gone)
            root.hide();
    }

    Follow {
        id: reveal

        speed: Appearance.animation.revealSpeed
        target: root.open ? 1 : 0

        epsilon: 0.005
    }

    Follow {
        id: wide

        speed: Appearance.animation.resizeSpeed
        target: root.wantWidth

        onTargetChanged: {
            if (!root.arrived)
                wide.snap();
        }
    }

    Follow {
        id: tall

        speed: Appearance.animation.resizeSpeed
        target: root.wantHeight

        onTargetChanged: {
            if (!root.arrived)
                tall.snap();
        }
    }

    Process {
        id: query

        command: ["hyprctl", "binds", "-j"]

        stdout: StdioCollector {
            onStreamFinished: root.readBinds(text)
        }
    }

    Process {
        id: devices

        command: ["hyprctl", "devices", "-j"]

        stdout: StdioCollector {
            onStreamFinished: root.readDevices(text)
        }
    }

    TextMetrics {
        id: em

        font.family: Appearance.font.family
        font.pixelSize: Appearance.font.size.small

        text: "M"
    }

    readonly property string widestLua: {
        let widest = "";
        for (const row of root.rows) {
            const t = row.action.length > 96 ? row.action.slice(0, 96) : row.action;
            if (t.length > widest.length)
                widest = t;
        }
        return widest;
    }

    TextMetrics {
        id: luaInk

        font.family: Appearance.font.family
        font.pixelSize: Appearance.font.size.small
        text: root.widestLua
    }

    Item {
        id: keys

        Keys.onPressed: event => {

            if (event.key !== Qt.Key_Escape)
                return;
            Appearance.instantly();
            root.hide();
            event.accepted = true;
        }
    }

    MouseArea {
        id: catcher

        anchors.fill: parent
        enabled: root.open
        visible: root.open

        onClicked: root.hide()
    }

    Pull {
        id: push

        x: card.x
        y: card.y
        width: card.width
        height: card.height

        visible: root.open

        dirX: 0
        dirY: -1

        angle: Config.values.control.pullAngleEdge

        travel: Math.min(root.cardHeight, push.fromY)

        onPulled: fraction => root.pushTo(fraction)
        onFinished: gone => root.pushEnd(gone)

    }

    Item {
        id: card

        x: root.areaX + (root.areaWidth - root.cardWidth) / 2
        y: root.restY - root.lift
        width: root.cardWidth
        height: root.cardHeight

        visible: root.presence > 0.001
        enabled: root.open

        opacity: root.presence

        SquircleRect {
            anchors.fill: parent

            radius: Appearance.rounding.large
            color: Appearance.colour.surface

            Item {
                anchors.fill: parent
                anchors.margins: Appearance.padding.large

                Column {
                    id: head

                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right

                    Item {
                        width: parent.width
                        height: Math.max(title.implicitHeight, controls.implicitHeight)

                        StyledText {
                            id: title

                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter

                            text: "Hotkeys"

                            font.pixelSize: Appearance.font.size.normal
                        }

                        Row {
                            id: controls

                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Appearance.padding.normal

                            Segments {
                                options: ["List", "Board"]
                                current: root.board ? 1 : 0

                                onPicked: i => {
                                    root.board = i === 1;
                                }
                            }
                        }
                    }

                    StyledText {
                        width: parent.width
                        wrapMode: Text.WordWrap

                        text: root.reading ? `reading ${root.source}…` : root.woven > 0 ? `${root.rows.length} binds from ${root.source}, ${root.woven} woven` : `${root.rows.length} binds from ${root.source}`
                        color: Appearance.colour.textFaint
                    }
                }

                Flickable {
                    id: view

                    anchors.top: head.bottom
                    anchors.topMargin: Appearance.padding.normal
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom

                    contentHeight: root.board ? keyboard.implicitHeight : list.implicitHeight
                    interactive: contentHeight > height
                    clip: interactive
                    boundsBehavior: Flickable.StopAtBounds

                    onMovementEnded: root.park()

                    WheelStep {
                        flick: view

                        onEnded: root.park()
                    }

                    BindList {
                        id: list

                        width: view.width
                        visible: !root.board

                        sheet: root
                    }

                    Keyboard {
                        id: keyboard

                        width: view.width
                        visible: root.board

                        sheet: root
                        advance: root.advance
                    }
                }
            }
        }
    }
}
