pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.services

// THE HOTKEY SHEET: what this keyboard actually does, asked of the compositor.
//
// Every other panel in this shell is drawn from the shell's own state, so it can
// only ever be right. This one is drawn from the USER'S CONFIG, which the shell
// does not own and cannot see, so the one thing it must never do is recite a
// list somebody typed in here once. A hardcoded sheet is wrong the first time a
// bind moves and, worse, it is wrong SILENTLY: it goes on confidently naming a
// key that does something else now. So the contents come from `hyprctl binds -j`
// and nowhere else, re-read on every open, because binds change whenever the
// user edits their config and the sheet is precisely the thing you open when you
// have forgotten what you changed.
//
// IT IS TWO VIEWS OF ONE SET OF BINDS, and they are two because they answer two
// different questions. BindList answers "what is on SUPER", which is the
// question you have when you are editing your config or trying to remember what
// you bound last week, and it answers it completely: every bind, grouped by how
// it is pressed, in one scroll. KeyBoard answers "what is on THIS KEY", which is
// the question you have with your hands on the keyboard, and the list cannot
// answer it at all without being read end to end. Neither is a nicer skin on the
// other, so the switch between them is a control in the header rather than a
// setting somewhere, and what you last chose is still chosen the next time you
// open it.
//
// It is modelled on modules/session/SessionMenu.qml, which is the shell's other
// summoned-by-name panel, and it inherits that panel's whole lifecycle argument:
// there is NO hover anywhere in here. A thing you reached for with the cursor
// can be closed by the cursor leaving, because leaving is the only thing that
// could have meant "done". This arrives from a keybind, from wherever you were,
// with the pointer resting on something entirely unrelated; there is no edge to
// leave and nothing for hover to say. So it is open until something says
// otherwise, and the four things that can say so are the catcher underneath it,
// Escape, the CLI, and a push up into the top edge.
//
// IT IS NOT A BLOB, unlike the power panel it is otherwise modelled on, and that
// is deliberate rather than an omission. The chassis field is for things that
// GROW OUT of the shell's body, where the fillet between the two says "these are
// connected" (DESIGN.md 14). This grows out of nothing: it is a document you
// summoned to read, it is centred in the content area rather than touching any
// band, and a melt that reached across that distance would be claiming a
// connection that is not there. Melting it in would also spend one of the
// field's twelve slots, and ten sources of panel are already spoken for.
Item {
    id: root

    // ONE BOOLEAN, and it is the state itself rather than a union of claims.
    //
    // The notification tray and the notch both derive presence from several
    // inputs, because hover, a pull and a pin can each hold those open and they
    // have to agree. Nothing holds this open but the asking: there is no hover
    // route in, no gesture that summons it, and no second opener anywhere. A
    // union of one term is just the term.
    property bool open: false

    // WHICH VIEW, and HOW A CHORD IS SPELLED. Two preferences rather than one,
    // because they are genuinely independent: the words-or-symbols choice is
    // about how a modifier is named and both views name modifiers.
    //
    // HELD HERE, which is what makes them last. This item lives for the whole
    // session, so a choice made once survives every open and close after it;
    // that is the floor the feature was asked for. Surviving a RESTART would
    // need a key in config.json, and the sheet cannot give itself one: the
    // schema is the defaults block in config/Config.qml and adding to it is the
    // integrator's job. It is written up as a contract rather than done here.
    property bool board: false
    property bool symbols: false

    // WHERE EACH VIEW WAS LEFT, because one Flickable holds both of them and its
    // contentY can only ever be the place the view on screen is at. The other
    // view's place has to be kept somewhere, and it is kept here, beside the
    // choice of view, because it is the same piece of state: which of the two
    // you are reading and how far into it you had got.
    property real listY: 0
    property real boardY: 0

    // The WHOLE screen while it is up, so a tap anywhere off the sheet puts it
    // away. Same shape, and the same argument, as the power panel's catcher: a
    // panel summoned by name has nothing else to dismiss it.
    readonly property Item maskItem: catcher

    // The window that had the keyboard before this took it, so it can have it
    // back. A sheet you opened to look something up and then had to click back
    // into your editor from would cost more than it told you.
    //
    // THE EDITOR ON THIS SCREEN, which is what `Hypr.focusedOn` is for. The
    // shell-wide answer sent the keyboard to whichever monitor happened to hold
    // it when the sheet went up, and a sheet is the panel you are most likely to
    // open on the screen you are NOT working in: you look a bind up on one
    // monitor in order to press it in the other. See services/Hypr.qml's
    // `focusedByMonitor`.
    property string restoreTo: ""

    // WHICH SCREEN THIS SHEET IS DRAWN ON, for the line above. Asked of the
    // window, per modules/SettingsCorner.qml and modules/sidebar/Sidebar.qml,
    // rather than threaded down through ShellWindow: the screen is a fact about
    // the surface, not about the document on it.
    readonly property string screenName: QsWindow.window?.screen?.name ?? ""

    // WHAT THE COMPOSITOR SAID, parsed into the only things a row needs: which
    // modifiers, which submap, which key, and what it does. Kept between opens,
    // so the second open draws a full sheet on the frame it is asked for rather
    // than growing into one as hyprctl answers.
    property var rows: []

    // WHAT THE COMPOSITOR SAID ABOUT THE KEYBOARD ITSELF, which the board needs
    // and the list does not: the active keymap's own name, the layout list, and
    // the xkb options, because two of the options on this machine change what a
    // key does (see KeyBoard.optionKeys). Read from `hyprctl devices -j` rather
    // than from `getoption input:kb_layout`, which answers with the CONFIGURED
    // list and not with which of them is live: this machine is set to `us,dk`
    // and is typing in the first of the two, and a board captioned "us,dk" would
    // be naming a layout whose legends it is not drawing.
    property string keymap: ""
    property string kbLayout: ""
    property string kbOptions: ""

    // A REAL ENTRY from `hyprctl binds -j` on this machine, so the parsing below
    // can be read against the data rather than against a memory of the schema:
    //
    //   {
    //     "locked": false, "mouse": false, "release": false, "repeat": false,
    //     "longPress": false, "non_consuming": false, "auto_consuming": false,
    //     "has_description": true, "modmask": 64, "submap": "",
    //     "submap_universal": "false", "key": "Slash", "keycode": 0,
    //     "catch_all": false, "description": "Toggle cheatsheet",
    //     "allow_input_capture": false, "dispatcher": "__lua", "arg": "145"
    //   }
    //
    // `modmask` is the xkb modifier bitfield, and the masks this machine
    // actually produced are 0, 5, 12, 64, 65, 68 and 69: 64 alone is SUPER, 65
    // is SUPER with SHIFT's bit 1, 68 is SUPER with CTRL's bit 4, 69 is all
    // three, 12 is CTRL plus ALT's bit 8, and 5 is CTRL plus SHIFT. Every one of
    // those decomposes against the table below, which is how it was checked.
    //
    // The order here is the order a chord is WRITTEN, not the order the bits
    // fall in. Sorting by bit value would print "ALT + CTRL" for mask 12, and
    // every keyboard, manual and configuration file on earth writes that pair
    // the other way round. It is a vocabulary rather than a set of slots, so
    // this is a list to read in order, not a position to hardcode.
    //
    // AND THE SYMBOL IS PART OF THE VOCABULARY, on the same row as the word,
    // because they are two spellings of one thing and keeping them in two lists
    // is how they come to disagree. Each one was FOUND on this machine rather
    // than assumed, which mattered more than it sounds: the obvious answers, the
    // plain Unicode U+21E7 for shift and U+2303 for control, are in NEITHER of
    // the faces this shell loads, so a sheet built on them would have drawn a
    // row of empty boxes, which is worse than the word it replaced. What is in
    // the symbol face (`fc-match "Symbols Nerd Font"` gives
    // SymbolsNerdFont-Regular.ttf here) is the Material Design keyboard set,
    // whose glyphs are the same shapes: U+F0636 is the shift arrow, U+F0634 the
    // control caret, U+F0635 the option knot and U+F0632 the caps arrow. Super
    // is the one the user named, and it is U+F31A, the Linux logo set's own Tux,
    // chosen over Font Awesome's U+F17C because it is a hair wider and reads as
    // a penguin rather than as a blob a pixel or two sooner.
    //
    // The three masks with no symbol keep the word. There is no glyph for "mod
    // 3" in any set because there is nothing for one to be a picture OF, and a
    // sheet that fell back to a placeholder would be showing you a mark you
    // could not look up.
    readonly property var modBits: [
        {
            bit: 64,
            name: "SUPER",
            symbol: String.fromCodePoint(0xF31A)
        },
        {
            bit: 4,
            name: "CTRL",
            symbol: String.fromCodePoint(0xF0634)
        },
        {
            bit: 8,
            name: "ALT",
            symbol: String.fromCodePoint(0xF0635)
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

    // Mouse buttons arrive as `mouse:272`, which is evdev's BTN_LEFT from
    // linux/input-event-codes.h and not a number anybody is expected to read.
    // The buttons are CONSECUTIVE from there, so this is one subtraction and a
    // list rather than a table of codes: BTN_LEFT, BTN_RIGHT, BTN_MIDDLE,
    // BTN_SIDE, BTN_EXTRA, BTN_FORWARD, BTN_BACK, BTN_TASK. A code past the end
    // falls back to the compositor's own spelling, which is at least honest.
    readonly property int mouseBase: 272
    readonly property var mouseNames: ["LEFT", "RIGHT", "MIDDLE", "SIDE", "EXTRA", "FORWARD", "BACK", "TASK"]

    // The modifiers in a mask, named, in writing order.
    function modNames(mask: int): var {
        return root.modBits.filter(m => (mask & m.bit) !== 0).map(m => m.name);
    }

    // The symbol face's mark for one modifier bit, or "" if that bit has none.
    function modSymbol(bit: int): string {
        for (const m of root.modBits)
            if (m.bit === bit)
                return m.symbol;
        return "";
    }

    // A key as it should be read rather than as the compositor stores it.
    //
    // Two normalisations, both computed from the string rather than enumerated,
    // because the set of keys a keyboard can carry is not a list this file gets
    // to know: a mouse button becomes its evdev name, and an XF86 media key
    // loses the vendor prefix and gets its camel case broken into words, so
    // `XF86AudioRaiseVolume` reads as AUDIO RAISE VOLUME instead of as one
    // twenty-character shout. Everything else is upper-cased and otherwise left
    // exactly as Hyprland spells it, which is deliberate: the sheet's whole job
    // is to tell you what to press, and what you would TYPE into the config to
    // change it is the same string.
    function keyName(key: string): string {
        if (key.startsWith("mouse:")) {
            const named = root.mouseNames[parseInt(key.slice(6), 10) - root.mouseBase];
            return named ? `MOUSE ${named}` : key.toUpperCase();
        }
        const bare = key.startsWith("XF86") ? key.slice(4).replace(/([a-z0-9])([A-Z])/g, "$1 $2") : key;
        return bare.toUpperCase();
    }

    // WHICH KEY A BIND IS ON, out of the three mutually exclusive ways Hyprland
    // has of holding one. `SKeybind` carries `key`, `keycode` and `catchAll`
    // side by side and fills in exactly one of them, which is why reading `key`
    // alone was not merely incomplete but wrong on screen: a bind written
    // `code:36` answers with `key` empty, and the chord came out as `SUPER + `
    // with a plus hanging off the end, or, on a bind with no modifier at all, as
    // a row blank in both columns that still took a line of the sheet. `code:`
    // is not an exotic spelling either: it is the LAYOUT-INDEPENDENT one, what
    // you reach for when a keysym name means a different physical key on
    // somebody else's keyboard, which is the trap the longest note in
    // docs/hyprland-binds.example.conf is about. The sheet was blind to exactly
    // the binds a config written to survive a layout change is likeliest to
    // hold.
    //
    // THE NAMED KEY WINS when there is one, because a name is the thing you can
    // actually press, and it is what the compositor gives back whenever it has
    // one to give. The other two are spelled the way a config spells them and
    // handed to keyName unchanged, which upper-cases them into the sheet's own
    // voice for free. That is deliberate rather than lazy for the keycode: a
    // keycode has no name BY CONSTRUCTION, since `code:` is what you write
    // precisely because the layout decides minute to minute what the key is
    // called, so the number is its whole identity and `code:36` is both what the
    // compositor means and the string you would search your own config for.
    //
    // A `code:` bind therefore has no cap on the drawn board either, and lands
    // in KeyBoard's off-board row instead. Mapping the number back to a physical
    // key would mean carrying the evdev-to-X11 offset and a keycode per cap, and
    // the whole reason somebody wrote `code:` is that they did not trust a name
    // to mean the same key twice.
    function keyOf(bind: var): string {
        const named = (bind.key ?? "").trim();
        if (named)
            return named;
        // The catch-all is the one of the three with an honest English name: it
        // fires on ANY key, which is the whole of what a submap's escape hatch
        // does, and printing the config's own `catchall` would be jargon saying
        // the same thing worse to somebody who has forgotten what they bound.
        if (bind.catch_all === true)
            return "any key";
        const code = bind.keycode ?? 0;
        return code > 0 ? `code:${code}` : "";
    }

    // HOW WIDE ONE CHARACTER OF THE SHELL'S FACE IS.
    //
    // Every width in this file is a multiple of it, which is exact rather than
    // approximate: Monocraft is monospaced, so a string's width is its length
    // times this and there is nothing to round. Measured, not taken from the
    // font's 2/3 ratio, so a change of face cannot leave every chord column in
    // the sheet half a character out with nothing to notice it.
    //
    // Rounded UP. TextMetrics measures the font's own advance and StyledText
    // renders natively, which puts stems back on the pixel grid, so a drawn
    // string can come out a fraction wider than the measured one. A column short
    // by half a pixel would clip the one row it was sized for.
    readonly property real advance: Math.ceil(em.advanceWidth)

    // HOW MANY CHARACTER CELLS A SYMBOL TAKES, and it is derived rather than
    // picked. A modifier symbol is drawn at the body size so that it sits ON the
    // line of type rather than beside it, and the body size is wider than one
    // character advance, so it needs as many cells as it is advances tall. At
    // the shell's current tokens that is 18 over 12, which is two; at any other
    // pair it is whatever the division says.
    readonly property int symbolCells: Math.ceil(Appearance.font.size.small / root.advance)

    // A CHORD, BROKEN INTO PIECES, each with its width in character cells.
    //
    // The pieces exist because a chord in symbols mode is written in two faces
    // at once and one Text has one family; Chord.qml carries that argument in
    // full. The cells exist because the list's two columns have to be measured
    // before a single row is laid out, and a laid-out Row cannot be measured
    // until it is.
    //
    // THE JOINER STAYS " + " IN BOTH VOCABULARIES. Apple writes its chords as
    // symbols run together, and that only reads because everyone already knows
    // where one modifier ends and the next begins; this sheet exists for the
    // case where you do not know that. The toggle was asked for as a choice
    // about how the modifiers are SPELLED, so the grammar around them is the one
    // thing it deliberately leaves alone: one chord shape, two vocabularies.
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
            const sym = root.symbols ? m.symbol : "";
            out.push({
                text: sym ? "" : m.name,
                glyph: sym,
                cells: sym ? root.symbolCells : m.name.length
            });
        }

        // The key is APPENDED RATHER THAN ASSUMED, so a bind the compositor
        // described with none of its three key fields prints its modifiers alone
        // instead of trailing a plus sign into nothing. Hyprland cannot produce
        // one today, since every bind it parses sets exactly one of the three,
        // so this is a guard against an answer nobody has seen rather than a
        // case in hand; inventing a placeholder key for it was the alternative,
        // and it would be the sheet claiming to know something it was never
        // told. It is also what lets a section heading ask for the same chord
        // with the key left off.
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

    function chordCells(mask: int, key: string): int {
        let n = 0;
        for (const p of root.chordParts(mask, key))
            n += p.cells;
        return n;
    }

    // `exec, banditshell launcher toggle` is this shell talking to itself, and
    // printing the whole command line for it would be like a menu labelling its
    // own entries with their function names. The program name is stripped and
    // the verbs are left, so a row reads `launcher toggle`, which is both what
    // the bind does and what you would type in a terminal to do it by hand.
    //
    // Found by BASENAME rather than by a prefix match on the command, because a
    // bind may name the script by path or reach it through `env`, and all three
    // spellings are the same program. Nothing else is rewritten: a translation
    // table per verb would be a second vocabulary to keep in step with bin/
    // banditshell, wrong the first time a verb was added, and the verbs already
    // read as English.
    function humaniseExec(cmd: string): string {
        const words = cmd.split(/\s+/).filter(w => w);
        const at = words.findIndex(w => w.split("/").pop() === "banditshell");
        if (at < 0)
            return cmd;
        const verbs = words.slice(at + 1);
        return verbs.length > 0 ? verbs.join(" ") : cmd;
    }

    // WHAT A BIND DOES, in as many words as the compositor is willing to give.
    function describe(bind: var): string {
        // The description wins outright, because it is the only thing here the
        // user actually WROTE about the bind. Hyprland's `bindd` carries one,
        // and a Lua config can pass one; everything below this line is the
        // sheet guessing from the machinery instead.
        const said = (bind.description ?? "").trim();
        if (said)
            return said;

        const dispatcher = (bind.dispatcher ?? "").trim();
        const arg = (bind.arg ?? "").trim();

        // A BIND REGISTERED FROM LUA OR A PLUGIN SAYS NOTHING, and this machine
        // is entirely made of them: `hyprctl binds -j` reports every one of its
        // eighty-two binds with `"dispatcher": "__lua"` and an `arg` that is the
        // callback's registration number. The number is a handle into the
        // plugin's own table and means nothing outside it, so printing `__lua
        // 37` would fill the sheet with noise that LOOKS like information.
        //
        // An empty string instead, and the header counts them and says why. A
        // row with a chord and nothing beside it reads as "this key is taken and
        // the compositor cannot tell you what by", which is the truth; `__lua
        // 37` reads as an answer.
        if (dispatcher === "__lua")
            return "";

        if (dispatcher === "exec")
            return root.humaniseExec(arg);

        // Everything else, as the compositor names it. A dispatcher is already a
        // verb (`killactive`, `workspace`, `movetoworkspacesilent`) and its
        // argument is already the thing it acts on, so the pair reads well
        // enough on its own, and a translation table would only be a list of
        // Hyprland's dispatchers to fall behind.
        return arg ? `${dispatcher} ${arg}` : dispatcher;
    }

    // THE MACHINERY, verbatim, for the one reader who has already pointed at a
    // key and is owed something rather than a blank line.
    //
    // The list never shows this, on purpose: a screen of `__lua 37` is noise
    // dressed as information, which is exactly what `describe` refuses to
    // produce. The board's readout is a different situation. You have tapped one
    // key, the chord is not news because you just pressed it, and the entire
    // content of the line is what the bind does; empty there is a key that lit
    // up for no visible reason. `__lua 37` at least says the bind comes from the
    // Lua config, which is where you would go to give it a description.
    function machinery(bind: var): string {
        const dispatcher = (bind.dispatcher ?? "").trim();
        const arg = (bind.arg ?? "").trim();
        return arg ? `${dispatcher} ${arg}` : dispatcher;
    }

    function parse(text: string): var {
        let raw = [];
        try {
            raw = JSON.parse(text);
        } catch (e) {
            console.warn(`CheatSheet: hyprctl binds did not answer with JSON: ${e}`);
            return [];
        }
        if (!Array.isArray(raw))
            return [];

        return raw.map(b => {
            const mask = b.modmask ?? 0;
            return {
                mask: mask,
                mods: root.modNames(mask).length,
                submap: b.submap ?? "",
                // THE KEY AS THE COMPOSITOR SPELLS IT, kept rather than folded
                // into a chord string at parse time. Two things need it raw: the
                // board matches it against its caps, and the chord is rebuilt
                // whenever the vocabulary changes. A chord baked in here would
                // be frozen at whichever spelling was current when hyprctl
                // answered, and the symbols toggle would do nothing to the rows
                // already on screen.
                key: root.keyOf(b),
                what: root.describe(b),
                raw: root.machinery(b)
            };
        });
    }

    // WHICH KEYBOARD IS TYPING, out of everything the compositor calls one.
    //
    // `hyprctl devices -j` lists the lid switch, the power button and the video
    // bus alongside the actual keyboard, and they all carry a layout because
    // Hyprland configures them all the same way. `main` is the compositor's own
    // answer to which one is authoritative; the first with a keymap is the
    // fallback for a session where nothing is flagged, and it is better than
    // nothing because on a machine with one keyboard configuration every entry
    // agrees anyway.
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

    // THE SHEET, grouped and ordered, built entirely from the rows.
    //
    // The group is the modifier set AND the submap, because those are the two
    // things that decide whether two binds are pressed the same way. Submaps are
    // the easy half to forget: a bind inside one only fires while that submap is
    // active, so listing it beside the ordinary binds would be a lie about a key
    // that does nothing until you have entered a mode. There is no submap on
    // this machine today, which is exactly why it has to be in the key rather
    // than added later by whoever first notices the sheet lying.
    //
    // THE ORDER IS THE FAMILY'S SIZE, largest first. A cheatsheet is read to
    // find a key you half remember, and the family you have bound most is the
    // one you are most likely to be hunting in; on this machine that puts the
    // thirty-eight SUPER binds at the top and the single CTRL + ALT one at the
    // bottom, which is the order you would look in. The two tiebreaks exist so
    // that two families of the same size cannot swap places between openings:
    // fewer modifiers first, then the mask itself, which is a total order.
    readonly property var sections: {
        const byKey = {};
        const out = [];

        for (const row of root.rows) {
            // The separator cannot be a character either half might contain. A
            // submap is a user-chosen name and a mask is a number, so a unit
            // separator between them is the one join that cannot collide.
            const key = `${row.submap}${row.mask}`;
            let group = byKey[key];
            if (!group) {
                group = {
                    mask: row.mask,
                    mods: row.mods,
                    submap: row.submap,
                    rows: []
                };
                byKey[key] = group;
                out.push(group);
            }
            group.rows.push(row);
        }

        out.sort((a, b) => b.rows.length - a.rows.length || a.mods - b.mods || a.mask - b.mask);
        return out;
    }

    // How many binds came back saying only which key. Counted rather than
    // guessed at, because the note it drives is a claim about this machine and
    // it would be worse than useless if it were off by one.
    readonly property int unnamed: root.rows.filter(r => !r.what).length

    // THE ROOM THE SHEET HAS: the content area, which is the screen less the
    // chassis band and the sidebar.
    //
    // Derived from the same tokens Chassis derives its own hole from rather than
    // being handed the hole, so this panel needs nothing wired to it but
    // `anchors.fill` and the integrator's line stays one line. The two can only
    // drift if Chassis changes its formula, and if it ever does, the honest fix
    // is to pass the rect in.
    //
    // It is centred in the CONTENT AREA and not on the screen, for the settings
    // page's reason: the sidebar makes those two different, and a sheet centred
    // on the second sits visibly right of the space it is actually in.
    //
    // AND IT STANDS OFF THE CHASSIS BY A GAP, which is the correction to the
    // paragraph above rather than an ornament on it. The room used to BE the
    // hole exactly, and for every sheet short enough to fit that was invisible:
    // the card is centred, and the centre of a rectangle does not move when you
    // inset both of its ends by the same amount. It showed up in the one case
    // the clamp bites. Eighty-three binds on a 1200-line screen took the card to
    // the full height of the hole, so it stood wedged between the top band and
    // the bottom one with its corners touching both, which is exactly what the
    // note at the top of this file says this panel is not: a document floating
    // clear of every band, connected to nothing, which is the whole reason it is
    // not a blob. Measured on a full-height capture: the card's bottom edge
    // landed on the band's top edge with nothing between them, and the last row
    // of binds, cut where the viewport cuts it, sat a padding tier above that
    // seam with no air anywhere below it.
    //
    // `sizes.gap` and not a padding tier, because this distance is not padding.
    // It is the space between a thing in the hole and the chassis around it,
    // which is the distance the compositor already keeps every window at; a
    // panel that borrowed a text tier for it would drift away from the windows
    // it sits among the first time the padding scale moved.
    //
    // WHAT IT DOES NOT DO is stop the viewport cutting a row through the middle
    // of its glyphs, and nothing here can: a document taller than its viewport
    // is cut wherever the viewport ends, and the row that gets cut changes with
    // every notch of the wheel. Clamping the card to a whole number of rows was
    // rejected for exactly that reason, since it would be right for the resting
    // view and wrong again one scroll later, and fading the last rows out under
    // a mask was rejected as a full-height render pass per frame for a document
    // that can be the whole screen. What this buys is the air: the cut now has a
    // padding tier and then a gap under it instead of a padding tier and then
    // the chassis.
    readonly property real areaX: Appearance.sizes.band + Appearance.sizes.gap + Appearance.sizes.sidebarWidth
    readonly property real areaY: Appearance.sizes.band + Appearance.sizes.gap
    readonly property real areaWidth: root.width - root.areaX - Appearance.sizes.band - Appearance.sizes.gap
    readonly property real areaHeight: root.height - (Appearance.sizes.band + Appearance.sizes.gap) * 2

    // The gap between the chord and what it does. A padding tier rather than a
    // measured column gap: it is the space between two columns of type, which is
    // exactly what the padding scale is for.
    readonly property real gutter: Appearance.padding.large

    // The chord column, measured off the WIDEST chord there is rather than off
    // the one being drawn, so the descriptions all start on the same x and the
    // sheet reads as two columns instead of as ragged pairs. Measured off the
    // data, so a machine with no chord longer than SUPER + A gets a narrow
    // column and one with SUPER + CTRL + SHIFT + RIGHT gets a wide one, and
    // neither number is written down anywhere.
    //
    // IN CELLS AND NOT IN PIXELS, which is what lets it survive the symbols
    // toggle. A chord drawn in symbols is a row of items in two faces and cannot
    // be measured by a TextMetrics at all; every one of those items is given a
    // width in character cells by chordParts, so the column is the largest of
    // those sums times one advance and is exact in both vocabularies. It moves
    // when the vocabulary does, which is right: symbols are a third of the width
    // of the words, and holding the column at the wider figure would leave a
    // hand's breadth of nothing down the middle of the sheet.
    readonly property real chordWidth: {
        let n = 0;
        for (const row of root.rows) {
            const c = root.chordCells(row.mask, row.key);
            if (c > n)
                n = c;
        }
        return n * root.advance;
    }

    readonly property real contentWidth: root.chordWidth + root.gutter + Math.ceil(whatInk.width)

    // WHAT THE CARD WANTS TO BE, which is a different question in each view.
    //
    // In the list it is the two columns of type, exactly as it always was. In
    // the board it is the KEYBOARD's natural width, which the board works out
    // from its own legends and which nothing here has an opinion about; the card
    // is the thing that wraps around it rather than the thing that decides how
    // big a key is. Reading `keys.naturalPitch` from here is safe and not a
    // cycle: that number is measured off the layout data and the type, and the
    // board only consults its own width afterwards to find out whether it may
    // have what it asked for.
    //
    // The header has a floor of its own, because a title and two controls in a
    // row is a real width and the list on a machine with no descriptions is
    // narrower than it. Without it the controls would be the first thing in the
    // sheet to be cut off, which is the one thing that has to stay reachable.
    readonly property real headWidth: title.implicitWidth + Appearance.padding.large + controls.implicitWidth

    readonly property real wantWidth: Math.min(root.areaWidth, Math.max(Appearance.sizes.menuWidth, root.headWidth, root.board ? keyboard.naturalPitch * keyboard.totalUnits : root.contentWidth) + Appearance.padding.large * 2)

    // As tall as it needs and no taller: a sheet of six binds is a card, and one
    // of eighty-two is a full-height document that scrolls. Read off the laid-out
    // view rather than computed from a row count times a row height, because the
    // second is a copy of the layout's arithmetic that goes wrong the first time
    // a heading changes size.
    readonly property real wantHeight: Math.min(root.areaHeight, head.implicitHeight + Appearance.padding.normal + (root.board ? keyboard.implicitHeight : list.implicitHeight) + Appearance.padding.large * 2)

    // AND THE CARD FOLLOWS BOTH, which the height used to do without.
    //
    // The old note said not to smooth it, and it was right about the case it was
    // written for: the one jump was from header-high to whatever the binds
    // wanted, on the frame hyprctl answered, a few milliseconds into a reveal
    // while the card was still mostly above the top edge and nearly transparent.
    // A smoother there was a moving part earning nothing.
    //
    // A second view changed that. Switching between a list and a keyboard is a
    // change of both dimensions at once, in the middle of the screen, at full
    // opacity, with somebody looking straight at it, and jumping reads as two
    // different panels rather than as one panel turning around. `resizeSpeed` is
    // the token for precisely this: a panel taking the size of content that
    // changed under it, at the same rate things track, so an object that slides
    // and resizes at once still reads as one object.
    //
    // Snapped on the way in, so the first open is still placed rather than flown
    // to: a Follow starts at zero, and without the snap the card would unfold
    // from nothing every single time.
    //
    // AND GOES ON SNAPPING FOR AS LONG AS IT IS STILL ARRIVING, which the one
    // snap in `show` cannot manage on its own. `show` calls `reload` and snaps in
    // the same breath, but reload only STARTS an hyprctl, so on the first open of
    // a session it snaps to the size of an EMPTY sheet: a header and the one line
    // saying nothing came back, which is 594 by 144 here. The binds land about
    // seven milliseconds later, the targets jump to 684 by 1180, and at
    // `resizeSpeed` the card then spends a third of a second unfolding in the
    // middle of the screen while the reveal, which is done in a quarter, hands it
    // full opacity halfway through. That is precisely the motion the smoothing
    // was added to prevent between views, played on the one open that should be
    // the calmest.
    //
    // Taking the size outright on every target change while the card is still on
    // its way in puts that growth back where the old note said it belonged: one
    // jump, at a quarter opacity, with the card still mostly above the top edge.
    // Once it has arrived, a change of size is a view switch and is smoothed,
    // which is the case `resizeSpeed` exists for. The two are told apart by the
    // card's own presence rather than by a flag anybody has to remember to set.
    readonly property real cardWidth: wide.value
    readonly property real cardHeight: tall.value

    // ALL THE WAY OUT AND STANDING STILL. `settled` is an exact test rather than
    // a near one (see Follow), so this is false for every frame of the reveal and
    // true for the whole time the sheet is simply up, including while a push has
    // hold of it: a push moves the card without resizing it, and a view switched
    // mid-push cannot happen, since the header's controls cannot be pressed by
    // the hand that is already dragging.
    readonly property bool arrived: root.open && reveal.settled

    readonly property real restY: root.areaY + (root.areaHeight - root.cardHeight) / 2

    // HOW FAR OUT IT IS, whoever is deciding. While a push is running that is the
    // hand; the rest of the time it is the reveal. One number downstream, so the
    // card's offset and its opacity do not each have to know which of the two is
    // driving. This is the settings page's arrangement, and TopNotch's, for the
    // reason written there: a reveal that only moved after the gesture ended
    // would show nothing at all for the whole push.
    readonly property real presence: root.pushing ? root.pushOut : reveal.value

    property bool pushing: false
    property real pushOut: 0

    // Off the TOP, all the way off: at presence 0 the card's own bottom edge is
    // exactly on the surface's top, so a closed sheet is gone rather than a
    // sliver resting on the band. That is also the distance the push has to
    // cover, which is why it is written once here and read by both.
    readonly property real lift: (root.restY + root.cardHeight) * (1 - root.presence)

    // THE SCROLL CHANGING HANDS, which is what a switch of view also is.
    //
    // One Flickable holds both views, so its contentHeight is whichever one is
    // showing and the instant `board` flips Qt has a new content height under an
    // old contentY and fixes it up on the spot. Switch to the shorter view and
    // the place you were reading is clamped away; switch back and you are at the
    // top. On this machine the board is a card's worth of keys and the list is
    // twice the height of the screen, so a round trip to check one against the
    // other costs the whole scroll every single time, which is precisely the
    // state the Flickable's own note says keeping both views alive was for.
    //
    // PARKED WHEN A SCROLL ENDS, and not when the view changes, which is the
    // difference between a fix and a fix for one route. `board` is written from
    // three places: the header's control, the config file (ShellWindow persists
    // the choice and hands it back), and the same file arriving from another
    // monitor's sheet. Only the first of those goes through anything this file
    // could hook, so a save that hung off the pick would be right for a tap and
    // wrong for a `banditshell config set`. A movement that has ended is also
    // the one moment the number is worth keeping: it is where the hand left the
    // document, settled, rather than a value in the middle of a flick. The clamp
    // that follows a flip is not a movement and cannot be mistaken for one.
    function park(): void {
        if (root.board)
            root.boardY = view.contentY;
        else
            root.listY = view.contentY;
    }

    // HANDED BACK AFTER THE FLIP HAS LANDED, which is why it is deferred rather
    // than assigned in the handler. The content height and this handler are both
    // hanging off the same change of `board` and QML does not say which of them
    // runs first; assigned straight away, the restore would be clamped by the
    // OUTGOING view's height half the time, which is the bug it is here to
    // undo. Qt.callLater runs once everything hanging off that change has been
    // processed, so by then the Flickable is measured for the view it is
    // actually showing.
    function restoreScroll(): void {
        view.contentY = root.board ? root.boardY : root.listY;
    }

    onBoardChanged: Qt.callLater(root.restoreScroll)

    function show(): void {
        if (root.open)
            return;
        root.restoreTo = Hypr.focusedOn(root.screenName);
        // RE-READ EVERY TIME. The sheet is what you open after changing your
        // binds, so a cached list is wrong at exactly the moment it is consulted.
        root.reload();
        // Back to the top, because the sheet you scrolled halfway through
        // yesterday is not where the next question starts. BOTH views, not just
        // the one showing: a parked scroll is the same stale answer, one switch
        // later.
        view.contentY = 0;
        root.listY = 0;
        root.boardY = 0;
        // And nothing held and nothing asked, for the very same reason. A
        // latched chord is a question in progress: reopening with SUPER and
        // SHIFT still lit, twenty-five keys lit under them and yesterday's
        // answer still in the readout would be the sheet putting a question in
        // your mouth, and there is nothing on the screen to say that state came
        // from the last time you looked. The board owns those two, so the board
        // is asked to drop them rather than being reached into from here.
        keyboard.forget();
        wide.snap();
        tall.snap();
        root.open = true;
        // DEFERRED: the surface only asks the compositor for the keyboard once
        // `open` has propagated, and forcing focus before that happens gets a
        // focused item that receives nothing. See ShellWindow's keyboardFocus,
        // and SessionMenu, which learned this first.
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

    // Guarded rather than assigned, because `running = true` on a Process that
    // is already running is a request to start a second one. Two opens a frame
    // apart is not a thing to spawn two hyprctls for, and the one in flight is
    // reading the same config anyway.
    function reload(): void {
        if (!query.running)
            query.running = true;
        // The keyboard is asked about on the same schedule and for the same
        // reason: a layout can be changed in hyprland.conf between two opens of
        // this sheet, and a board captioned with the old one would be labelling
        // its caps with symbols the keyboard no longer sends.
        if (!devices.running)
            devices.running = true;
    }

    // How far out the push has left it, as a fraction, from a gesture that
    // reports how far it has pushed the sheet AWAY. The one subtraction, made
    // here so that `presence`, the lift and the opacity go on meaning what they
    // meant when the reveal was the only thing writing them.
    function pushTo(fraction: real): void {
        if (!root.open)
            return;
        root.pushing = true;
        root.pushOut = 1 - Math.max(0, Math.min(fraction, 1));
    }

    function pushEnd(gone: bool): void {
        // A release always arrives and a push does not always precede it: the
        // guard above turns a push made on a closed sheet into a gesture this
        // panel took no part in.
        if (!root.pushing)
            return;
        root.pushing = false;
        // Hand the smoother the depth the hand let go at, so the sheet carries
        // on from there rather than jumping back to start the journey again.
        // Committed, and `hide` drops the target to 0, so this finishes what the
        // push started; let go short of it and the target is still 1 and the very
        // same assignment walks it home.
        reveal.value = root.pushOut;
        root.pushOut = 0;
        if (gone)
            root.hide();
    }

    Follow {
        id: reveal

        speed: Appearance.anim.revealSpeed
        target: root.open ? 1 : 0
        // A 0-to-1 fraction, not a pixel count: the default quarter-pixel
        // epsilon would leave a closed sheet permanently a quarter open.
        epsilon: 0.005
    }

    Follow {
        id: wide

        speed: Appearance.anim.resizeSpeed
        target: root.wantWidth

        // Written as a handler on the target rather than as a call from wherever
        // the size changed, because the size changes at the END of a layout and
        // not at the assignment that caused it: the rows arrive, the Repeater
        // builds, the Column measures, and only then is there a new number to
        // take. Anything that snapped at the assignment would be snapping to the
        // height of the sheet as it was.
        onTargetChanged: {
            if (!root.arrived)
                wide.snap();
        }
    }

    Follow {
        id: tall

        speed: Appearance.anim.resizeSpeed
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
            onStreamFinished: root.rows = root.parse(text)
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
        // ONE CHARACTER, and any character: the face is monospaced, so every
        // glyph has the same advance and this is the whole font's ruler.
        text: "M"
    }

    // What the description column is as wide as. The LONGEST STRING rather than
    // the widest rendered one, which is exact here and not a shortcut: the
    // shell's font is monospaced, so character count and width are the same
    // ordering, and picking the string by length costs one pass instead of one
    // TextMetrics per row.
    readonly property string widestWhat: {
        let widest = "";
        for (const row of root.rows)
            if (row.what.length > widest.length)
                widest = row.what;
        return widest;
    }

    TextMetrics {
        id: whatInk

        font.family: Appearance.font.family
        font.pixelSize: Appearance.font.size.small
        text: root.widestWhat
    }

    // THE KEYBOARD FOCUS, on an item of its own rather than on the card.
    //
    // The card is invisible until the reveal has moved off zero, and an invisible
    // item cannot hold focus, so focusing the card on the way up would silently
    // do nothing and the first Escape would go to the desktop. This one has no
    // size and is always visible, so it is always focusable. SessionMenu's, and
    // its reasoning, unchanged.
    Item {
        id: keys

        Keys.onPressed: event => {
            // Tested on `event.key` rather than through Keys.onEscapePressed, to
            // match the power panel: the named handlers were measured not firing
            // on an item reached this way, and one idiom for both panels is worth
            // more than the two lines this saves.
            if (event.key !== Qt.Key_Escape)
                return;
            root.hide();
            event.accepted = true;
        }
    }

    // DECLARED FIRST, so it sits under everything: declaration order is input
    // order in QML. Anywhere that is not the sheet puts the sheet away.
    MouseArea {
        id: catcher

        anchors.fill: parent
        enabled: root.open
        visible: root.open

        onClicked: root.hide()
    }

    // THE WAY BACK: a push up into the top edge.
    //
    // Nothing summoned this from a direction, so there is no summoning gesture to
    // reverse (DESIGN.md 15's rule assumes one). Up into the top edge is the
    // convention the notch set for the top of this screen, and a sheet that flies
    // up and off is the same motion the reveal plays backwards, so the gesture
    // and the animation agree about which way "away" is.
    //
    // A SIBLING of the card wearing the card's rectangle, and NOT a child of it.
    // Pull keeps its press anchor in its parent's frame, which survives this item
    // moving inside a still parent and does NOT survive the PARENT moving, and
    // moving the card is this gesture's entire job. Inside the card it would be
    // measuring itself against its own effect and the push would dissolve into
    // noise. Out here the parent is the screen-filling root, which never moves,
    // and the bindings below hand it the card's rectangle anyway.
    //
    // DECLARED BEFORE THE CARD, which is what keeps it out of the sheet's way.
    // What is left for it is the padding ring and the header, because the
    // Flickable below takes its own presses whenever the list overflows, and that
    // is right rather than a compromise: a vertical drag on a scrolling list is a
    // scroll, and it would be perverse for the same motion to sometimes throw the
    // whole sheet away instead. THE HEADER IS THE HANDLE, which is where a handle
    // belongs, and the board is a field of keys that each take their own press,
    // so it leaves the gesture nothing to fight over either.
    Pull {
        id: push

        x: card.x
        y: card.y
        width: card.width
        height: card.height

        // Only while there is a sheet. A gesture zone outliving the thing it
        // pushes would be a patch of screen that swallows presses and answers
        // with nothing.
        //
        // Gated on `open` and NOT on the card's own visibility, which is the
        // difference between a push that lands and one that undoes itself. A
        // push carried to the end drives `presence` to exactly zero, which
        // takes the card's `visible` false MID-GESTURE; this item following it
        // would go invisible under the hand, Qt would take the grab away, and
        // Pull's `onCanceled` would report the completed push as a REVERSAL and
        // walk the sheet straight back out. `open` is still true for the whole
        // gesture and only goes false once the release has been answered.
        visible: root.open

        // Straight up. There is nothing to infer and nothing to branch on: the
        // vector is the gesture.
        dirX: 0
        dirY: -1

        // An EDGE's tolerance rather than a corner's, for TopNotch's reason: a
        // corner has ninety degrees of "off the screen" to divide up and an edge
        // has a hundred and eighty, so the corner figure is stingy here. What the
        // extra room would be kept away from is a gesture running ALONG the top
        // band, and there is not one.
        angle: Appearance.sizes.pullAngleEdge

        // A PUTTING-AWAY pull, so it measures against the thing being pushed
        // rather than against the screen: the sheet is right there under the hand
        // and the point of the drag is that its edge tracks it (Pull's travel
        // note has both cases).
        //
        // CLAMPED TO THE ROOM THE PRESS ACTUALLY HAS, which is the whole reason
        // this is not simply the card's height. The handle for a sheet that
        // scrolls is the header, by the paragraph above; a full-height sheet
        // rests one band from the top, so on this screen the header's lowest
        // pixel is ninety-four from the top edge and ninety-four pixels is ALL
        // THE UPWARD TRAVEL THERE IS. A pointer cannot leave the screen.
        // Measured against the card, which is 1180 tall here, that is a progress
        // of 0.08 and `pullCommit` is 0.25, so the commit point was unreachable
        // from the one place the gesture can be started and every release fell
        // back to the bare velocity test: exactly the lift-off noise
        // `pullCommit` exists to absorb (Pull's release note). A header shoved a
        // firm eighty pixels walked home because the finger peeled backwards on
        // its way off. The gesture was only completable from the padding strips
        // down the sides, which nothing points at.
        //
        // `push.fromY` IS that room, exactly and without measuring anything
        // twice: Pull records the press in its parent's frame, the parent is the
        // screen-filling root, so the press's own y is its distance from the top
        // edge. It is written once on the press and read on every move after it,
        // so the ruler is settled for the whole gesture. The card's own height is
        // settled for a gesture too: a view is only ever switched by the header's
        // controls, and nothing can be pressing those and dragging this at the
        // same time. The minimum keeps the panel's own ruler wherever it fits: a
        // sheet short enough not to scroll rests far enough down that the room
        // exceeds the card, so one finger-length of panel goes on being one
        // finger-length of travel and nothing about those changes. Only the tall
        // sheet, whose handle is pinned against the top edge, gets the shorter
        // ruler, and there a full push means "pushed to the top of the screen",
        // which is the one thing the hand can always do.
        travel: Math.min(root.cardHeight, push.fromY)

        // NO hoverEnabled. A hoverEnabled MouseArea is the topmost thing that
        // gets hover and everything under it gets none; nothing in this panel
        // wants hover today, and a zone the size of the sheet would be the reason
        // the first thing that did never worked.

        onPulled: fraction => root.pushTo(fraction)
        onFinished: gone => root.pushEnd(gone)

        // `tapped` is deliberately unwired. A press on the sheet's padding is
        // somebody reaching for a row and missing, and a sheet that vanished when
        // you missed a row would take the answer away at the exact moment you
        // were reading it. Tapping to close belongs to the catcher, which is
        // everywhere the sheet is not.
    }

    Item {
        id: card

        x: root.areaX + (root.areaWidth - root.cardWidth) / 2
        y: root.restY - root.lift
        width: root.cardWidth
        height: root.cardHeight

        visible: root.presence > 0.001
        enabled: root.open

        // Faded as well as moved. The card passes over the top band on its way
        // out, and a sheet at full strength crossing the chassis reads as two
        // panels colliding rather than as one leaving.
        opacity: root.presence

        G2Rect {
            anchors.fill: parent

            radius: Appearance.rounding.large
            color: Appearance.colour.surface

            // The padding ring, as an item rather than as margins on each child,
            // so the Flickable's clip lands on the ring's inside edge and rows
            // scroll out of sight at the padding rather than at the corner.
            Item {
                anchors.fill: parent
                anchors.margins: Appearance.padding.large

                Column {
                    id: head

                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right

                    // THE TITLE AND THE TWO CHOICES ON ONE LINE, with the
                    // controls hard right. A row of controls under the caption
                    // would put them below the sentence that explains the data,
                    // which reads as if they were about the sentence; up here
                    // they are visibly part of the panel's own frame, which is
                    // what they are.
                    Item {
                        width: parent.width
                        height: Math.max(title.implicitHeight, controls.implicitHeight)

                        StyledText {
                            id: title

                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter

                            // Capitalised, like the settings page's own title
                            // and its page names: a panel's name is a proper
                            // noun here, and the caption under it is the
                            // sentence.
                            text: "Hotkeys"
                            // The one thing this view is about, and the only
                            // place the second tier is spent: everything else
                            // here is body text carrying its hierarchy in
                            // colour.
                            font.pixelSize: Appearance.font.size.normal
                        }

                        Row {
                            id: controls

                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Appearance.padding.normal

                            // TWO SEGMENTED CONTROLS, side by side, and the
                            // order is which question you ask first: what am I
                            // looking at, and then how is it spelled.
                            //
                            // The state is a bool and the control is an index,
                            // so the two conversions are written here and
                            // nowhere else. A control that dealt in booleans
                            // could not have a third choice added to it without
                            // being rewritten, and the sheet may well grow one.
                            Segments {
                                options: ["List", "Board"]
                                current: root.board ? 1 : 0

                                onPicked: i => {
                                    root.board = i === 1;
                                }
                            }

                            Segments {
                                options: ["Words", "Symbols"]
                                current: root.symbols ? 1 : 0

                                onPicked: i => {
                                    root.symbols = i === 1;
                                }
                            }
                        }
                    }

                    // WHAT THE SHEET IS AND WHAT IT COULD NOT SAY.
                    //
                    // The second half only appears when there is something to
                    // admit, and it exists because the alternative is a screen of
                    // chords with nothing beside them and no explanation: on this
                    // machine every bind is registered from a Lua config, which
                    // Hyprland reports as `__lua` with a callback number, so the
                    // sheet can name eighty-two keys and say what one of them
                    // does. Blaming the sheet would be the natural reading, and
                    // it would be wrong. Naming the fix in the same breath, since
                    // a complaint you cannot act on is just a complaint.
                    //
                    // IT MATTERS MORE NOW THAN IT DID. A blank right-hand column
                    // in the list is at least visibly blank; a lit key on the
                    // board with nothing to say about it is a light and no more,
                    // and there is no column there to look empty. This one line
                    // is what stops that reading as the board being broken.
                    //
                    // WRAPPED AND NOT ELIDED, which is this line's entire
                    // history. It used to elide, and on the machine it was
                    // written for it read "83 binds, 81 of them saying only which
                    // key: give a" and stopped: the ellipsis landed exactly
                    // between the complaint and the instruction, so the sheet
                    // spent a line telling you it was useless and none telling
                    // you how to fix it. It is a complaint you cannot act on
                    // again, by the paragraph above, and by the worst possible
                    // mechanism, since nothing was wrong except the width.
                    //
                    // The width is why, and it is not a bug to go and fix: the
                    // card is measured off the BINDS (wantWidth, above), so its
                    // width is the widest chord plus the widest description, and
                    // on the machine with no descriptions there is nothing on the
                    // right to make it wide. Letting this sentence into that
                    // measurement was rejected outright, because one line of
                    // header prose would then set the width of the whole sheet
                    // and eighty short binds would be drawn across a paragraph's
                    // worth of card. Shortening the sentence until it fit was
                    // rejected for being true only here: the ruler is the user's
                    // own binds, a machine with shorter chords gets a narrower
                    // card, and the cut would simply come back somewhere nobody
                    // was looking. A line that CANNOT be truncated is the only
                    // version of this that is right on every machine, and two
                    // faint lines under a title cost nothing: wantHeight reads
                    // head.implicitHeight, so the card grows by the line it uses.
                    StyledText {
                        width: parent.width
                        wrapMode: Text.WordWrap

                        text: root.unnamed > 0 ? `${root.rows.length} binds, ${root.unnamed} of them saying only which key: give a bind a description with bindd and it lands here` : `${root.rows.length} binds`
                        color: Appearance.colour.textFaint
                    }
                }

                // Scrolls only when it has to. A sheet shorter than the screen is
                // a card; one that always scrolls is a document. The tray's
                // arrangement, and `clip` follows `interactive` for its reason:
                // clipping costs a render pass and buys nothing at all while
                // everything already fits.
                //
                // BOTH VIEWS LIVE IN IT, and the one that is not showing is
                // merely invisible rather than torn down. Rebuilding either on
                // every switch would throw away the board's latched modifiers and
                // the list's scroll position, which are exactly the state
                // somebody is holding while they flip between the two to check
                // one against the other.
                //
                // ONE OF THEM IS ONLY HALF TRUE BY ITSELF, which is what `park`
                // and `restoreScroll` above are for: this Flickable has one
                // contentY and there are two documents, so the position it is
                // holding is the showing view's and the other view's has to be
                // kept beside the choice of view. A Flickable each would need no
                // bookkeeping at all and was rejected for costing more than it
                // saves: two sets of bounds, two clips and two things to anchor,
                // for a document that is only ever read one view at a time.
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

                    // Where the hand left off, kept for the view it was left in.
                    // A wheel, a drag and a flick all end here, and nothing else
                    // does.
                    onMovementEnded: root.park()

                    BindList {
                        id: list

                        width: view.width
                        visible: !root.board

                        sheet: root
                    }

                    KeyBoard {
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
