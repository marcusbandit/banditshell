pragma ComponentBehavior: Bound

import QtQuick
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

    // The WHOLE screen while it is up, so a tap anywhere off the sheet puts it
    // away. Same shape, and the same argument, as the power panel's catcher: a
    // panel summoned by name has nothing else to dismiss it.
    readonly property Item maskItem: catcher

    // The window that had the keyboard before this took it, so it can have it
    // back. A sheet you opened to look something up and then had to click back
    // into your editor from would cost more than it told you.
    property string restoreTo: ""

    // WHAT THE COMPOSITOR SAID, parsed into the only four things a row needs:
    // which modifiers, which submap, the chord as it reads, and what it does.
    // Kept between opens, so the second open draws a full sheet on the frame it
    // is asked for rather than growing into one as hyprctl answers.
    property var rows: []

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
    readonly property var modBits: [
        {
            bit: 64,
            name: "SUPER"
        },
        {
            bit: 4,
            name: "CTRL"
        },
        {
            bit: 8,
            name: "ALT"
        },
        {
            bit: 1,
            name: "SHIFT"
        },
        {
            bit: 2,
            name: "CAPS"
        },
        {
            bit: 16,
            name: "MOD2"
        },
        {
            bit: 32,
            name: "MOD3"
        },
        {
            bit: 128,
            name: "MOD5"
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

    // The chord: the modifiers and the key, in the shape a manual writes them.
    //
    // The key is APPENDED RATHER THAN ASSUMED, so a bind the compositor
    // described with none of its three key fields prints its modifiers alone
    // instead of trailing a plus sign into nothing. Hyprland cannot produce one
    // today, since every bind it parses sets exactly one of the three, so this
    // is a guard against an answer nobody has seen rather than a case in hand;
    // inventing a placeholder key for it was the alternative, and it would be
    // the sheet claiming to know something it was never told.
    function chordFor(mask: int, key: string): string {
        const parts = root.modNames(mask);
        if (key)
            parts.push(root.keyName(key));
        return parts.join(" + ");
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
                chord: root.chordFor(mask, root.keyOf(b)),
                what: root.describe(b)
            };
        });
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
            const key = `${row.submap}\u001f${row.mask}`;
            let group = byKey[key];
            if (!group) {
                const names = root.modNames(row.mask);
                group = {
                    mask: row.mask,
                    mods: row.mods,
                    // A bare key is still a family, and the commonest one on a
                    // laptop: every volume, brightness and media key lives here.
                    // It needs a heading that says so rather than an empty line.
                    title: (names.length > 0 ? names.join(" + ") : "NO MODIFIER") + (row.submap ? ` (${row.submap})` : ""),
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
    readonly property real areaX: Appearance.sizes.band + Appearance.sizes.sidebarWidth
    readonly property real areaY: Appearance.sizes.band
    readonly property real areaWidth: root.width - root.areaX - Appearance.sizes.band
    readonly property real areaHeight: root.height - Appearance.sizes.band * 2

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
    // Rounded UP, both of them. TextMetrics measures the font's own advances and
    // StyledText renders natively, which puts stems back on the pixel grid, so
    // the drawn string can come out a fraction wider than the measured one. A
    // column short by half a pixel would put an ellipsis on the one row it was
    // sized for, which is the row most worth reading.
    readonly property real chordWidth: Math.ceil(chordInk.width)
    readonly property real contentWidth: root.chordWidth + root.gutter + Math.ceil(whatInk.width)

    // No narrower than a sidebar menu, so a sheet that came back empty is still
    // a panel saying so rather than a stub, and never wider than the room it has.
    readonly property real cardWidth: Math.min(root.areaWidth, Math.max(Appearance.sizes.menuWidth, root.contentWidth + Appearance.padding.large * 2))

    // As tall as it needs and no taller: a sheet of six binds is a card, and one
    // of eighty-two is a full-height document that scrolls. Read off the laid-out
    // column rather than computed from a row count times a row height, because
    // the second is a copy of the layout's arithmetic that goes wrong the first
    // time a heading changes size.
    //
    // NOT SMOOTHED, deliberately. The height jumps once, from header-high to
    // whatever the binds want, on the frame hyprctl answers; that lands a few
    // milliseconds into a reveal that takes a fifth of a second, while the card
    // is still mostly above the top edge and nearly transparent. A Follow here
    // would be a moving part earning nothing, and after the first open the rows
    // are already in hand and there is no jump at all.
    readonly property real cardHeight: Math.min(root.areaHeight, head.implicitHeight + Appearance.padding.normal + list.implicitHeight + Appearance.padding.large * 2)

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

    function show(): void {
        if (root.open)
            return;
        root.restoreTo = Hypr.focusedAddress;
        // RE-READ EVERY TIME. The sheet is what you open after changing your
        // binds, so a cached list is wrong at exactly the moment it is consulted.
        root.reload();
        // Back to the top, because the sheet you scrolled halfway through
        // yesterday is not where the next question starts.
        view.contentY = 0;
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

    Process {
        id: query

        command: ["hyprctl", "binds", "-j"]

        stdout: StdioCollector {
            onStreamFinished: root.rows = root.parse(text)
        }
    }

    // What the chord column measures itself against, and what the sheet is as
    // wide as. Both are the LONGEST STRING rather than the widest rendered one,
    // which is exact here and not a shortcut: the shell's font is monospaced, so
    // character count and width are the same ordering, and picking the string by
    // length costs one pass instead of one TextMetrics per row.
    readonly property string widestChord: {
        let widest = "";
        for (const row of root.rows)
            if (row.chord.length > widest.length)
                widest = row.chord;
        return widest;
    }

    readonly property string widestWhat: {
        let widest = "";
        for (const row of root.rows)
            if (row.what.length > widest.length)
                widest = row.what;
        return widest;
    }

    TextMetrics {
        id: chordInk

        font.family: Appearance.font.family
        font.pixelSize: Appearance.font.size.small
        text: root.widestChord
    }

    TextMetrics {
        id: whatInk

        font.family: Appearance.font.family
        font.pixelSize: Appearance.font.size.small
        text: root.widestWhat
    }

    // THE KEYBOARD, on an item of its own rather than on the card.
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
    // belongs.
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
        // note has both cases). `cardHeight` is a settled ruler: the push moves
        // the card and never resizes it, so this cannot shrink as it is read.
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
        // so the ruler is settled for the whole gesture, which is what
        // `cardHeight` was chosen for. The minimum keeps the panel's own ruler
        // wherever it fits: a sheet short enough not to scroll rests far enough
        // down that the room exceeds the card, so one finger-length of panel
        // goes on being one finger-length of travel and nothing about those
        // changes. Only the tall sheet, whose handle is pinned against the top
        // edge, gets the shorter ruler, and there a full push means "pushed to
        // the top of the screen", which is the one thing the hand can always do.
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

                    StyledText {
                        // Capitalised, like the settings page's own title and its
                        // page names: a panel's name is a proper noun here, and
                        // the caption under it is the sentence.
                        text: "Hotkeys"
                        // The one thing this view is about, and the only place
                        // the second tier is spent: everything else here is body
                        // text carrying its hierarchy in colour.
                        font.pixelSize: Appearance.font.size.normal
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
                    // card is measured off the BINDS (cardWidth, above), so its
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
                    // faint lines under a title cost nothing: cardHeight reads
                    // head.implicitHeight, so the card grows by the line it uses.
                    StyledText {
                        width: parent.width
                        wrapMode: Text.WordWrap

                        text: root.unnamed > 0 ? `${root.rows.length} binds, ${root.unnamed} of them saying only which key: give a bind a description and it lands here` : `${root.rows.length} binds`
                        color: Appearance.colour.textFaint
                    }
                }

                // Scrolls only when it has to. A sheet shorter than the screen is
                // a card; one that always scrolls is a document. The tray's
                // arrangement, and `clip` follows `interactive` for its reason:
                // clipping costs a render pass and buys nothing at all while
                // everything already fits.
                Flickable {
                    id: view

                    anchors.top: head.bottom
                    anchors.topMargin: Appearance.padding.normal
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom

                    contentHeight: list.implicitHeight
                    interactive: contentHeight > height
                    clip: interactive
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: list

                        width: view.width
                        spacing: Appearance.padding.normal

                        // The sheet with nothing on it, which is not the same as
                        // a sheet that has not drawn. It names WHERE the nothing
                        // came from rather than saying "no binds", because the
                        // three ways to get here (a compositor with no binds, an
                        // hyprctl that is not on PATH, and one that answered with
                        // something other than JSON) are indistinguishable from
                        // this side and all three are questions about hyprctl.
                        // The parse failure also puts a line in the log.
                        StyledText {
                            width: parent.width
                            elide: Text.ElideRight
                            visible: root.rows.length === 0

                            text: "nothing came back from hyprctl"
                            color: Appearance.colour.textGhost
                        }

                        Repeater {
                            model: root.sections

                            delegate: Column {
                                id: section

                                required property var modelData
                                required property int index

                                width: list.width
                                spacing: Appearance.padding.small

                                // A hairline in its own band of air, on every
                                // section but the first. The band is what gives
                                // the rule room to breathe: a Separator dropped
                                // straight into the column would sit one row
                                // spacing from the rows on either side and read
                                // as an underline on the last of them. An
                                // invisible item takes no space in a Column, so
                                // the first section simply starts.
                                Item {
                                    width: parent.width
                                    height: Appearance.padding.normal
                                    visible: section.index > 0

                                    Separator {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width
                                    }
                                }

                                StyledText {
                                    width: parent.width
                                    elide: Text.ElideRight

                                    text: section.modelData.title
                                    color: Appearance.colour.textFaint
                                }

                                Repeater {
                                    model: section.modelData.rows

                                    delegate: Item {
                                        id: line

                                        required property var modelData

                                        width: section.width
                                        height: chord.implicitHeight

                                        // THE CHORD, in the brightest tier: it is
                                        // the thing you came here to find, and
                                        // the description is what confirms you
                                        // found the right one.
                                        //
                                        // It repeats the modifiers the section
                                        // heading already named, and that is
                                        // deliberate: a row you read out of the
                                        // corner of your eye, or photograph, or
                                        // scroll to with the heading off the top,
                                        // has to be a complete answer on its own.
                                        StyledText {
                                            id: chord

                                            // Clamped as well as sized, and the
                                            // clamp is never reached in
                                            // practice: the column is already
                                            // as wide as the longest chord
                                            // there is, so nothing elides. It
                                            // is here for the pathological
                                            // narrow screen, where the column
                                            // measured wider than the card it
                                            // sits in and a chord would
                                            // otherwise run out past the
                                            // padding.
                                            width: Math.min(root.chordWidth, line.width)
                                            elide: Text.ElideRight

                                            text: line.modelData.chord
                                        }

                                        StyledText {
                                            x: root.chordWidth + root.gutter
                                            width: Math.max(0, line.width - root.chordWidth - root.gutter)
                                            elide: Text.ElideRight

                                            text: line.modelData.what
                                            color: Appearance.colour.textDim
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
