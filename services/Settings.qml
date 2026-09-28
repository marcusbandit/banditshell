pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The settings page. A REAL WINDOW, always.
//
// It used to be two things: a card the shell drew on its own surface, and the
// same card pulled out into a window, with a handover that moved the page
// between them in place. The card is gone. A settings page is the one panel
// you want to keep open next to the thing you are changing, and a shell surface
// cannot be put next to anything: it is not a window, so it cannot be tiled,
// moved to another workspace, or left somewhere while you work. A window can.
// With no docked state to hand over from or back to, the page is simply a
// window the way the file browser is one, and all the machinery the handover
// needed (the settle, the give-up timer, the reader, the handback) went with
// it.
//
// KEPT ALIVE, hidden, rather than destroyed between uses. The page is a page,
// not a dialog, and rebuilding it every time it was opened would throw away
// whatever state it had accumulated - which, once this has more in it than a
// button, is the entire point of it being a settings page.
//
// This file owns the state and the compositor rules. The drawing is
// modules/settings/.
Singleton {
    id: root

    readonly property int homeWidth: Appearance.sizes.settingsWidth
    readonly property int homeHeight: Appearance.sizes.settingsHeight

    property bool open: false

    // WHICH SCREEN THE PAGE WAS SUMMONED FROM, by name. Not where the window
    // IS - a window is on whichever monitor it has been dragged to - but where
    // the request came from: a corner you clicked is on a particular monitor,
    // and pages inside settings that open other shell surfaces (the hotkey
    // sheet) aim them there rather than at whatever the window now happens to
    // overlap. Everything summoned by name rather than reached for leaves it
    // empty and gets the focused screen, which is the right answer when the
    // request did not come from a place.
    property string screenName: ""

    // WHICH PAGE THE FACE IS SHOWING, and the register of pages it can show.
    //
    // On the singleton rather than on the face, so that every reader of the
    // state - the CLI, a keybind, the preview harness - agrees with the face
    // about what is open.
    //
    // `pages` is DATA, not decoration. The face renders its list of sections
    // from it and resolves each page's file by naming convention (key
    // "general" loads pages/GeneralPage.qml), so adding a page here and
    // dropping a <Key>Page.qml into modules/settings/pages/ is the entire
    // recipe: no switch statement anywhere grows a case.
    //
    // EMPTY MEANS THE ROOT: the list of sections itself, which is a place of
    // its own the way a phone's settings app opens on its list rather than on
    // whichever section you last visited. The face is wide enough to stand the
    // list and the first section side by side, because a pane with nothing in
    // it is not a state worth drawing.
    property string page: ""

    // `group` is which card of the list a section sits in, and `blurb` is the
    // line under its name that says what is inside before you open it: a list
    // of one-word titles is a list you have to open every entry of.
    //
    // THE GROUPS ARE A PHONE'S. Settings is the one surface that has
    // EVERYTHING, which is what makes it settings rather than a menu: the
    // wifi, bluetooth and sound menus on the bar are the same questions asked
    // in a hurry, and this is where they are asked with room. So the list is
    // laid out the way Android lays its own out, network first, then what you
    // see and hear, then the system, then what this thing is.
    //
    // A page with a `parent` is a SUB-PAGE: it is not in the list, it is
    // reached from its parent's own rows, and back from it goes to the parent
    // rather than to the list. The font picker and the wallpaper are ones; a
    // page of a hundred typeface names does not belong in a list of sections,
    // and what the shell is seen against is an appearance question.
    //
    // THE LIST IS FILTERED, not curated: a machine with no battery has no
    // battery page, and a section about a cell the machine does not have is a
    // lie the list would be telling every time it drew. The filter is a
    // binding rather than a one-off, so a machine that grows a battery grows
    // the page with it, and every consumer of `pages` -- the rail, the search,
    // `setPage`'s guard -- inherits the answer from this one place.
    readonly property var pages: [
        {
            key: "wifi",
            title: "Wi-Fi",
            icon: "wifi",
            group: "Network",
            blurb: "networks, the adapter, sharing"
        },
        {
            key: "bluetooth",
            title: "Bluetooth",
            icon: "bluetooth",
            group: "Network",
            blurb: "paired devices and pairing"
        },
        {
            key: "sound",
            title: "Sound",
            icon: "volume_up",
            group: "Sound and display",
            blurb: "output, input, each app"
        },
        // The one page that is not a nicety. Every other setting in this list
        // has `banditshell set` in front of it as well as a row, and the band
        // order does not: it is an array, and Quickshell's IPC splats a
        // bracketed argument into an argument list (see config/Config.qml), so
        // there is no CLI spelling of it to fall back on.
        {
            key: "monitors",
            title: "Monitors",
            icon: "monitor",
            group: "Sound and display",
            blurb: "displays and their workspace bands"
        },
        // A SUB-PAGE of Appearance, reached from Appearance's rows rather than
        // from the list: what the shell is seen against is an appearance
        // question, and a top-level section for it left Appearance with
        // nothing to be.
        {
            key: "wallpaper",
            title: "Wallpaper",
            icon: "wallpaper",
            parent: "appearance",
            blurb: "the picture behind everything"
        },
        {
            key: "appearance",
            title: "Appearance",
            icon: "palette",
            group: "Sound and display",
            blurb: "palette, font, the compositor"
        },
        {
            key: "font",
            title: "Font",
            icon: "text_fields",
            parent: "appearance",
            blurb: "the face every word is set in"
        },
        {
            key: "general",
            title: "General",
            icon: "tune",
            group: "System",
            blurb: "touch, windows, the fold, network rules"
        },
        {
            key: "battery",
            title: "Battery",
            icon: "battery_full",
            group: "System",
            blurb: "charge, health, the log"
        },
        {
            key: "device",
            title: "Device",
            icon: "computer",
            group: "System",
            blurb: "the hardware, and how it is doing"
        },
        {
            key: "keybinds",
            title: "Keybinds",
            icon: "keyboard",
            group: "System",
            blurb: "every Hyprland bind: record a chord, edit the command"
        },
        {
            key: "developer",
            title: "Developer",
            icon: "code",
            group: "System",
            blurb: "reload, files, what the shell knows"
        },
        {
            key: "about",
            title: "About",
            icon: "info",
            group: "About",
            blurb: "what it is, and why it is like this"
        }
    ].filter(p => p.key !== "battery" || Battery.available);

    // The groups, in the order the pages first name them, so the list's cards
    // come from the data above rather than from a second list that could
    // disagree with it. Sub-pages name no group and appear in none.
    readonly property var groups: root.pages.map(p => p.group).filter((g, i, all) => g && all.indexOf(g) === i)

    function entry(key: string): var {
        return root.pages.find(p => p.key === key) ?? null;
    }

    // The section a page belongs to in the list: itself, or for a sub-page,
    // its parent. What the list highlights beside an open page.
    function sectionOf(key: string): string {
        const e = root.entry(key);
        return e?.parent ?? key;
    }

    // Unknown keys are IGNORED rather than reset to a default or taken on
    // faith. The list is built from `pages` and cannot say a wrong key; the
    // CLI and whatever keybind arrives later can, and a typo from those should
    // change nothing at all rather than blank the face against a key no file
    // answers to.
    function setPage(key: string): void {
        if (root.pages.some(p => p.key === key))
            root.page = key;
    }

    // One level out: a sub-page goes to its parent, a section goes to the
    // list. Its own verb rather than setPage(""), because "" is not a page
    // and setPage's whole contract is refusing keys that are not.
    function back(): void {
        root.page = root.entry(root.page)?.parent ?? "";
    }

    // HOW THE COMPOSITOR RECOGNISES THE WINDOW.
    //
    // A title rather than a class, because Quickshell gives every window it makes
    // the same class and there is no second one to give this. Anchored at both
    // ends in the rule below, so it cannot match a terminal that happens to be
    // running something with this name in it.
    readonly property string windowTitle: "banditshell-settings"

    // `on` names the screen the request came from, for the callers that know;
    // see screenName. `which` optionally names the page the face should be
    // showing. A KNOWN page key switches to it; anything else, including the
    // missing argument, leaves the page alone, so every caller written before
    // pages existed keeps meaning exactly what it meant. `var` rather than
    // `string`, and that is not a style choice: QML coerces a MISSING string
    // argument to the literal "undefined", which is a perfectly truthy screen
    // name that no screen has. Applied BEFORE the open guard, on purpose:
    // "show me the icons page" is a request about the page as well as about
    // the panel, and refusing the first half because the second was already
    // granted would answer it with nothing.
    function show(on: var, which: var): void {
        if (typeof which === "string")
            root.setPage(which);
        if (root.open)
            return;
        root.screenName = (typeof on === "string" && on) || Hypr.focusedScreen || Quickshell.screens[0]?.name || "";
        root.open = true;
    }

    function hide(): void {
        root.open = false;
    }

    // The page rides through untouched: a toggle is a show or a hide, and hide
    // has no use for one.
    function toggle(on: var, which: var): void {
        if (root.open)
            root.hide();
        else
            root.show(on, which);
    }

    // WHAT THE COMPOSITOR HAS TO BE TOLD ONCE.
    //
    // Nothing about how the window LOOKS. The border, the rounding, the shadow
    // and the inactive dim are the user's decoration settings, they are what makes
    // a window on this desktop look like a window, and the page is a window.
    // Turning them off would be exactly what made it read as a pane of wallpaper
    // rather than as a peer of the terminal beside it.
    //
    // `float` is not cosmetic: a tiled settings page squeezed into whatever the
    // layout had left is not the page that was designed.
    //
    // `no_anim` is about summoning: the page is a document you left open on
    // purpose, reopened to the same place, and an open animation playing on
    // every toggle would read as a new window arriving rather than as the page
    // coming back to where it was. A placement, not an entrance.
    //
    // NOT centred, for the reason Files is not: the window is kept alive and
    // re-shown, so the compositor re-applies the rules on every open, and a
    // window that jumped back to the middle of the screen each time you toggled
    // it would be throwing away the place you put it.
    //
    // Pushed from here rather than left in the user's hyprland.conf because it is
    // part of this feature and not part of their setup: a shell that needs a
    // handful of lines of compositor config to not look broken is a shell that
    // will look broken on the next machine.
    //
    // SAID TWICE, once per parser, and that is not duplication for its own sake.
    // Hyprland 0.5x replaced its config language with Lua and the new parser
    // refuses `keyword` outright, so a shell that only knows the old spelling
    // installs nothing, says nothing, and hands you a tiled window the page
    // cannot fill. Each entry says itself in both dialects, on one line, so
    // the pair cannot drift apart.
    //
    // The legacy spelling is `<field> <value>, match:<field> <value>`, which is
    // Hyprland's rule syntax as of 0.5x and not the `float,title:^(x)$` of every
    // example still on the internet. The old form is not an error: hyprctl takes
    // it, exits 0, and prints its complaint onto a stdout nobody was reading.
    // Which is what the collector below is for.
    readonly property var rules: [
        {
            lua: "float = true",
            legacy: "float on"
        },
        {
            lua: `size = { ${root.homeWidth}, ${root.homeHeight} }`,
            legacy: `size ${root.homeWidth} ${root.homeHeight}`
        },
        {
            lua: "no_anim = true",
            legacy: "no_anim on"
        }
    ]

    function installRules(): void {
        // Not before the compositor has said which language it speaks: `lua`
        // reads false while the question is still in flight, and false is also a
        // real answer. See Hypr.parserKnown.
        if (!Compositor.isHyprland || !Hypr.parserKnown)
            return;

        const title = `^(${root.windowTitle})$`;

        if (Hypr.lua) {
            // ONE rule with every field on it, named, rather than one rule per
            // field: the Lua binding takes a whole spec at once, and a name is
            // how a rule is identified rather than accumulated.
            ruler.exec(["hyprctl", "eval", `hl.window_rule({ name = "${root.windowTitle}", match = { title = "${title}" }, ${root.rules.map(r => r.lua).join(", ")} })`]);
            return;
        }

        ruler.exec(["hyprctl", "--batch", root.rules.map(r => `keyword windowrule ${r.legacy}, match:title ${title}`).join(" ; ")]);
    }

    Process {
        id: ruler

        // hyprctl reports a rejected rule on stdout and still exits 0, so the
        // exit code says nothing at all. It says `ok` per rule when it is happy;
        // anything else on that stream is the complaint.
        stdout: StdioCollector {
            onStreamFinished: {
                const complaints = text.split("\n").map(l => l.trim()).filter(l => l && l !== "ok");
                if (complaints.length > 0)
                    console.warn(`Settings: the compositor refused a window rule: ${complaints.join("; ")}`);
            }
        }
    }

    Connections {
        target: Hypr

        function onConfigReloaded(): void {
            root.installRules();
        }

        // The compositor has just said which language it speaks. Everything the
        // rules need was known long before this; this is the last of it.
        function onParserKnownChanged(): void {
            root.installRules();
        }
    }

    // For the case where the parser probe has already answered by the time this
    // loads. When it has not, the handler above is what installs them.
    Component.onCompleted: root.installRules()
}
