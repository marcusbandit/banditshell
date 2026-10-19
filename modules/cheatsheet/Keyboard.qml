pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root

    required property var sheet

    required property real advance

    property int latched: 0

    property var picked: null

    readonly property real seam: Appearance.padding.small

    readonly property bool fromLayout: Keyboards.board !== null

    readonly property var sections: root.fromLayout ? Keyboards.board.sections : Keyboards.template

    readonly property var deskRows: root.sheet.rows.filter(r => !r.submap)

    readonly property int inModes: root.sheet.rows.length - root.deskRows.length

    readonly property var bound: {
        const set = {};
        for (const row of root.sheet.rows)
            for (const p of row.presses)
                set[p.key.toLowerCase()] = true;
        return set;
    }

    function sectionOn(section: var): bool {
        if (root.fromLayout || section.id !== "numpad")
            return true;
        for (const cell of section.keys)
            for (const s of cell.syms) {
                const low = s.toLowerCase();
                if (root.bound[low] && Keyboards.blocked[low] === undefined)
                    return true;
            }
        return false;
    }

    readonly property var shown: root.sections.filter(s => root.sectionOn(s))

    readonly property real totalUnits: {
        let n = 0;
        for (const section of root.shown)
            n = Math.max(n, section.x + section.width);
        return n;
    }

    readonly property real totalRows: {
        let n = 0;
        for (const section of root.shown)
            n = Math.max(n, section.y + section.height);
        return n;
    }

    readonly property var optionKeys: [
        {
            option: "caps:backspace",
            role: "CAPS",
            cap: "Back",
            syms: ["BackSpace"],
            mod: 0
        },
        {
            option: "grp:switch",
            role: "RALT",
            cap: "AltGr",
            syms: [],
            mod: 0
        }
    ]

    readonly property var options: root.sheet.kbOptions.split(",").map(o => o.trim())

    function dress(cell: var): var {
        let cap = cell.cap;
        let syms = cell.syms;
        let mod = cell.mod;
        for (const o of root.optionKeys) {
            if (o.role !== cell.role || root.options.indexOf(o.option) < 0)
                continue;
            cap = o.cap;
            syms = o.syms;
            mod = o.mod;
        }
        return {
            id: cell.id,
            role: cell.role,
            cap: cap,
            syms: syms,
            mod: mod,
            matrix: cell.matrix,
            encoder: cell.encoder,
            x: cell.x,
            y: cell.y,
            w: cell.w,
            h: cell.h,
            foot: cell.foot
        };
    }

    readonly property var placed: {
        const out = [];
        for (const section of root.shown)
            for (const cell of section.keys) {
                const key = root.dress(cell);
                key.x = section.x + cell.x;
                key.y = section.y + cell.y;
                out.push(key);
            }
        return out;
    }

    function glyphOf(key: var): string {
        return key.mod ? root.sheet.modSymbol(key.mod) : "";
    }

    readonly property real legendMargin: Appearance.padding.hair

    function legendWidth(cap: string, glyph: string): real {
        const sigil = glyph ? Appearance.font.size.small + (cap ? Appearance.padding.hair : 0) : 0;
        return cap.length * root.advance + sigil + root.legendMargin * 2 + root.seam;
    }

    readonly property real naturalPitch: {
        let p = Appearance.sizes.minTarget + root.seam;
        for (const k of root.placed) {
            const need = root.legendWidth(k.cap, root.glyphOf(k)) / k.w;
            if (need > p)
                p = need;
        }
        return Math.ceil(p);
    }

    readonly property real pitch: root.totalUnits > 0 ? Math.min(root.naturalPitch, Math.floor(root.width / root.totalUnits)) : 0

    readonly property bool fits: root.pitch >= Appearance.sizes.minTarget + root.seam

    readonly property real boardWidth: root.totalUnits * root.pitch
    readonly property real boardHeight: root.totalRows * root.pitch - root.seam

    readonly property var lit: {
        const m = {};
        for (const row of root.deskRows)
            for (const p of row.presses)
                if (p.mask === root.latched)
                    m[p.key.toLowerCase()] = true;
        return m;
    }

    function isLit(syms: var): bool {
        for (const s of syms)
            if (root.lit[s.toLowerCase()])
                return true;
        return false;
    }

    function modOffers(bit: int): bool {
        if ((root.latched & bit) !== 0)
            return false;
        const want = root.latched | bit;
        for (const row of root.deskRows)
            for (const p of row.presses)
                if ((p.mask & want) === want)
                    return true;
        return false;
    }

    function toggleMod(bit: int): void {
        root.latched = (root.latched & bit) !== 0 ? root.latched & ~bit : root.latched | bit;
    }

    function forget(): void {
        root.latched = 0;
        root.picked = null;
    }

    function choose(key: var): void {
        root.picked = root.picked && root.picked.id === key.id && root.picked.note === undefined ? null : {
            id: key.id,
            cap: key.cap,
            syms: key.syms
        };
    }

    function readBlocked(key: var, note: string): void {
        root.picked = root.picked && root.picked.note !== undefined && root.picked.id === key.id ? null : {
            id: key.id,
            cap: key.cap || key.matrix,
            note: note
        };
    }

    readonly property var offBoard: {
        const known = {};
        for (const k of root.placed)
            for (const s of k.syms)
                known[s.toLowerCase()] = true;

        const seen = {};
        const out = [];
        for (const row of root.deskRows)
            for (const p of row.presses) {
                const low = p.key.toLowerCase();
                if (known[low] || seen[low] || low.startsWith("switch:"))
                    continue;
                seen[low] = true;
                out.push({
                    id: `off:${low}`,
                    cap: root.sheet.keyName(p.key),
                    syms: [p.key],
                    matrix: ""
                });
            }
        out.sort((a, b) => a.cap.localeCompare(b.cap));
        return out;
    }

    readonly property var chosen: {
        if (!root.picked || root.picked.note !== undefined)
            return [];
        const want = {};
        for (const s of root.picked.syms)
            want[s.toLowerCase()] = true;

        const out = [];
        for (const row of root.deskRows) {
            const press = row.presses.find(p => want[p.key.toLowerCase()] && (p.mask & root.latched) === root.latched);
            if (press)
                out.push({
                    mask: press.mask,
                    key: press.key,
                    action: row.action
                });
        }

        out.sort((a, b) => (a.mask === root.latched ? 0 : 1) - (b.mask === root.latched ? 0 : 1) || a.mask - b.mask);
        return out;
    }

    readonly property int reach: {
        let n = 0;
        for (const row of root.deskRows)
            if (row.presses.some(p => p.mask === root.latched))
                n++;
        return n;
    }

    readonly property int busiest: {
        const n = {};
        let most = 0;
        for (const row of root.deskRows) {
            const once = {};
            for (const p of row.presses) {
                const low = p.key.toLowerCase();
                if (once[low])
                    continue;
                once[low] = true;
                n[low] = (n[low] ?? 0) + 1;
                most = Math.max(most, n[low]);
            }
        }
        return most;
    }

    readonly property string footer: {
        const parts = [];
        if (root.sheet.keymap)
            parts.push(root.sheet.keymap);
        if (root.fromLayout && Keyboards.board.name)
            parts.push(Keyboards.board.name);
        parts.push(Keyboards.variant.toUpperCase());
        if (root.sheet.kbOptions)
            parts.push(root.sheet.kbOptions);
        return parts.join(", ");
    }

    readonly property real lineBox: Appearance.font.line.small

    implicitHeight: stack.implicitHeight

    Column {
        id: stack

        width: parent.width
        spacing: Appearance.padding.normal

        StyledText {
            width: parent.width
            wrapMode: Text.WordWrap
            visible: !root.fits

            text: `the board needs ${Math.ceil(root.totalUnits * (Appearance.sizes.minTarget + root.seam))}px, ${Math.floor(root.width)}px here`
            color: Appearance.colour.textFaint
        }

        Item {
            width: parent.width
            height: root.fits ? root.boardHeight : 0
            visible: root.fits

            Item {
                x: Math.round((parent.width - root.boardWidth) / 2)
                width: root.boardWidth
                height: parent.height

                Repeater {
                    model: root.placed

                    delegate: KeyCap {
                        id: cap

                        required property var modelData

                        readonly property var note: Keyboards.blockedNote(cap.modelData)

                        x: cap.modelData.x * root.pitch
                        y: cap.modelData.y * root.pitch

                        units: cap.modelData.w
                        span: cap.modelData.h
                        foot: cap.modelData.foot
                        pitch: root.pitch
                        seam: root.seam
                        margin: root.legendMargin

                        label: cap.modelData.cap
                        glyph: root.glyphOf(cap.modelData)
                        blocked: cap.note !== null

                        latched: cap.modelData.mod ? (root.latched & cap.modelData.mod) !== 0 : false
                        lit: !cap.blocked && (cap.modelData.mod ? root.modOffers(cap.modelData.mod) : root.isLit(cap.modelData.syms))
                        selected: !cap.modelData.mod && !!root.picked && root.picked.id === cap.modelData.id

                        onTapped: cap.note !== null ? root.readBlocked(cap.modelData, cap.note) : cap.modelData.mod ? root.toggleMod(cap.modelData.mod) : root.choose(cap.modelData)
                    }
                }
            }
        }

        Column {
            width: parent.width
            spacing: Appearance.padding.small
            visible: root.fits && root.offBoard.length > 0

            StyledText {
                width: parent.width
                elide: Text.ElideRight

                text: "bound, not on the board"
                color: Appearance.colour.textFaint
            }

            Flow {
                width: parent.width
                spacing: root.seam

                Repeater {
                    model: root.offBoard

                    delegate: KeyCap {
                        id: spare

                        required property var modelData

                        readonly property var note: Keyboards.blockedNote(spare.modelData)

                        units: root.pitch > 0 ? Math.min(root.totalUnits, root.legendWidth(spare.modelData.cap, "") / root.pitch) : 1
                        pitch: root.pitch
                        seam: root.seam
                        margin: root.legendMargin

                        label: spare.modelData.cap
                        blocked: spare.note !== null
                        lit: spare.note === null && root.isLit(spare.modelData.syms)
                        selected: !!root.picked && root.picked.id === spare.modelData.id

                        onTapped: spare.note !== null ? root.readBlocked(spare.modelData, spare.note) : root.choose(spare.modelData)
                    }
                }
            }
        }

        Separator {
            width: parent.width
        }

        Item {
            width: parent.width
            height: Math.max(Appearance.sizes.rowHeight * 2, root.busiest * root.lineBox + Math.max(0, root.busiest - 1) * Appearance.padding.small)

            Flickable {
                id: answer

                anchors.fill: parent

                contentHeight: lines.implicitHeight
                interactive: contentHeight > height
                clip: interactive
                boundsBehavior: Flickable.StopAtBounds

                WheelStep {
                    flick: answer
                }

                Column {
                    id: lines

                    width: answer.width
                    spacing: Appearance.padding.small

                    StyledText {
                        width: parent.width
                        elide: Text.ElideRight
                        visible: !root.picked && root.latched > 0

                        text: `${root.reach} binds`
                        color: Appearance.colour.textFaint
                    }

                    StyledText {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        visible: !!root.picked && root.picked.note !== undefined

                        text: root.picked ? `${root.picked.cap}: ${root.picked.note || "struck"}` : ""
                        color: Appearance.colour.textFaint
                    }

                    StyledText {
                        width: parent.width
                        elide: Text.ElideRight
                        visible: !!root.picked && root.picked.note === undefined && root.chosen.length === 0

                        text: root.picked ? `${root.picked.cap}: nothing bound` : ""
                        color: Appearance.colour.textFaint
                    }

                    Repeater {
                        model: root.chosen

                        delegate: Item {
                            id: hit

                            required property var modelData

                            width: lines.width
                            height: says.implicitHeight

                            Chord {
                                id: says

                                parts: root.sheet.chordParts(hit.modelData.mask, hit.modelData.key)
                                advance: root.advance
                            }

                            StyledText {
                                x: says.implicitWidth + Appearance.padding.large
                                width: Math.max(0, hit.width - says.implicitWidth - Appearance.padding.large)
                                elide: Text.ElideRight

                                text: hit.modelData.action
                                color: Appearance.colour.textDim
                            }
                        }
                    }
                }
            }
        }

        StyledText {
            width: parent.width
            elide: Text.ElideRight
            visible: root.inModes > 0

            text: `${root.inModes} binds in submaps`
            color: Appearance.colour.textFaint
        }

        StyledText {
            width: parent.width
            elide: Text.ElideRight

            text: root.footer
            color: Appearance.colour.textFaint
        }
    }
}
