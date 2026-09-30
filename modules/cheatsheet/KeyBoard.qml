pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

Item {
    id: root

    required property var sheet

    required property real advance

    property int latched: 0

    property var picked: null

    readonly property real seam: Appearance.padding.small

    readonly property var plan: [
        [
            {
                id: "ESC",
                cap: "ESC",
                syms: ["escape"]
            },
            {
                units: 1
            },
            {
                id: "F1",
                cap: "F1",
                syms: ["F1"]
            },
            {
                id: "F2",
                cap: "F2",
                syms: ["F2"]
            },
            {
                id: "F3",
                cap: "F3",
                syms: ["F3"]
            },
            {
                id: "F4",
                cap: "F4",
                syms: ["F4"]
            },
            {
                units: 0.5
            },
            {
                id: "F5",
                cap: "F5",
                syms: ["F5"]
            },
            {
                id: "F6",
                cap: "F6",
                syms: ["F6"]
            },
            {
                id: "F7",
                cap: "F7",
                syms: ["F7"]
            },
            {
                id: "F8",
                cap: "F8",
                syms: ["F8"]
            },
            {
                units: 0.5
            },
            {
                id: "F9",
                cap: "F9",
                syms: ["F9"]
            },
            {
                id: "F10",
                cap: "F10",
                syms: ["F10"]
            },
            {
                id: "F11",
                cap: "F11",
                syms: ["F11"]
            },
            {
                id: "F12",
                cap: "F12",
                syms: ["F12"]
            }
        ],
        [
            {
                id: "TLDE",
                cap: "`",
                syms: ["grave"]
            },
            {
                id: "AE01",
                cap: "1",
                syms: ["1"]
            },
            {
                id: "AE02",
                cap: "2",
                syms: ["2"]
            },
            {
                id: "AE03",
                cap: "3",
                syms: ["3"]
            },
            {
                id: "AE04",
                cap: "4",
                syms: ["4"]
            },
            {
                id: "AE05",
                cap: "5",
                syms: ["5"]
            },
            {
                id: "AE06",
                cap: "6",
                syms: ["6"]
            },
            {
                id: "AE07",
                cap: "7",
                syms: ["7"]
            },
            {
                id: "AE08",
                cap: "8",
                syms: ["8"]
            },
            {
                id: "AE09",
                cap: "9",
                syms: ["9"]
            },
            {
                id: "AE10",
                cap: "0",
                syms: ["0"]
            },
            {
                id: "AE11",
                cap: "-",
                syms: ["minus"]
            },
            {
                id: "AE12",
                cap: "=",
                syms: ["equal"]
            },
            {
                id: "BKSP",
                cap: "BACK",
                syms: ["BackSpace"],
                units: 2
            }
        ],
        [
            {
                id: "TAB",
                cap: "TAB",
                syms: ["tab"],
                units: 1.5
            },
            {
                id: "AD01",
                cap: "Q",
                syms: ["q"]
            },
            {
                id: "AD02",
                cap: "W",
                syms: ["w"]
            },
            {
                id: "AD03",
                cap: "E",
                syms: ["e"]
            },
            {
                id: "AD04",
                cap: "R",
                syms: ["r"]
            },
            {
                id: "AD05",
                cap: "T",
                syms: ["t"]
            },
            {
                id: "AD06",
                cap: "Y",
                syms: ["y"]
            },
            {
                id: "AD07",
                cap: "U",
                syms: ["u"]
            },
            {
                id: "AD08",
                cap: "I",
                syms: ["i"]
            },
            {
                id: "AD09",
                cap: "O",
                syms: ["o"]
            },
            {
                id: "AD10",
                cap: "P",
                syms: ["p"]
            },
            {
                id: "AD11",
                cap: "[",
                syms: ["bracketleft"]
            },
            {
                id: "AD12",
                cap: "]",
                syms: ["bracketright"]
            },
            {
                id: "RTRN",
                cap: "ENTER",
                syms: ["Return"],
                units: 1.5,
                foot: 1.25
            }
        ],
        [
            {
                id: "CAPS",
                cap: "CAPS",
                syms: ["Caps_Lock"],
                units: 1.75
            },
            {
                id: "AC01",
                cap: "A",
                syms: ["a"]
            },
            {
                id: "AC02",
                cap: "S",
                syms: ["s"]
            },
            {
                id: "AC03",
                cap: "D",
                syms: ["d"]
            },
            {
                id: "AC04",
                cap: "F",
                syms: ["f"]
            },
            {
                id: "AC05",
                cap: "G",
                syms: ["g"]
            },
            {
                id: "AC06",
                cap: "H",
                syms: ["h"]
            },
            {
                id: "AC07",
                cap: "J",
                syms: ["j"]
            },
            {
                id: "AC08",
                cap: "K",
                syms: ["k"]
            },
            {
                id: "AC09",
                cap: "L",
                syms: ["l"]
            },
            {
                id: "AC10",
                cap: ";",
                syms: ["semicolon"]
            },
            {
                id: "AC11",
                cap: "'",
                syms: ["apostrophe"]
            },
            {
                id: "BKSL",
                cap: "\\",
                syms: ["backslash"]
            }
        ],
        [
            {
                id: "LFSH",
                cap: "SHIFT",
                syms: [],
                mod: 1,
                units: 1.25
            },
            {
                id: "LSGT",
                cap: "<",
                syms: ["less"]
            },
            {
                id: "AB01",
                cap: "Z",
                syms: ["z"]
            },
            {
                id: "AB02",
                cap: "X",
                syms: ["x"]
            },
            {
                id: "AB03",
                cap: "C",
                syms: ["c"]
            },
            {
                id: "AB04",
                cap: "V",
                syms: ["v"]
            },
            {
                id: "AB05",
                cap: "B",
                syms: ["b"]
            },
            {
                id: "AB06",
                cap: "N",
                syms: ["n"]
            },
            {
                id: "AB07",
                cap: "M",
                syms: ["m"]
            },
            {
                id: "AB08",
                cap: ",",
                syms: ["comma"]
            },
            {
                id: "AB09",
                cap: ".",
                syms: ["period"]
            },
            {
                id: "AB10",
                cap: "/",
                syms: ["slash"]
            },
            {
                id: "RTSH",
                cap: "SHIFT",
                syms: [],
                mod: 1,
                units: 2.75
            },
            {
                units: 1.25
            },
            {
                id: "UP",
                cap: "↑",
                syms: ["Up"]
            }
        ],
        [
            {
                id: "LCTL",
                cap: "CTRL",
                syms: [],
                mod: 4,
                units: 1.25
            },
            {
                id: "LWIN",
                cap: "SUPER",
                syms: [],
                mod: 64,
                units: 1.25
            },
            {
                id: "LALT",
                cap: "ALT",
                syms: [],
                mod: 8,
                units: 1.25
            },
            {
                id: "SPCE",
                cap: "",
                syms: ["space"],
                units: 6.25
            },
            {
                id: "RALT",
                cap: "ALT",
                syms: [],
                mod: 8,
                units: 1.25
            },
            {
                id: "RWIN",
                cap: "SUPER",
                syms: [],
                mod: 64,
                units: 1.25
            },
            {
                id: "MENU",
                cap: "MENU",
                syms: ["Menu"],
                units: 1.25
            },
            {
                id: "RCTL",
                cap: "CTRL",
                syms: [],
                mod: 4,
                units: 1.25
            },
            {
                units: 0.25
            },
            {
                id: "LEFT",
                cap: "←",
                syms: ["Left"]
            },
            {
                id: "DOWN",
                cap: "↓",
                syms: ["Down"]
            },
            {
                id: "RIGHT",
                cap: "→",
                syms: ["Right"]
            }
        ]
    ]

    readonly property var optionKeys: [
        {
            option: "caps:backspace",
            id: "CAPS",
            cap: "BACK",
            syms: ["BackSpace"],
            mod: 0
        },
        {
            option: "grp:switch",
            id: "RALT",
            cap: "ALTGR",
            syms: [],
            mod: 0
        }
    ]

    function dress(cell: var): var {
        for (const o of root.optionKeys) {
            if (o.id !== cell.id)
                continue;
            if (root.sheet.kbOptions.indexOf(o.option) < 0)
                continue;
            return {
                id: cell.id,
                cap: o.cap,
                syms: o.syms,
                mod: o.mod,
                units: cell.units ?? 1,
                foot: cell.foot ?? 0
            };
        }
        return {
            id: cell.id,
            cap: cell.cap,
            syms: cell.syms,
            mod: cell.mod ?? 0,
            units: cell.units ?? 1,
            foot: cell.foot ?? 0
        };
    }

    readonly property var placed: {
        const out = [];
        for (let r = 0; r < root.plan.length; r++) {
            let at = 0;
            for (const cell of root.plan[r]) {
                const units = cell.units ?? 1;
                if (cell.id) {
                    const key = root.dress(cell);
                    key.row = r;
                    key.at = at;
                    out.push(key);
                }
                at += units;
            }
        }
        return out;
    }

    readonly property real totalUnits: {
        let out = 0;
        for (const k of root.placed)
            out = Math.max(out, k.at + k.units);
        return out;
    }

    readonly property real naturalPitch: {
        let p = Appearance.sizes.minTarget + root.seam;
        for (const k of root.placed) {
            const need = (k.cap.length * root.advance + Appearance.padding.normal + root.seam) / k.units;
            if (need > p)
                p = need;
        }
        return Math.ceil(p);
    }

    readonly property real pitch: Math.min(root.naturalPitch, Math.floor(root.width / root.totalUnits))

    readonly property bool fits: root.pitch >= Appearance.sizes.minTarget + root.seam

    readonly property real boardWidth: root.totalUnits * root.pitch
    readonly property real boardHeight: root.plan.length * root.pitch - root.seam

    readonly property var deskRows: root.sheet.rows.filter(r => !r.submap)

    readonly property int inModes: root.sheet.rows.length - root.deskRows.length

    readonly property var lit: {
        const m = {};
        for (const row of root.deskRows) {
            if (row.mask !== root.latched || !row.key)
                continue;
            const low = row.key.toLowerCase();
            m[low] = (m[low] ?? 0) + 1;
        }
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
            if ((row.mask & want) === want)
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

    function choose(cap: string, syms: var): void {
        root.picked = root.picked && root.picked.cap === cap ? null : {
            cap: cap,
            syms: syms
        };
    }

    readonly property var offBoard: {
        const known = {};
        for (const k of root.placed)
            for (const s of k.syms)
                known[s.toLowerCase()] = true;

        const seen = {};
        const out = [];
        for (const row of root.deskRows) {
            if (!row.key)
                continue;
            const low = row.key.toLowerCase();
            if (known[low] || seen[low])
                continue;
            seen[low] = true;
            out.push({
                cap: root.sheet.keyName(row.key),
                syms: [row.key]
            });
        }
        out.sort((a, b) => a.cap.localeCompare(b.cap));
        return out;
    }

    readonly property var chosen: {
        if (!root.picked)
            return [];
        const want = {};
        for (const s of root.picked.syms)
            want[s.toLowerCase()] = true;

        const out = [];
        for (const row of root.deskRows)
            if (row.key && want[row.key.toLowerCase()] && (row.mask & root.latched) === root.latched)
                out.push(row);

        out.sort((a, b) => (a.mask === root.latched ? 0 : 1) - (b.mask === root.latched ? 0 : 1) || a.mask - b.mask);
        return out;
    }

    readonly property int reach: {
        let n = 0;
        for (const row of root.deskRows)
            if (row.mask === root.latched)
                n++;
        return n;
    }

    readonly property int busiest: {
        const n = {};
        let most = 0;
        for (const row of root.deskRows) {
            if (!row.key)
                continue;
            const low = row.key.toLowerCase();
            n[low] = (n[low] ?? 0) + 1;
            if (n[low] > most)
                most = n[low];
        }
        return most;
    }

    readonly property real lineBox: Math.round(Appearance.font.size.small * 4 / 3)

    implicitHeight: stack.implicitHeight

    Column {
        id: stack

        width: parent.width
        spacing: Appearance.padding.normal

        StyledText {
            width: parent.width
            wrapMode: Text.WordWrap
            visible: !root.fits

            text: `not enough room for a board a finger can press: ${root.totalUnits} keys wide needs ${Math.ceil(root.totalUnits * (Appearance.sizes.minTarget + root.seam))}px and there are ${Math.floor(root.width)}. The list has the same binds.`
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

                        x: cap.modelData.at * root.pitch
                        y: cap.modelData.row * root.pitch

                        readonly property string sym: cap.modelData.mod && root.sheet.symbols ? root.sheet.modSymbol(cap.modelData.mod) : ""

                        units: cap.modelData.units
                        foot: cap.modelData.foot
                        pitch: root.pitch
                        seam: root.seam

                        label: cap.sym ? "" : cap.modelData.cap
                        glyph: cap.sym

                        latched: cap.modelData.mod ? (root.latched & cap.modelData.mod) !== 0 : false
                        lit: cap.modelData.mod ? root.modOffers(cap.modelData.mod) : root.isLit(cap.modelData.syms)
                        selected: !cap.modelData.mod && !!root.picked && root.picked.cap === cap.modelData.cap

                        onTapped: cap.modelData.mod ? root.toggleMod(cap.modelData.mod) : root.choose(cap.modelData.cap, cap.modelData.syms)
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

                text: "bound, and not on an ISO board"
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

                        units: root.pitch > 0 ? (spare.modelData.cap.length * root.advance + Appearance.padding.normal + root.seam) / root.pitch : 1
                        pitch: root.pitch
                        seam: root.seam

                        label: spare.modelData.cap
                        lit: root.isLit(spare.modelData.syms)
                        selected: !!root.picked && root.picked.cap === spare.modelData.cap

                        onTapped: root.choose(spare.modelData.cap, spare.modelData.syms)
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

                Column {
                    id: lines

                    width: answer.width
                    spacing: Appearance.padding.small

                    StyledText {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        visible: !root.picked

                        text: root.latched > 0 ? `${root.reach} binds under what you are holding: tap a key to read one` : "tap a modifier to hold it, tap a key to read it"
                        color: Appearance.colour.textFaint
                    }

                    StyledText {
                        width: parent.width
                        elide: Text.ElideRight
                        visible: !!root.picked && root.chosen.length === 0

                        text: root.picked ? `${root.picked.cap}: nothing bound here` : ""
                        color: Appearance.colour.textGhost
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

                                text: hit.modelData.what || hit.modelData.raw
                                color: hit.modelData.what ? Appearance.colour.textDim : Appearance.colour.textGhost
                            }
                        }
                    }
                }
            }
        }

        StyledText {
            width: parent.width
            wrapMode: Text.WordWrap
            visible: root.inModes > 0

            text: `${root.inModes} binds live inside a submap and only fire once you are in it, so they are not on the board: the list has them, under the mode's own name`
            color: Appearance.colour.textGhost
        }

        StyledText {
            width: parent.width
            wrapMode: Text.WordWrap

            text: root.sheet.keymap ? (root.sheet.kbOptions ? `${root.sheet.keymap}, ISO, ${root.sheet.kbOptions}` : `${root.sheet.keymap}, ISO`) : "ISO"
            color: Appearance.colour.textGhost
        }
    }
}
