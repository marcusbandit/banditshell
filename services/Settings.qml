pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The settings page, and the one thing about it that is not ordinary: it is the
// same page whether the shell draws it or the compositor does.
//
// Press the button on it and it becomes a real window, standing in the exact
// place and at the exact size it was standing a frame earlier. Press it again
// and the shell takes the page back wherever the window had got to by then, and
// flies it home. Nothing about the page changes across either handover; what
// changes is which surface is holding it.
//
// WHY BOTHER. A settings page is the one panel you want to keep open next to the
// thing you are changing, and a shell surface cannot be put next to anything: it
// is not a window, so it cannot be tiled, moved to another workspace, or left
// somewhere while you work. A window can. But a window is also the wrong thing
// to summon a page INTO from a keybind, which is what the shell surface is good
// at. So it is both, and the handover is the price.
//
// The state is TWO FLAGS, not one three-valued mode:
//
//   open      the page exists at all
//   floating  a window is holding it rather than the shell
//
// because almost everything that cares about one of them does not care about the
// other, and a mode enum would make every one of those tests a list.
//
// This file owns the compositor half. The drawing is modules/settings/.
Singleton {
    id: root

    readonly property int homeWidth: Appearance.sizes.settingsWidth
    readonly property int homeHeight: Appearance.sizes.settingsHeight

    property bool open: false
    property bool floating: false

    // Which screen's shell surface draws the card, by name. Only one screen
    // draws it: the page is one page, not one per monitor.
    property string screenName: ""

    // WHICH PAGE THE FACE IS SHOWING, and the register of pages it can show.
    //
    // On the singleton rather than on the face, and that placement is the
    // handover argument again: the face is drawn twice (a shell card and a real
    // window), and the whole point of the handover is that both surfaces show
    // the same page. A page choice kept face-side would be two choices, one per
    // copy, and pulling the page out would flip it back to whichever page the
    // other copy last remembered.
    //
    // `pages` is DATA, not decoration. The face renders its rail from it and
    // resolves each page's file by naming convention (key "icons" loads
    // pages/IconsPage.qml), so adding a page here and dropping a <Key>Page.qml
    // into modules/settings/pages/ is the entire recipe: no switch statement
    // anywhere grows a case.
    property string page: "icons"

    readonly property var pages: [
        {
            key: "icons",
            title: "Icons",
            icon: "apps"
        },
        {
            key: "appearance",
            title: "Appearance",
            icon: "palette"
        },
        // The one page that is not a nicety. Every other setting on this rail
        // has `banditshell set` in front of it as well as a row, and the band
        // order does not: it is an array, and Quickshell's IPC splats a
        // bracketed argument into an argument list (see config/Config.qml), so
        // there is no CLI spelling of it to fall back on.
        {
            key: "screens",
            title: "Screens",
            icon: "monitor"
        }
    ]

    // Unknown keys are IGNORED rather than reset to a default or taken on
    // faith. The rail is built from `pages` and cannot say a wrong key; the CLI
    // and whatever keybind arrives later can, and a typo from those should
    // change nothing at all rather than blank the face against a key no file
    // answers to.
    function setPage(key: string): void {
        if (root.pages.some(p => p.key === key))
            root.page = key;
    }

    // The window that had the keyboard before the page took it, so it can have it
    // back. Same contract as the power panel's.
    property string restoreTo: ""

    // WHERE THE CARD SHOULD APPEAR the next time the shell draws it, in that
    // screen's own coordinates, or null for "at home".
    //
    // Set on the way back from a window and cleared once the card has stood in
    // its place long enough to have been seen there. It is the thing that makes
    // the return seamless: the card does not open, it takes over.
    property var handoff: null

    // HOW THE COMPOSITOR RECOGNISES THE WINDOW.
    //
    // A title rather than a class, because Quickshell gives every window it makes
    // the same class and there is no second one to give this. Anchored at both
    // ends in the rule below, so it cannot match a terminal that happens to be
    // running something with this name in it.
    readonly property string windowTitle: "banditshell-settings"

    property bool windowOpen: false
    property int windowWidth: root.homeWidth
    property int windowHeight: root.homeHeight

    // The window is standing where it was told to, and can therefore be looked
    // at. Until then it is drawn fully transparent: a new floating window lands
    // wherever the compositor felt like putting it, and that place is never the
    // one the card was in.
    property bool placed: false

    property string address: ""

    // The rect a window has been asked for but has not reached yet, in the
    // compositor's own coordinates. Non-null exactly while one is on its way.
    property var pending: null

    // `on` names the screen to draw it on, for the callers that know: a corner
    // you clicked is on a particular monitor, and opening the page on whichever
    // one happens to hold the focused window would put it somewhere you are not
    // looking. Everything summoned by name rather than reached for leaves it
    // empty and gets the focused screen, which is the right answer when the
    // request did not come from a place.
    // `var` rather than `string`, and that is not a style choice: QML coerces a
    // MISSING string argument to the literal "undefined", which is a perfectly
    // truthy screen name that no screen has, and every caller that does not name
    // one would assign the page to a monitor that does not exist and then draw
    // it nowhere.
    // `which` optionally names the page the face should be showing. A KNOWN
    // page key switches to it; anything else, including the missing argument,
    // leaves the page alone, so every caller written before pages existed keeps
    // meaning exactly what it meant. `var` for the screen argument's reason,
    // and tested for stringness here rather than letting setPage's coercion
    // sort it out: a missing argument arriving as the literal "undefined" is an
    // accident this file already documents once, not a contract to lean on.
    // Applied BEFORE the open guard, on purpose: "show me the icons page" is a
    // request about the page as well as about the panel, and refusing the first
    // half because the second was already granted would answer it with nothing.
    function show(on: var, which: var): void {
        if (typeof which === "string")
            root.setPage(which);
        if (root.open)
            return;
        root.handoff = null;
        root.screenName = (typeof on === "string" && on) || Hypr.focusedScreen || Quickshell.screens[0]?.name || "";
        // AFTER the line above, because that line is what decides which screen
        // this page is opening on, and the window to hand the keyboard back to
        // is the one that was in front of you THERE. `on` names a screen
        // precisely for the callers that are not on the focused one, so reading
        // the shell-wide focusedAddress here contradicted the argument written
        // over this function's own argument list. See focusedByMonitor in
        // services/Hypr.qml.
        root.restoreTo = Hypr.focusedOn(root.screenName);
        root.floating = false;
        root.open = true;
    }

    function hide(): void {
        if (!root.open)
            return;
        root.open = false;
        root.floating = false;
        root.handoff = null;
        root.closeWindow();
        Hypr.restoreFocus(root.restoreTo);
        root.restoreTo = "";
    }

    // The page rides through untouched: a toggle is a show or a hide, and hide
    // has no use for one.
    function toggle(on: var, which: var): void {
        if (root.open)
            root.hide();
        else
            root.show(on, which);
    }

    // THE PRESS THAT TURNS THE CARD INTO A WINDOW.
    //
    // The rect arrives in the screen's own coordinates, because that is what the
    // card knows about itself; the compositor thinks in the layout's, so the
    // screen's origin goes on here rather than at every call site.
    //
    // Nothing becomes visible from this call. The window is asked for, and the
    // shell keeps drawing the card until it has been put where the card is; see
    // settle() below.
    function popOut(screen: var, x: real, y: real, w: real, h: real): void {
        if (!root.open || root.floating || !screen)
            return;

        root.address = "";
        root.placed = false;
        root.pending = {
            x: Math.round(screen.x + x),
            y: Math.round(screen.y + y),
            w: Math.round(w),
            h: Math.round(h)
        };
        root.windowWidth = root.pending.w;
        root.windowHeight = root.pending.h;
        root.windowOpen = true;
        giveUp.restart();
    }

    // THE PRESS THAT PUTS THE WINDOW BACK IN THE SHELL.
    //
    // Where the window IS has to be asked for rather than remembered. Dragging a
    // floating window emits no event, so anything the shell had cached dates from
    // whenever something else last happened, and "spawn where the window is"
    // would mean "spawn where the window was when you last changed workspace".
    function popIn(): void {
        if (!root.floating || reader.running)
            return;
        reader.running = true;
    }

    function closeWindow(): void {
        giveUp.stop();
        root.windowOpen = false;
        root.placed = false;
        root.address = "";
        root.pending = null;
    }

    // Which screen a point in the compositor's layout falls on. The window can be
    // dragged to another monitor, and the shell surface that takes it back has to
    // be that monitor's.
    function screenAt(x: real, y: real): var {
        for (const s of Quickshell.screens)
            if (x >= s.x && x < s.x + s.width && y >= s.y && y < s.y + s.height)
                return s;
        return Quickshell.screens[0] ?? null;
    }

    // The window has arrived where the card was. Both are now drawing the same
    // page in the same place, which is the only moment either can change without
    // it being seen.
    function settle(): void {
        giveUp.stop();
        root.pending = null;
        root.placed = true;
        root.floating = true;
    }

    // What `hyprctl -j clients` said, once we have found ourselves in it.
    function land(json: string): void {
        let client = null;
        try {
            client = JSON.parse(json).find(c => c.title === root.windowTitle);
        } catch (e) {}

        // The window is gone: closed from the compositor while we were asking.
        // There is nothing to come back FROM, so the page goes with it.
        if (!client)
            return root.hide();

        const w = client.size[0];
        const h = client.size[1];
        const screen = root.screenAt(client.at[0] + w / 2, client.at[1] + h / 2);
        if (!screen)
            return root.hide();

        root.screenName = screen.name;
        root.handoff = {
            x: client.at[0] - screen.x,
            y: client.at[1] - screen.y,
            w,
            h
        };

        // The shell takes the window's place BEFORE the window goes, and the card
        // stays exactly there for as long as `handoff` is set. Only when it is
        // cleared does the card start flying home, which is why the window can be
        // closed and the flight begun on the same tick: by then the card has been
        // standing in front of it for two frames.
        root.floating = false;
        handback.restart();
    }

    Timer {
        id: handback

        interval: Appearance.anim.handover
        onTriggered: {
            root.closeWindow();
            root.handoff = null;
        }
    }

    // A window that never arrives must not leave the page invisible in one place
    // and absent from the other. If the compositor has not answered by now,
    // show the window wherever it landed rather than nowhere at all.
    Timer {
        id: giveUp

        interval: Appearance.anim.slow
        onTriggered: {
            console.warn("Settings: the compositor never placed the window; showing it where it landed.");
            root.settle();
        }
    }

    Connections {
        target: Hypr

        // The window has an address for the first time, which is the earliest
        // moment anything can be said about where it goes.
        function onWindowOpened(addr: string, title: string): void {
            if (!root.pending || title !== root.windowTitle)
                return;

            root.address = addr;
            const p = root.pending;

            // Size first, then position: resizing is anchored at the top-left, so
            // doing it second would be doing it to a corner that has already been
            // put where it belongs.
            //
            // Both dialects again, and both do the two in ONE hyprctl, because
            // the exit of that one process is the moment the window is standing
            // where the card is and the handover may happen.
            if (Hypr.lua)
                placer.exec(["hyprctl", "eval", `(function() local w = "address:${addr}" hl.dispatch(hl.dsp.window.resize({ x = ${p.w}, y = ${p.h}, window = w })) hl.dispatch(hl.dsp.window.move({ x = ${p.x}, y = ${p.y}, window = w })) end)()`]);
            else
                placer.exec(["hyprctl", "--batch", `dispatch resizewindowpixel exact ${p.w} ${p.h},address:${addr} ; dispatch movewindowpixel exact ${p.x} ${p.y},address:${addr}`]);
        }

        // Closed from the compositor rather than from the button. The page went
        // with it: a window is a thing you are allowed to close, and pretending
        // otherwise would leave the shell believing it was showing a page that
        // is not on any screen.
        function onWindowClosed(addr: string): void {
            if (root.address && addr === root.address)
                root.hide();
        }

        function onConfigReloaded(): void {
            root.installRules();
        }

        // The compositor has just said which language it speaks. Everything the
        // rules need was known long before this; this is the last of it.
        function onParserKnownChanged(): void {
            root.installRules();
        }
    }

    // THROUGH hyprctl RATHER THAN Hyprland.dispatch, for the one thing dispatch
    // cannot do: say when.
    //
    // A dispatch down the event socket is fire and forget, so a card that has to
    // hand over the instant the window lands would have to guess a delay and be
    // wrong on a loaded machine. hyprctl exits when Hyprland has done the work,
    // so the exit IS the moment.
    Process {
        id: placer

        onExited: root.settle()
    }

    Process {
        id: reader

        command: ["hyprctl", "-j", "clients"]

        stdout: StdioCollector {
            onStreamFinished: root.land(text)
        }
    }

    // WHAT THE COMPOSITOR HAS TO BE TOLD ONCE.
    //
    // Nothing about how the window LOOKS. The border, the rounding, the shadow
    // and the inactive dim are the user's decoration settings, they are what makes
    // a window on this desktop look like a window, and the page is a window now.
    // Turning them off (which this used to do, on the theory that the window was
    // the card and the card had its own edge) is exactly what made it read as a
    // pane of wallpaper rather than as a peer of the terminal beside it.
    //
    // `float` is not cosmetic: a tiled window cannot be put anywhere, and every
    // one of these transitions is about a window being in an exact place.
    //
    // `no_anim` is not cosmetic either, and it is the one thing here that is about
    // drawing. The open animation would play over the handover - a window sliding
    // in from wherever the compositor first put it, on top of a card already
    // standing where it belongs - and the whole point of the handover is that
    // there is nothing to see. The window's arrival is a placement, not an
    // entrance; it has already entered, as a card.
    //
    // Pushed from here rather than left in the user's hyprland.conf because it is
    // part of this feature and not part of their setup: a shell that needs a
    // handful of lines of compositor config to not look broken is a shell that
    // will look broken on the next machine.
    //
    // THE RULE CARRIES THE DEFAULTS, and only the defaults: that it floats, the
    // size the page rests at, and that its arrival is not animated. Where a
    // particular window goes is not a default and cannot be one, so the exact rect
    // is still dispatched per handover; see the placer above. The size is here
    // anyway, because a window that arrives already the right size is one the
    // placer only has to MOVE, and because it is the size the page has whether or
    // not anything else works.
    //
    // SAID TWICE, once per parser, and that is not duplication for its own sake.
    // Hyprland 0.5x replaced its config language with Lua and the new parser
    // refuses `keyword` outright, so a shell that only knows the old spelling
    // installs nothing, says nothing, and hands you a tiled window that the
    // handover cannot move anywhere. Each entry says itself in both dialects, on
    // one line, so the pair cannot drift apart.
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

    // For the case where the parser probe has already answered by the time this
    // loads. When it has not, the handler above is what installs them.
    Component.onCompleted: root.installRules()
}
