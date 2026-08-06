pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

// THE BOARD: the same binds, arranged the way your hands know them.
//
// The list next door answers "what is on SUPER" perfectly and answers "what is
// on this key" not at all, because to find that out you have to read every
// group. This is the other index into the same data: hold a modifier and the
// keys it reaches light up, tap one and it says what it does. The user asked
// for it twice in one sentence, which is usually the sign that a feature is the
// point rather than a decoration.
//
// IT IS A SCHEMATIC OF AN ISO BOARD, NOT A PHOTOGRAPH OF THIS ONE, and that is a
// decision rather than a shortcut. What is drawn is the ISO main block plus the
// arrow cluster, because that is the part every ISO keyboard has, in the same
// place, in the same proportions: the alphanumeric island, the tall enter, the
// extra key beside the left shift. Everything to the RIGHT of that differs per
// chassis and cannot be asked for. This machine is a laptop, so it has no
// separate print/scroll/pause cluster and no navigation block; a desktop board
// has both; another laptop puts home and end on the arrow keys. Drawing three
// keys that are not under your fingers, to fill a hole in a picture, would be
// the board lying about the hardware, which is the one thing a reference must
// not do.
//
// WHAT THAT LEAVES OUT IS PUT BACK BY THE DATA. Every bind whose key has no cap
// on the board (the media and brightness keys, the mouse buttons, a `code:36`)
// becomes a cap in the row underneath, built from the binds themselves rather
// than from a second list to keep in step. So the board is complete about the
// binds even where it is deliberately incomplete about the chassis: on this
// machine that is ten XF86 keys and two mouse buttons, which is an eighth of
// everything bound and would otherwise be invisible here.
//
// THE LAYOUT IS DATA AND THE GEOMETRY IS A FOLD OVER IT. A row is a list of
// widths in UNITS and the x of a key is the sum of the units before it, so
// there is not one pixel position written down anywhere and the whole board
// rescales from a single pitch (~/.claude/rules/math-over-hardcoding.md). That
// is also what makes the ISO enter possible to state at all: it is 1.5 units of
// one row and 1.25 of the next, and the two numbers are the shape.
Item {
    id: root

    // The sheet, for the binds and the vocabulary. A `var` and not a CheatSheet,
    // because CheatSheet instantiates this file: naming the type here would be a
    // cycle between two components in one directory, and the thing gained would
    // be a type name in a property that has exactly one possible value.
    required property var sheet

    // One character of the shell's face, measured once by the sheet. The board's
    // pitch comes out of it, which is why it is measured rather than assumed.
    required property real advance

    // WHICH MODIFIERS ARE BEING HELD, as the same xkb bitfield the compositor
    // reports, so a latched set and a bind's `modmask` compare with `===` and
    // nothing has to be translated in between.
    //
    // They LATCH rather than being held down, which is the whole reason this
    // works with one finger: a board you had to physically hold SUPER on to read
    // would need the other hand on the mouse and would fire the bind you were
    // trying to look up. Tap to hold, tap again to let go.
    property int latched: 0

    // WHICH KEY WAS ASKED ABOUT: `{ cap, syms }`, or null for none. Not a plain
    // string, because a key can answer to more than one keysym name (a config
    // may write `Prior` or `Page_Up` for the same physical key) and the readout
    // has to find binds under either.
    property var picked: null

    readonly property real seam: Appearance.padding.small

    // The ISO main block plus the arrows. Each cell is a width in units, and a
    // cell with an `id` is a key rather than a gap; `units` defaults to 1
    // because most keys are one unit and writing it eighty times would bury the
    // ones that are not.
    //
    // `syms` are the KEYSYM NAMES a bind may spell this key with, matched
    // case-insensitively because the compositor hands back whatever the config
    // wrote and this machine's own binds arrive as `RETURN`, `tab`, `Slash` and
    // `grave` in the same list. A key with more than one name has all of them:
    // xkb calls the page keys `Prior` and `Next`, everyone else calls them
    // `Page_Up` and `Page_Down`, and both compile.
    //
    // `mod` is the xkb bit a modifier contributes, and it is deliberately the
    // same bit for both sides: Hyprland's `modmask` has one SHIFT bit and no
    // opinion about which shift you pressed, so both shifts latch together and
    // both light together. Pretending otherwise would be the board inventing a
    // distinction the compositor cannot make.
    //
    // THE CAPS ARE WHAT THIS LAYOUT PRODUCES, which was compiled rather than
    // remembered: `hyprctl getoption input:kb_layout` says `us,dk` with the
    // active group being English (US), and `xkbcli compile-keymap` on exactly
    // that gives `less`/`greater` for the key beside the left shift and
    // `backslash`/`bar` for the one left of the enter. Those are the two keys an
    // ISO board has and an ANSI one does not, so they are the two that would
    // have been guessed wrong. Only the unshifted legend is printed: a real
    // keycap carries two, and a second string per key would either need a fourth
    // type size or would halve the size of the one that matters
    // (~/.claude/rules/type-scale.md).
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

    // WHAT `input:kb_options` DID TO THE BOARD, for the options this file knows
    // how to apply, and nothing else.
    //
    // An xkb option can move a key's whole meaning, and two of the ones set on
    // this machine do. `caps:backspace` makes the caps key a second backspace,
    // which the compiled keymap confirms: `key <CAPS> { symbols[1] = [ BackSpace
    // ] }` and nothing in any modifier map. `grp:switch` makes the right alt the
    // layout switch, so the compiled `modifier_map Mod1` lists the LEFT alt
    // alone; a board that went on calling that key ALT would light it whenever
    // an ALT bind existed and it would never fire one.
    //
    // A TABLE AND NOT A BRANCH, because the honest scope of this is "the options
    // the sheet has been taught", and a table makes that scope readable and
    // extendable. An option not in here changes nothing: the physical key keeps
    // its legend, which is the right failure, since the legend is then at worst
    // out of date rather than actively wrong about what the key sends.
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

    // A key as the running keymap leaves it. Nothing to apply is the common
    // case, so the plan's own entry is returned unchanged rather than copied.
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

    // THE FOLD: every key with the row it is on and how many units precede it.
    //
    // Flat rather than nested, and in reading order, which is what keeps the ISO
    // enter's foot out of the way of the key to its left. The enter's item is
    // the bounding box of an L, so a quarter unit of it hangs over the end of
    // the backslash key; the backslash comes LATER in this list, declaration
    // order is input order in QML, and the later sibling takes the press. (Its
    // own file also puts the areas on the two drawn pieces rather than on the
    // box, so this is a belt as well as braces.)
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

    // How wide and how tall the board is, IN UNITS, read off the fold rather
    // than written down. The arrow cluster is the only thing past the main
    // block's fifteen, so this is the one place that knows the board is 18.25
    // wide, and it knows it by adding up.
    readonly property real totalUnits: {
        let out = 0;
        for (const k of root.placed)
            out = Math.max(out, k.at + k.units);
        return out;
    }

    // WHAT ONE UNIT WANTS TO BE, measured off the legends.
    //
    // A key is two things at once: a target a finger lands on, and a box a word
    // has to fit in. WCAG's minimum target is the floor and it is nowhere near
    // the answer here, because SHIFT on 1.25 units needs five characters and a
    // little air, and five characters of an 18px pixel font is sixty pixels. So
    // the pitch is the widest DEMAND any key makes, divided by the units that
    // key has to spend it over, and the floor is only reached on a board whose
    // longest legend is a single character.
    //
    // Measured off the WORDS even while the symbols are showing, deliberately.
    // In symbols mode the modifier legends collapse to one glyph each and the
    // demand falls away, so the board could be a third narrower; letting it be
    // would mean the whole keyboard changed size when you flipped how the
    // modifiers are spelled, and a reference that resizes under you while you
    // are reading it is worse than one that is bigger than it strictly needs to
    // be. It is sized for its worst case and holds still.
    readonly property real naturalPitch: {
        let p = Appearance.sizes.minTarget + root.seam;
        for (const k of root.placed) {
            const need = (k.cap.length * root.advance + Appearance.padding.normal + root.seam) / k.units;
            if (need > p)
                p = need;
        }
        return Math.ceil(p);
    }

    // What it actually gets: what it wants, or what the room allows, whichever
    // is less. Whole pixels, because a pixel font's stems belong on the pixel
    // grid and a fractional pitch would put every second key half a pixel off it.
    readonly property real pitch: Math.min(root.naturalPitch, Math.floor(root.width / root.totalUnits))

    // Below the minimum target the board stops being a thing you can press, and
    // the honest answer is to say so rather than to draw a keyboard nobody can
    // hit. See the note where this is used.
    readonly property bool fits: root.pitch >= Appearance.sizes.minTarget + root.seam

    readonly property real boardWidth: root.totalUnits * root.pitch
    readonly property real boardHeight: root.plan.length * root.pitch - root.seam

    // THE BINDS THE BOARD IS ALLOWED TO SPEAK FOR: the ones that fire from where
    // you are standing.
    //
    // A bind inside a submap does nothing whatsoever until you have entered that
    // mode, so lighting its key would be the very promise the lighting below
    // refuses to make about a chord you are not holding: latch SUPER, watch L
    // light up exactly as the thirty-eight real SUPER binds do, press SUPER and L
    // at the desktop, and nothing happens. Tapping it would be worse, because the
    // readout would then print a whole chord that does not work.
    //
    // THE BOARD HAS NOWHERE TO PUT THE DISTINCTION, which is why it is a filter
    // and not a shade. A cap is lit or it is dark, and a third state meaning "in
    // a mode" would be a colour nobody can read off a keyboard. The list has the
    // room and already does it right: it groups by submap as well as by mask (see
    // CheatSheet.sections) and prints the mode's name beside the family, so the
    // two views would otherwise disagree about the same bind.
    //
    // So the board reads the desktop's binds, and says underneath how many it
    // left out, rather than either lying about them or hiding them. There is no
    // submap on this machine today, which is exactly why it is written down now
    // rather than by whoever first watches a key light up for nothing.
    readonly property var deskRows: root.sheet.rows.filter(r => !r.submap)

    readonly property int inModes: root.sheet.rows.length - root.deskRows.length

    // EVERY KEY THAT IS BOUND UNDER THE MODIFIERS BEING HELD, counted once.
    //
    // An exact match on the mask, not a subset: with SUPER held, a bind on SUPER
    // and SHIFT is not reachable without also holding SHIFT, and lighting it
    // would be the board promising something the keyboard will not do. What
    // stops that being a dead end is that SHIFT ITSELF lights (see modOffers),
    // so the way on is visible from where you are.
    //
    // A map rather than a search per key, because it is read once per cap and
    // there are eighty-odd caps: one pass over the binds instead of eighty
    // passes.
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

    // WHETHER THERE IS ANYTHING DOWN THIS ROAD. It is what turns the board into
    // something you can explore rather than something you have to already know:
    // with SUPER held, SHIFT lights because SUPER plus SHIFT is a real family
    // here and ALT stays dark because nothing on this machine uses SUPER with
    // ALT, so the next move is on the screen instead of in your memory.
    //
    // A SUBSET TEST AND NOT AN EXACT ONE, which is the opposite of how the caps
    // themselves light and is the whole point of the distinction. A cap lights
    // when the chord you are holding WILL do something, because a lit key is a
    // promise about the very next press. A modifier lights when holding it leads
    // ANYWHERE, because pressing a modifier is not a press that does anything:
    // it is a step further into the tree, and the question it answers is whether
    // there is a tree that way at all.
    //
    // The exact test was tried first and it dead-ends. This machine has no bind
    // on CTRL alone, so with nothing held CTRL read as plainly unbound, and
    // CTRL plus SHIFT and CTRL plus ALT were both unreachable: the only route to
    // them was through a key the board had just said was empty.
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

    // DROP THE QUESTION, asked for by the sheet on every open.
    //
    // Both of the properties above are a question in progress rather than a
    // preference: which modifiers you are holding and which key you pointed at
    // are the two halves of one thing you were in the middle of asking. This item
    // is built once and lives as long as the shell, so without this they outlive
    // the open they were asked in, and the sheet comes back tomorrow with SUPER
    // and SHIFT lit, twenty-five keys lit under them and an answer in the readout
    // that belongs to nothing you did. It is the same argument the sheet makes
    // for zeroing its scroll in the same breath, and a stale chord is louder than
    // a stale scroll: it is coloured, it is in the accent, and there is nothing
    // on screen to say where it came from.
    //
    // A function here rather than the sheet assigning the two from outside, so
    // that what counts as the question stays this file's business and a third
    // piece of it added later is dropped by the call that already exists. The
    // vocabulary and the choice of view are NOT dropped: those are preferences,
    // they were chosen deliberately, and forgetting them every open is the thing
    // the sheet's own note says it will not do.
    function forget(): void {
        root.latched = 0;
        root.picked = null;
    }

    // Tapping the key you already asked about puts the question away, so the
    // readout can be cleared without reaching for anything else.
    function choose(cap: string, syms: var): void {
        root.picked = root.picked && root.picked.cap === cap ? null : {
            cap: cap,
            syms: syms
        };
    }

    // KEYS WITH BINDS THAT THE BOARD HAS NO CAP FOR, from the binds themselves.
    //
    // This is the other half of the schematic argument at the top: the board
    // refuses to draw hardware it cannot know is there, so anything bound to
    // that hardware would simply vanish. Here it is instead, in the same
    // vocabulary, pressable in the same way. On this machine it is the ten media
    // and brightness keys (which live on a laptop's function row behind Fn and
    // therefore have no cap of their own anywhere) and the two mouse buttons,
    // which are not on any keyboard at all.
    //
    // Ordered by the name that is drawn, so the row is the same on every open;
    // the binds arrive in the compositor's own order, which is the order they
    // were registered and not an order anybody can read.
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

    // WHAT THE ASKED-ABOUT KEY DOES, with what is being held taken into account.
    //
    // The filter is that the bind's modifiers CONTAIN the latched set, which is
    // deliberately looser than the exact match the lighting uses, and the two
    // answer different questions. The lighting answers "will this exact chord do
    // something", which has to be exact or it is a promise the keyboard breaks.
    // The readout answers "I am holding this and I am asking about that key",
    // and with nothing held that is the whole truth about the key, which is the
    // useful answer and never comes back empty on a key that plainly does
    // things. Exact matches sort first, so what you are actually holding is the
    // first line either way.
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

    // How many binds the held set reaches at all. The readout says it when
    // nothing has been asked about, because "SUPER, 38 binds" is the answer to
    // the question you asked by latching SUPER, and a panel that answered a
    // press with nothing at all would read as broken.
    readonly property int reach: {
        let n = 0;
        for (const row of root.deskRows)
            if (row.mask === root.latched)
                n++;
        return n;
    }

    // HOW MANY BINDS THE BUSIEST KEY CARRIES, which is how tall the readout has
    // to be. See the strip itself for why it is a fixed height at all; this is
    // where the height comes from.
    //
    // Measured off the data rather than picked, and the number it wants is
    // exactly this one: with nothing latched the readout lists every bind on the
    // key you tapped, and with something latched it lists a subset of them, so
    // the worst case over every key is the most any tap can produce. On this
    // machine that is four, because the arrow keys carry SUPER, SUPER with
    // SHIFT, SUPER with CTRL and all three.
    //
    // A fixed two rows was the first attempt and it cut the fourth line off the
    // arrow keys, on a strip with nothing to say that a fourth line existed. A
    // scroll bar would have been an admission that the strip was the wrong size;
    // a cap would be a number picked here and wrong on somebody's machine. If a
    // config really does put twenty binds on one key, the strip is twenty lines,
    // the card runs out of screen and the whole view scrolls, which is the same
    // thing the list has always done with a long config.
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

    // One line of body type in its own box, which is StyledText's fixed 4/3 line
    // box; the same expression Appearance uses to size the lock screen's field,
    // and for the same reason: the two must not be able to disagree about how
    // tall a line is.
    readonly property real lineBox: Math.round(Appearance.font.size.small * 4 / 3)

    implicitHeight: stack.implicitHeight

    Column {
        id: stack

        width: parent.width
        spacing: Appearance.padding.normal

        // THE BOARD CANNOT BE DRAWN AT A SIZE A FINGER CAN USE, said plainly.
        //
        // The alternative is a keyboard whose keys are twenty pixels across,
        // which looks like the feature works and is not usable by the input the
        // feature was built for. Both views read the same binds, so the list is
        // a complete answer and saying which way to go costs one line.
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
                // Centred in whatever room there is. At the card's own width
                // this is zero, because the card is measured off the board; it
                // is the screen that could not give the board its natural pitch
                // where the leftover would otherwise all pile up on the right.
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

                        // A modifier says itself in whichever vocabulary the
                        // sheet is speaking, so the board and the list agree
                        // about what SUPER looks like. Everything else has one
                        // legend: a symbol for Q would be Q.
                        //
                        // Empty means the word, which is not merely a guard: the
                        // three high masks have no glyph anywhere because there
                        // is nothing for one to be a picture of, and a modifier
                        // key wearing one of them would go blank in symbols mode
                        // rather than keeping the only name it has.
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

                        // A MODIFIER LATCHES AND DOES NOT GET ASKED ABOUT, which
                        // is the one branch on the board. Everything else is a
                        // question; a modifier is the thing you ask it under,
                        // and offering "what is SUPER bound to" as a separate
                        // answer would be offering the board's entire contents
                        // as a one-line readout.
                        onTapped: cap.modelData.mod ? root.toggleMod(cap.modelData.mod) : root.choose(cap.modelData.cap, cap.modelData.syms)
                    }
                }
            }
        }

        // THE KEYS THE BOARD WOULD NOT DRAW, when there are any. Kept visually
        // apart from the board by being a wrapping flow of caps rather than a
        // row of a keyboard, because they are not in a row on any hardware and
        // laying them out like one would be the lie the board is avoiding.
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

                        // Its own width, in units, from its own legend, so
                        // AUDIO RAISE VOLUME and MOUSE LEFT each get exactly
                        // the room they need out of the same pitch the board
                        // uses. Same formula as naturalPitch, read the other
                        // way round.
                        //
                        // Guarded against a pitch of zero, which is the state
                        // this whole item is in for the one frame before the
                        // card has a width to give it: bindings are evaluated
                        // whether or not the thing is visible, and a division by
                        // zero here would put an Infinity into a width and take
                        // the layout with it.
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

        // THE READOUT, and it is a strip of FIXED height under the board rather
        // than anything that appears on or beside a key.
        //
        // A popover on the key was the obvious idea and it is the wrong one: the
        // keys around the one you tapped are exactly what you are comparing it
        // against, and a bubble puts them behind itself. It would also need its
        // own way to be dismissed, on a panel that already has four.
        //
        // Sending the answer to the list view loses worse: the board IS the
        // question, and a view that switches away from itself to answer takes
        // the modifiers you had latched off the screen at the moment they became
        // the context for what you are reading.
        //
        // So it is always in the same place, which is the whole point: after two
        // taps your eye knows where the answer appears and stops hunting for it.
        // FIXED, and fixed is the load-bearing part. A strip that grew with the
        // number of lines would move the board every time you tapped a key, so
        // the second thing you wanted to press would not be where you last saw
        // it.
        //
        // As tall as the BUSIEST key needs, so nothing is ever cut off and
        // nothing ever moves; `busiest` above carries that argument and the two
        // attempts it replaces. The floor is two menu rows, because a row is
        // this shell's unit of one answer and a strip sized for a config where
        // every key carries exactly one bind would sit under the board with no
        // air at all.
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

                    // WHAT TO DO, when nothing has been asked yet, and what the
                    // held modifiers reach once something is. It is the only
                    // instruction anywhere in the sheet, and it earns its line:
                    // a keyboard drawn on a screen looks like a picture, and
                    // nothing about it says that the keys answer.
                    StyledText {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        visible: !root.picked

                        text: root.latched > 0 ? `${root.reach} binds under what you are holding: tap a key to read one` : "tap a modifier to hold it, tap a key to read it"
                        color: Appearance.colour.textFaint
                    }

                    // A key that does nothing, said as plainly as the dark cap
                    // already says it. Without this, tapping an unbound key
                    // would leave the last answer on screen and read as if that
                    // answer belonged to the key you just pressed.
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

                            // The chord in full, modifiers and all, even though
                            // the board is already showing which modifiers are
                            // held. Same argument as the list's rows: an answer
                            // has to be complete on its own, because the thing
                            // you do with it is go and press it, and by then you
                            // are looking at the keyboard rather than at this.
                            Chord {
                                id: says

                                parts: root.sheet.chordParts(hit.modelData.mask, hit.modelData.key)
                                advance: root.advance
                            }

                            StyledText {
                                x: says.implicitWidth + Appearance.padding.large
                                width: Math.max(0, hit.width - says.implicitWidth - Appearance.padding.large)
                                elide: Text.ElideRight

                                // A BIND WITH NO DESCRIPTION IS NOT LEFT BLANK
                                // HERE, unlike in the list, and that is the one
                                // place the two views deliberately differ. In
                                // the list a blank right-hand column reads as
                                // "this chord is taken and the compositor could
                                // not say what by", which is true and is
                                // legible because the chord next to it is the
                                // answer to the question the list was opened
                                // with. Here you have already pointed at the
                                // key, so the chord is not news: the whole
                                // content of the line is what it does, and a
                                // line that is empty is a key that lit up for
                                // no visible reason. The dispatcher and its
                                // argument are what the compositor has instead;
                                // on this machine that is `__lua` and a
                                // callback number, which says at least that the
                                // bind comes from the Lua config and that the
                                // sheet is not hiding anything. The header
                                // above says where a real description comes
                                // from.
                                text: hit.modelData.what || hit.modelData.raw
                                color: hit.modelData.what ? Appearance.colour.textDim : Appearance.colour.textGhost
                            }
                        }
                    }
                }
            }
        }

        // WHAT THE BOARD LEFT OUT, when the config has modes at all.
        //
        // Only when there is something to admit, like the header's own line
        // upstairs and for the same reason: the alternative is a key you know you
        // bound sitting dark with nothing to explain why, which reads as the
        // board being broken rather than as the board being careful. It names
        // where they went, because a complaint you cannot act on is just a
        // complaint, and the list next door is one tap away in the header.
        StyledText {
            width: parent.width
            wrapMode: Text.WordWrap
            visible: root.inModes > 0

            text: `${root.inModes} binds live inside a submap and only fire once you are in it, so they are not on the board: the list has them, under the mode's own name`
            color: Appearance.colour.textGhost
        }

        // WHERE THE LEGENDS CAME FROM, quietly, because every cap above is a
        // claim about a keymap this shell does not own. If the layout is not the
        // one you are typing on, this is the line that says so, and it is the
        // compositor's own words rather than the sheet's.
        StyledText {
            width: parent.width
            wrapMode: Text.WordWrap

            text: root.sheet.keymap ? (root.sheet.kbOptions ? `${root.sheet.keymap}, ISO, ${root.sheet.kbOptions}` : `${root.sheet.keymap}, ISO`) : "ISO"
            color: Appearance.colour.textGhost
        }
    }
}
