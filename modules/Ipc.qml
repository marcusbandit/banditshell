pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// The shell's control surface, for the `banditshell` CLI, and through the CLI
// for keybinds: a Hyprland bind is an exec of a command line, so everything
// reachable here is a hotkey away without the shell knowing or caring which
// key. docs/hyprland-binds.example.conf is a worked set to copy from.
//
// It exists mostly so menus can be driven without a mouse. Hover is a fine way
// to open something and an impossible one to test: you cannot script a cursor
// into a corner and assert what happened. With every menu reachable from here,
// the gesture and the thing it opens can be checked separately.
//
// Every function returns a string, because a CLI that prints nothing on success
// is indistinguishable from one that silently did nothing.
Scope {
    id: root

    required property var picker

    // Shared by two of the penmap verbs, so `set` can answer with the same
    // sentence `status` does rather than inventing a second phrasing for the
    // same fact.
    function penmapStatus(): string {
        const r = PenMap.region;
        const lock = PenMap.aspectLocked ? "locked" : "free";
        const pad = PenMap.padConnected ? "pad" : "no pad";
        const mode = PenMap.followWindow ? ", follow" : "";
        return `${Math.round(r.width)}x${Math.round(r.height)} at ${Math.round(r.x)},${Math.round(r.y)} on ${PenMap.monitorName || "no monitor"} (${lock}, ${pad}${mode})`;
    }

    IpcHandler {
        target: "menu"

        // Every menu key, one per line. Off the window you are on, and any other
        // would answer the same: the keys are the tray's items plus the
        // sidebar's fixed entries, which is one list for the session however
        // many screens draw it. Nothing here asks what is OPEN, so there is
        // nothing for Shell.showing to go and find.
        function list(): string {
            const win = Shell.forScreen("");
            return win ? win.statusKeys.join("\n") : "";
        }

        function open(key: string, screen: string): string {
            const win = Shell.forScreen(screen);
            if (!win)
                return screen ? `no shell window on screen: ${screen}` : "no shell window";
            return win.openMenu(key) ? `open ${key}` : `no such menu: ${key}`;
        }

        function close(): string {
            for (const win of Shell.windows)
                win.menus.hide();
            return "closed";
        }

        // A NAMED screen is a question about that screen; an unnamed one is a
        // question about the menu, which may be standing on a monitor the focus
        // has since left. Shell.showing says why at length: asking "here"
        // whether this key is up answers no as soon as you glance elsewhere, and
        // the toggle then opens a second copy of the menu you were trying to put
        // away. `open` below it still means here, because a key that matched
        // nothing anywhere is a summon.
        function toggle(key: string, screen: string): string {
            const win = screen ? Shell.forScreen(screen) : Shell.showing(w => w.menus.currentKey === key);
            if (win?.menus.currentKey === key)
                return close();
            return open(key, screen);
        }

        // What is open, or nothing. Asked of the window that HAS one open rather
        // than of the one the keyboard is on: a menu does not close because you
        // looked away, and answering "" for a menu that is visibly up would be
        // this handler reporting a state the shell is not in.
        function current(): string {
            const win = Shell.showing(w => w.menus.currentKey);
            return win?.menus.currentKey ?? "";
        }

        // What the shell believes about the cursor, which is the whole reason a
        // menu is or is not still open. Worth being able to ask from outside:
        // "it closed when it should not have" and "it never thought you were on
        // it" look identical from a screenshot, and this separates them.
        //
        // The keyboard for the same reason: a field with a prompt open and a
        // field the surface has actually asked the compositor for the keyboard
        // for look identical from a screenshot, right up until you type.
        //
        // Read off the window HOLDING a menu, not off the focused one. The whole
        // question is why a particular menu did or did not stay up, and on two
        // monitors the answer from the screen it is not on is four fields of
        // nothing, which is indistinguishable from the menu having closed.
        function hover(): string {
            const win = Shell.showing(w => w.menus.currentKey);
            if (!win)
                return "no shell window";
            return `shell=${win.cursorOnShell} panel=${win.menus.hovered} open=[${win.menus.currentKey}] keyboard=${win.menus.needsKeyboard}`;
        }
    }

    IpcHandler {
        target: "picker"

        // Two axes: freeze the screen first or not, and go to the clipboard or
        // to an editor. Four names rather than flags, because a keybind is a
        // string and flags in a keybind are a thing to get wrong once and never
        // notice.
        function open(): string {
            root.picker.show(false, false);
            return "picker";
        }

        function freeze(): string {
            root.picker.show(true, false);
            return "picker (frozen)";
        }

        function clip(): string {
            root.picker.show(false, true);
            return "picker (to clipboard)";
        }

        function freezeclip(): string {
            root.picker.show(true, true);
            return "picker (frozen, to clipboard)";
        }

        function close(): string {
            root.picker.close();
            return "closed";
        }
    }

    IpcHandler {
        target: "launcher"

        // THE ONE THAT IS OUT, not the one you are standing in front of. The
        // difference only exists on two monitors and there it is the whole
        // behaviour: pull the launcher up, look at the other screen (which under
        // follow_mouse is enough to move the focus), press the bind again, and a
        // toggle that resolved to the focused window would open a second
        // launcher rather than close the first. Shell.showing carries the
        // argument; `open` just below stays on the focused window because a
        // summon means here.
        function toggle(): string {
            const win = Shell.showing(w => w.launcher.open);
            if (!win)
                return "no shell window";
            win.launcher.toggle();
            return win.launcher.open ? "open" : "closed";
        }

        function open(): string {
            Shell.forScreen("")?.launcher.show();
            return "open";
        }

        function close(): string {
            for (const win of Shell.windows)
                win.launcher.hide();
            return "closed";
        }

        // START SOMETHING BY ID, without a panel and without typing.
        //
        // The same call the launcher's Return makes, so the whole path after the
        // key (frecency, the window claim, the launch notice) can be exercised
        // from a terminal. The panel and what it starts break separately, which
        // is this file's whole reason for existing.
        function run(id: string): string {
            const entry = Apps.entryById(id) ?? Apps.search(id)[0];
            if (!entry)
                return `no application matches "${id}"`;
            Apps.launch(entry);
            Hypr.claimNextWindow();
            return `launched ${entry.name}`;
        }

        // Drive the niagara concept's rail from here, because hover cannot be
        // scripted: a warped pointer delivers no motion inside a surface it is
        // already in. 0 is the top of the rail, 1 the bottom, and anything
        // negative lets go of it.
        //
        // Aimed at the launcher that is OPEN, since a rail inside a closed panel
        // is nothing to scrub: this reports a fraction either way, and pointing
        // it at the focused window would have it report success into a launcher
        // nobody can see while the visible one stands still.
        function scrub(fraction: string): string {
            const win = Shell.showing(w => w.launcher.open);
            if (!win)
                return "no shell window";
            win.launcher.scrub(parseFloat(fraction));
            return `scrubbed to ${fraction}`;
        }
    }

    // WHAT YOU COPIED. The launcher's shape above, plus the things a list of
    // items has that a list of applications does not: a way to read it without a
    // panel, and a way to put one back without pointing at it.
    //
    // Those exist for the reason this whole file does. A menu opened by a key
    // and driven by a pointer can only be checked by looking at a picture of it,
    // and "the second row is the thing I copied" and "the second row LOOKS like
    // the thing I copied" are not the same claim. `list` settles it in text, and
    // `use` performs the one action the panel exists for without a surface being
    // involved at all, so the recorder and the panel can be broken separately.
    IpcHandler {
        target: "clipboard"

        // The launcher's toggle, down to the reason: the panel that is already
        // out is the one a second press is about, and the focused screen is not
        // where it necessarily is by then.
        function toggle(): string {
            const win = Shell.showing(w => w.clipboard.open);
            if (!win)
                return "no shell window";
            win.clipboard.toggle();
            return win.clipboard.open ? "open" : "closed";
        }

        function open(): string {
            Shell.forScreen("")?.clipboard.show();
            return "open";
        }

        // Every window, like the launcher's: closing is the one verb that must
        // work whichever screen the thing ended up on.
        function close(): string {
            for (const win of Shell.windows)
                win.clipboard.hide();
            return "closed";
        }

        // The history as text, one entry per line, newest first: index, kind,
        // whether it is kept, and enough of the content to recognise. Truncated
        // to one line per entry ON PURPOSE, because the values are arbitrary and
        // a copied file with newlines in it would otherwise write its own rows.
        function list(): string {
            const rows = Clipboard.entries.map((e, i) => {
                const what = Clipboard.summarise(e).replace(/\s+/g, " ").trim();
                return `${i}\t${e.pinned ? "*" : " "}\t${e.kind}\t${what.slice(0, 120)}`;
            });
            return rows.join("\n");
        }

        // BACK ONTO THE CLIPBOARD, by the index `list` printed.
        function use(index: string): string {
            const at = parseInt(index, 10);
            const entry = Clipboard.entries[at];
            if (!entry)
                return `no entry ${index}`;
            Clipboard.copy(entry);
            return `copied ${entry.kind}: ${Clipboard.summarise(entry).slice(0, 80)}`;
        }

        function pin(index: string): string {
            const at = parseInt(index, 10);
            const entry = Clipboard.entries[at];
            if (!entry)
                return `no entry ${index}`;
            Clipboard.setPinned(entry, !entry.pinned);
            return entry.pinned ? "let go" : "kept";
        }

        function remove(index: string): string {
            const at = parseInt(index, 10);
            const entry = Clipboard.entries[at];
            if (!entry)
                return `no entry ${index}`;
            Clipboard.remove(entry);
            return "removed";
        }

        // Everything loose. Pinned entries survive, which is the whole point of
        // a pin and is why this does not need a confirmation.
        function clear(): string {
            const before = Clipboard.entries.length;
            Clipboard.clear();
            return `cleared ${before - Clipboard.entries.length}, kept ${Clipboard.entries.length}`;
        }

        // Whether the thing is actually recording, which is the question a
        // clipboard that has quietly stopped cannot answer any other way: a
        // history that is not growing looks exactly like an afternoon in which
        // nothing was copied.
        //
        // Everything here but `open` is the service's and is one answer for the
        // session. `open` is a window's, so it is read off whichever window has
        // the panel out: a line saying open=false with the panel sitting on the
        // other monitor would be the one field in it that lies.
        function status(): string {
            const win = Shell.showing(w => w.clipboard.open);
            const kinds = {};
            for (const e of Clipboard.entries)
                kinds[e.kind] = (kinds[e.kind] ?? 0) + 1;
            const tally = Object.keys(kinds).sort().map(k => `${k}=${kinds[k]}`).join(" ");
            return `recording=${Clipboard.recording} entries=${Clipboard.entries.length} pinned=${Clipboard.entries.filter(e => e.pinned).length} open=${win?.clipboard.open ?? false} ${tally}`;
        }
    }

    // The power panel. Opened on the screen the keyboard is on, the same way
    // every other handler here works: a question about ending the session is
    // asked of the person, and the person is at the monitor they are looking at,
    // not at whichever one the compositor enumerated first. It used to land on
    // window zero, which is a fact about the order the outputs came up in and
    // reads as correct right up until there are two of them.
    //
    // Putting it away is the other half and is not the same question: see the
    // toggle, and Shell.showing for the whole of the argument.
    IpcHandler {
        target: "session"

        function toggle(): string {
            const win = Shell.showing(w => w.session.open);
            if (!win)
                return "no shell window";
            win.session.toggle();
            return win.session.open ? "open" : "closed";
        }

        function open(): string {
            Shell.forScreen("")?.session.show();
            return "open";
        }

        function close(): string {
            for (const win of Shell.windows)
                win.session.hide();
            return "closed";
        }
    }

    // The media controller: Super+M's popup. The panel's own keys (space, the
    // arrows) do the media; this target only decides whether the card is out,
    // on the power panel's exact shape - summoned by name, so the toggle goes
    // through Shell.showing and finds the one already up.
    IpcHandler {
        target: "media"

        function toggle(): string {
            const win = Shell.showing(w => w.media.open);
            if (!win)
                return "no shell window";
            win.media.toggle();
            return win.media.open ? "open" : "closed";
        }

        function open(): string {
            Shell.forScreen("")?.media.show();
            return "open";
        }

        function close(): string {
            for (const win of Shell.windows)
                win.media.hide();
            return "closed";
        }

        // What the card would say, without the card: the player it is pointed
        // at and the state of the card itself. The shell-side half is
        // session-wide (Media picks one player for the whole session); open is
        // read off the window holding the card, per the rule at the top of
        // this file.
        function status(): string {
            const win = Shell.showing(w => w.media.open);
            return `open=${win?.media.open ?? false} player=${Media.app || "none"} playing=${Media.playing} title="${Media.title}"`;
        }
    }

    // The calculator, driven exactly like the power panel above and for the same
    // reason: it is summoned by name from wherever you were, so it arrives on the
    // screen you were at when you asked, while `close` reaches every screen
    // because "put it away" is not a question about a monitor. The verbs that
    // toggle go through Shell.showing instead, since a panel that already exists
    // is a thing rather than a place.
    //
    // THIS IS ALSO WHAT THE .desktop ENTRY RUNS. A desktop file is a keybind
    // somebody else's menu owns, so the route has to be the CLI rather than
    // anything that assumes a shell already has the pointer: see
    // assets/applications/banditshell-calculator.desktop, which is nothing but
    // `banditshell calculator`.
    IpcHandler {
        target: "calculator"

        function toggle(): string {
            const win = Shell.showing(w => w.calculator.open);
            if (!win)
                return "no shell window";
            win.calculator.toggle();
            return win.calculator.open ? "open" : "closed";
        }

        function open(): string {
            Shell.forScreen("")?.calculator.show();
            return "open";
        }

        function close(): string {
            for (const win of Shell.windows)
                win.calculator.hide();
            return "closed";
        }

        // THE SAME CALCULATOR WITH THE WHOLE SCREEN, which is what the .desktop
        // entry runs: launched by name from an application menu it should behave
        // like an application, standing over the desktop rather than clinging to
        // the sidebar the way the key's panel does.
        //
        // A TOGGLE, unlike `open` above, because a desktop entry launched twice
        // has to put its window away: that is the contract every other summoner
        // in this shell keeps and the one an application menu most obviously
        // assumes. Toggling on the SHAPE and not just on open-ness, so `app`
        // while the flank panel is out promotes it instead of closing it; the
        // entry says "Calculator", and answering a request for the big one by
        // putting the small one away would be the entry doing the opposite of
        // what it says.
        //
        // Which means it is asking about a calculator that may already exist, so
        // it goes through Shell.showing like the plain toggle: launched a second
        // time from a menu on the other monitor, this has to find the window it
        // put up the first time. With nothing out anywhere the fallback is the
        // focused screen, and the launch behaves like a summon, which it is.
        function app(): string {
            const win = Shell.showing(w => w.calculator.open);
            if (!win)
                return "no shell window";
            if (win.calculator.open && win.calculator.full)
                return close();
            win.calculator.app();
            return "open";
        }

        // Its twin, for symmetry and for a keybind that wants the small one
        // whatever you were last in. Same toggle rule, read the same way, and
        // aimed at the same window for the same reason.
        function panel(): string {
            const win = Shell.showing(w => w.calculator.open);
            if (!win)
                return "no shell window";
            if (win.calculator.open && !win.calculator.full)
                return close();
            win.calculator.panel();
            return "open";
        }

        // Which shape it is in, and whether it is out at all. The one question a
        // script cannot otherwise ask, and the one the two verbs above are
        // deciding on, so it has to be asked of the same window they act on:
        // a status that disagreed with `app` about where the calculator is would
        // be worse than no status at all.
        function status(): string {
            const win = Shell.showing(w => w.calculator.open);
            return `open=${win?.calculator.open ?? false} shape=${win?.calculator.full ? "app" : "panel"}`;
        }

        // WHAT IS ON THE LINE, so the panel is scriptable in the one way a
        // calculator can be: `banditshell calculator answer "2+3*4"` prints 14
        // without a surface being involved at all. Straight through the same
        // service the panel and the launcher use, so a terminal cannot be told a
        // different answer from a screen.
        function answer(expression: string): string {
            const result = Calc.evaluate(expression);
            return result ? result.text : `not an expression: ${expression}`;
        }
    }

    // THE HINGE. This target is not really for a person: it is the door the
    // COMPOSITOR knocks on.
    //
    // A convertible reports its fold as an evdev switch, and the shell cannot
    // read that device (the nodes are root:input and this user is deliberately
    // not in that group; scripts/tablet-state.py argues the case). Hyprland
    // already has it open, so the fold arrives as a `switch:on:` bind that execs
    // `banditshell tablet on`, which lands here. That is the whole mechanism,
    // and it is why the verbs are `on`/`off` rather than something more
    // conversational: they are named after the switch, not after a mood.
    //
    // NOT PER-SCREEN, unlike every panel target above. A hinge is a fact about
    // the machine rather than about a monitor, so there is nothing to name and
    // nothing to choose.
    IpcHandler {
        target: "tablet"

        // WHO IS CALLING, as an argument, because "the hinge moved" and
        // "somebody typed a command" are different facts and `status` is the
        // only place either one can be seen. The switch binds pass
        // `compositor`; a person passes nothing and gets `cli`. Reporting both
        // as `cli` (which is what this did at first) makes the one diagnostic
        // this service has useless for the one failure it is meant to catch,
        // which is a switch bind that has silently stopped firing.
        function on(from: string): string {
            return Tablet.apply("on", from || "cli");
        }

        function off(from: string): string {
            return Tablet.apply("off", from || "cli");
        }

        function toggle(from: string): string {
            return Tablet.apply("toggle", from || "cli");
        }

        // THE LID, which on this chassis is half of the hinge's answer: the
        // Yoga switch trips at 0 degrees as well as at 360, so a closed lid is
        // what tells the shell that a "fold" was somebody shutting the laptop.
        // See services/Tablet.qml. The lid bind passes `compositor` for the
        // same reason the fold binds do.
        function lid(state: string, from: string): string {
            return Tablet.applyLid(state, from || "cli");
        }

        // WHERE THE BELIEF CAME FROM, and not just what it is. `folded` is false
        // both when the machine is flat and when nothing has managed to tell the
        // shell anything, and those two are worth telling apart: a fold that
        // never arrives is a switch bind that is not firing, and this line is
        // how that gets diagnosed without attaching a debugger to a compositor.
        function status(): string {
            const state = Tablet.folding ? "folded" : "flat";
            const hinge = `${Tablet.known ? "known" : "assumed"}, via ${Tablet.source}`;
            const lid = `${Tablet.lidClosed ? "closed" : "open"}, ${Tablet.lidKnown ? "known" : "assumed"}, via ${Tablet.lidSource}`;
            // BOTH DEVICES, because `folded` is now the AND of them and a line
            // reporting only the hinge could no longer explain its own answer:
            // a switch that says folded and a shell that says flat is the lid
            // doing its job, and this is where that is visible.
            return `${state} (hinge ${Tablet.hinge ? "on" : "off"}, ${hinge}; lid ${lid})`;
        }
    }

    // THE BOARD ITSELF, separately from the hinge, because the two are genuinely
    // different questions and conflating them would remove the useful cases at
    // both ends: a keyboard on an unfolded machine (a bind, when the real one is
    // across the desk) and a folded machine with no keyboard (reading something,
    // where the board is just in the way).
    IpcHandler {
        target: "keyboard"

        // Named, that screen; unnamed, the screen the BOARD is on, the way every
        // toggle in this file resolves (Shell.showing says why). There is one
        // pair of hands and there should be one board: asking the focused window
        // instead would answer a second press from the other monitor by putting
        // up a second keyboard while the first one stayed where it was.
        function toggle(screen: string): string {
            const win = screen ? Shell.forScreen(screen) : Shell.showing(w => w.keyboard.open);
            if (!win)
                return "no shell window";
            win.keyboard.toggle();
            return win.keyboard.open ? "open" : "closed";
        }

        function open(screen: string): string {
            const win = Shell.forScreen(screen);
            if (!win)
                return "no shell window";
            win.keyboard.show();
            return "open";
        }

        // EVERY SCREEN, like every other `close` here: "put it away" is not a
        // question about a monitor.
        function close(): string {
            for (const win of Shell.windows)
                win.keyboard.hide();
            return "closed";
        }

        // WHICH PAGE IS UP, as well as whether the board is. The page is the
        // only piece of the board's state that persists across a hide, so it is
        // the only one worth reporting. Unnamed, it answers for the board that
        // is out rather than for the focused screen's, so that it and the toggle
        // above can never be talking about different keyboards.
        function status(screen: string): string {
            const win = screen ? Shell.forScreen(screen) : Shell.showing(w => w.keyboard.open);
            if (!win)
                return "no shell window";
            return `${win.keyboard.open ? "open" : "closed"} on "${win.keyboard.page}"`;
        }

        // DOES THE BOARD TAKE UP ROOM. Not per-screen for the same reason the
        // hinge is not: it is one preference about how the keyboard behaves,
        // and a board that reserved space on one monitor and floated on another
        // would be two different keyboards.
        function dock(): string {
            Tablet.setDocked(true);
            return "docked";
        }

        function float(): string {
            Tablet.setDocked(false);
            return "floating";
        }

        // The board that is out, when none is named, for `launcher scrub`'s
        // reason: this drives a control on a surface someone is looking at, and
        // aiming it at the focused screen would quietly repage a hidden board
        // while the visible one carried on showing the letters.
        function page(name: string, screen: string): string {
            const win = screen ? Shell.forScreen(screen) : Shell.showing(w => w.keyboard.open);
            if (!win)
                return "no shell window";
            win.keyboard.page = name;
            return `page ${name}`;
        }
    }

    // The hotkey sheet: every bind the compositor knows about, read off it
    // rather than out of a list in this repo. Driven exactly like the power
    // panel above, and for the same reason: it is summoned by name from
    // wherever you were, so it arrives on the screen you asked from, and
    // `close` reaches every screen because "put it away" is not a question
    // about a monitor.
    //
    // This is also the target that the keybind actually goes through. The sheet
    // is the one panel here whose whole content is the user's own config, so it
    // has to be openable the moment that config changes, without the shell
    // being restarted or knowing anything about which key was pressed.
    //
    // AN OPTIONAL SCREEN, exactly as `menu open` takes one, and the empty string
    // means the screen you are on, so every keybind and every line of
    // docs/hyprland-binds.example.conf goes on meaning what it meant. The
    // paragraph above is about the DEFAULT and it stands, with the default now
    // reading the focus instead of the order the outputs came up in: a sheet you
    // summoned by name belongs under the eyes that asked for it. What it was
    // never an argument for is the sheet being the one panel in this file that
    // CANNOT be named a screen, which is what it had become:
    // `menu` and `settings` both take one, so a sweep can put them on a headless
    // output and photograph them there, and this panel alone had to be opened on
    // the user's own display, over the user's own work, to be looked at at all.
    // A default is not the same thing as a restriction.
    IpcHandler {
        target: "hotkeys"

        // NAMED, that screen; unnamed, the screen the sheet is ON. A sheet is a
        // summoned panel like the launcher and the power panel, so a second
        // press means the one already up: without that, reading the sheet on one
        // monitor and pressing the bind while looking at the other would put a
        // second sheet up rather than take the first one down. `open` below
        // keeps meaning here, because it has nothing to find.
        function toggle(screen: string): string {
            const win = screen ? Shell.forScreen(screen) : Shell.showing(w => w.hotkeys.open);
            if (!win)
                return screen ? `no shell window on screen: ${screen}` : "no shell window";
            win.hotkeys.toggle();
            return win.hotkeys.open ? "open" : "closed";
        }

        // GUARDED, unlike the power panel's `open` just above, which answers
        // "open" whether or not there was a window to open anything on. Both
        // shapes are in this file and this is the better one: the header's rule
        // is that a CLI printing nothing on success cannot be told from one that
        // did nothing, and a CLI printing "open" over an empty screen is worse
        // than either.
        function open(screen: string): string {
            const win = Shell.forScreen(screen);
            if (!win)
                return screen ? `no shell window on screen: ${screen}` : "no shell window";
            win.hotkeys.show();
            return "open";
        }

        // No screen here, deliberately, and `menu close` is written the same way:
        // "put it away" is not a question about a monitor, and a close that
        // needed to be told which screen would leave a sheet up on the one you
        // forgot to name.
        function close(): string {
            for (const win of Shell.windows)
                win.hotkeys.hide();
            return "closed";
        }

        // WHAT IT READ, not just whether it is up, because the failure this
        // panel actually has is a sheet full of chords with nothing beside them,
        // and from a screenshot that looks the same whatever caused it. `binds`
        // separates "hyprctl said nothing" from "hyprctl said plenty";
        // `described` separates a config full of `bindd` from one whose binds
        // are registered from Lua or a plugin, which Hyprland reports with no
        // dispatcher this side can read. On this machine that second number is
        // 1 out of 82, and knowing it is the compositor's answer rather than the
        // sheet's parsing is the whole point of printing it.
        //
        // Unnamed, it reads the sheet that is UP: the counts are the same on
        // every screen because every sheet asks the same compositor, but `open`
        // is not, and a status reporting open=false about a sheet filling the
        // next monitor is the one line here that could mislead.
        function status(screen: string): string {
            const win = screen ? Shell.forScreen(screen) : Shell.showing(w => w.hotkeys.open);
            if (!win)
                return screen ? `no shell window on screen: ${screen}` : "no shell window";
            return `open=${win.hotkeys.open} binds=${win.hotkeys.rows.length} described=${win.hotkeys.rows.length - win.hotkeys.unnamed} groups=${win.hotkeys.sections.length}`;
        }
    }

    // The notification tray. The CLI takes the pull gesture's seat, not
    // hover's: it writes the PIN, the one input in the tray's presence union
    // that means "deliberately held out" (see NotificationTray.expanded). A
    // separate shown flag written from here was rejected because presence is a
    // derived union with exactly one deliberate writer; a second one would
    // fight the gesture, and a tray opened by hotkey would stop answering the
    // pull that is supposed to put it away. Through the pin, a hotkey and a
    // pull land in the same state and leave by the same doors.
    //
    // AN OPTIONAL SCREEN on every verb that pins one, exactly as `hotkeys` and
    // `menu` take one, with the empty string meaning the screen you are on so
    // every existing keybind goes on meaning what it meant. The paragraph above
    // is about WHICH INPUT the CLI stands in for and it is untouched; what the
    // tray had additionally become was the panel that could only be pinned on
    // Shell.windows[0], and that is a restriction nobody argued for.
    //
    // AND THE TOGGLE STAYS ON THE SCREEN YOU ARE ON, which is the one place in
    // this file where a toggle does not go hunting for the thing it toggles (see
    // Shell.showing). Every panel above is summoned and therefore singular: one
    // launcher, one sheet, one power menu, and a second press is about the one
    // that exists. A tray is not summoned, it is FURNITURE, standing in the
    // corner of every screen at once, and its pin is a per-screen fact about a
    // per-screen object. "Hold this monitor's tray out" is a sentence with an
    // answer on each monitor, so the pin belongs where the keyboard is and a
    // tray held out elsewhere is none of this press's business. The notch below
    // is the same shape for the same reason.
    //
    // It was found by a sweep that could not photograph the expanded tray at
    // all. A screenshot goes to a throwaway headless output and never to the
    // user's own screen, so a panel that can only be pinned on window zero is a
    // panel that can only be looked at over the user's work: the pin landed on
    // eDP-1 while the camera was pointed at a headless output, and the shot came
    // back correctly showing an empty corner. The tray's own popup path put a
    // card on every screen and covered the card, but the PINNED, expanded tray,
    // which is the whole of what this verb exists to produce, had no way to be
    // seen. A default is not the same thing as a restriction, which is the
    // sentence `hotkeys` above already had to be taught.
    //
    // `close` and `clear` stay screenless for their own reasons, written at
    // each.
    IpcHandler {
        target: "notifications"

        function open(screen: string): string {
            const win = Shell.forScreen(screen);
            if (!win)
                return screen ? `no shell window on screen: ${screen}` : "no shell window";
            win.notifications.pinned = true;
            return "open";
        }

        // The pin is withdrawn on every screen, like `menu close`: "make it go
        // away" is not a request about a particular monitor. The tray may
        // still stand a moment where a cursor is resting on it, and that is
        // hover's vote to cast, not this one's to override.
        function close(): string {
            for (const win of Shell.windows)
                win.notifications.pinned = false;
            return "closed";
        }

        function toggle(screen: string): string {
            const win = Shell.forScreen(screen);
            if (!win)
                return screen ? `no shell window on screen: ${screen}` : "no shell window";
            win.notifications.pinned = !win.notifications.pinned;
            return win.notifications.pinned ? "open" : "closed";
        }

        // Through the service rather than the tray, because the history is one
        // list for the whole session whichever screen happens to draw it.
        function clear(): string {
            Notifs.clear();
            return "cleared";
        }

        // Pin and presence SEPARATELY, because them disagreeing is the failure
        // this line exists to catch: expanded without the pin is hover holding
        // the tray, which is fine, and pinned without expanded is the derived
        // union dropping a term, which is a bug you could otherwise only infer.
        //
        // NAMEABLE, because that failure is a per-window one: `pinned` and
        // `expanded` are read off a particular tray, so a status that could only
        // ever read window zero's could not tell you whether the tray you just
        // pinned somewhere else had actually come out. `count` is the service's
        // and is the same number whichever window answers.
        function status(screen: string): string {
            const win = Shell.forScreen(screen);
            if (!win)
                return screen ? `no shell window on screen: ${screen}` : "no shell window";
            return `count=${Notifs.count} pinned=${win.notifications.pinned} expanded=${win.notifications.expanded}`;
        }

        // WHETHER A PERSON IS CURRENTLY ENGAGED WITH THIS SENDER'S CARD, which
        // the shell knows and the sender cannot possibly infer.
        //
        // It exists for senders that could update at any rate and have to pick
        // one. A download that redraws every two seconds is thrift on a card
        // nobody is reading, and reads as FROZEN under a cursor that came to
        // read it; the sender wants to spend its updates exactly where they are
        // being watched, and this is the only way to find out where that is.
        //
        // Answers for one app, because "is MY card held" is the only form of
        // the question a sender can act on: it knows nothing about anyone
        // else's cards and has no business being told about them.
        //
        // `held` rather than `hovered` because the card's own union is the
        // right one. Hover, a drag in progress and a card deliberately pinned
        // open all mean the same thing to a sender, which is that the card is
        // being attended to right now.
        //
        // Both lists, since a card can be held in the popup stack or in the
        // hub, and to the sender those are the same event.
        function held(app: string): string {
            if (!app)
                return "0";
            const key = app.toLowerCase();
            const attended = e => e?.held && (e.appName ?? "").toLowerCase() === key;
            return Notifs.popups.some(attended) || Notifs.history.some(attended) ? "1" : "0";
        }
    }

    // The top notch, the same shape as the tray above and for the same reason:
    // the CLI writes the PIN and nothing else. `active` is the notch's derived
    // union (hover, pull, pin), so `open` holds the notch out the way a pull
    // does, and a cursor already resting on it keeps its own say when the pin
    // is taken back.
    //
    // THE SAME SHAPE INCLUDES THE SCREEN, which is the whole reason to say
    // "the same shape" rather than to write the four functions out twice. The
    // notch is pinned per window exactly as the tray is, it is photographed the
    // same way and therefore cannot be photographed for the same reason, and a
    // handler that read window zero alone while the one above it took a name
    // would leave that sentence false the day someone relied on it.
    IpcHandler {
        target: "notch"

        function open(screen: string): string {
            const win = Shell.forScreen(screen);
            if (!win)
                return screen ? `no shell window on screen: ${screen}` : "no shell window";
            win.notch.pinned = true;
            return "open";
        }

        function close(): string {
            for (const win of Shell.windows)
                win.notch.pinned = false;
            return "closed";
        }

        function toggle(screen: string): string {
            const win = Shell.forScreen(screen);
            if (!win)
                return screen ? `no shell window on screen: ${screen}` : "no shell window";
            win.notch.pinned = !win.notch.pinned;
            return win.notch.pinned ? "open" : "closed";
        }

        function status(screen: string): string {
            const win = Shell.forScreen(screen);
            if (!win)
                return screen ? `no shell window on screen: ${screen}` : "no shell window";
            return `pinned=${win.notch.pinned} active=${win.notch.active}`;
        }
    }

    // The settings page. Driven off the singleton rather than off a window,
    // unlike everything above it: the page is ONE page for the whole session,
    // which screen draws it is its own business, and half the time no shell
    // window is drawing it at all because it has been pulled out into a window.
    IpcHandler {
        target: "settings"

        function toggle(): string {
            Settings.toggle();
            return Settings.open ? "open" : "closed";
        }

        // `page` is optional and names what the panel opens TO. Validated here
        // rather than trusted to the service, because the caller is a keybind
        // or a script: a typo that silently opened the panel on whatever page
        // it last showed would look exactly like success. Naming a page also
        // has to mean naming it when the panel is ALREADY up, so setPage runs
        // as well: show carries the page for the summon, and setPage covers
        // the panel that was open all along, which show leaves untouched.
        //
        // `screen` is optional too and names where the summon lands, the same
        // way `menu open` takes one: a gesture opens things under the cursor,
        // but IPC has no cursor, and this used to hand show a hardcoded ""
        // so a script could only ever summon the panel onto the focused
        // screen. That made the panel impossible to photograph whenever the
        // focused screen was busy (a fullscreen window draws over every layer
        // surface), which is exactly the kind of untestability this file
        // exists to remove. Validated for the page's reason: show accepts any
        // string and would assign the panel to a screen that does not exist,
        // drawing it nowhere while this function reports "open". Only the
        // SUMMON is steered; a panel already up stays on its screen, matching
        // how show treats the argument, because teleporting a panel someone
        // is looking at is a stranger outcome than ignoring the request.
        function open(page: string, screen: string): string {
            if (page && !Settings.pages.some(p => p.key === page))
                return `no such page: ${page} (have: ${Settings.pages.map(p => p.key).join(", ")})`;
            if (screen && !Shell.forScreen(screen))
                return `no shell window on screen: ${screen}`;
            Settings.show(screen, page);
            if (page)
                Settings.setPage(page);
            return page ? `open at ${page}` : "open";
        }

        function close(): string {
            Settings.hide();
            return "closed";
        }

        // Change the page without touching presence, so a keybind can walk the
        // panel while it stays put. An unknown key answers with the keys that
        // exist: they live in the service, and a CLI error that does not name
        // the valid inputs sends you source diving for a string. Bare, it
        // reads the page back instead of erroring, because "which page is it
        // on" is a question worth one word.
        function page(key: string): string {
            if (!key)
                return Settings.page || "no page";
            if (!Settings.pages.some(p => p.key === key))
                return `no such page: ${key} (have: ${Settings.pages.map(p => p.key).join(", ")})`;
            Settings.setPage(key);
            return `page ${key}`;
        }

        // The two halves of the handover, by name rather than as a flag, for the
        // same reason the picker has four verbs: a keybind is a string, and a
        // flag in a keybind is a thing to get wrong once and never notice.
        //
        // `pull` needs a rect and takes none: it uses the one the card is
        // actually occupying, which is the only rect that makes the handover
        // invisible and is not something a caller could know.
        function pull(): string {
            const win = Shell.forScreen(Settings.screenName);
            if (!Settings.open || Settings.floating)
                return "not on the shell";
            if (!win)
                return `no shell window on screen: ${Settings.screenName}`;
            win.settings.popOut();
            return "pulled out";
        }

        function put(): string {
            if (!Settings.floating)
                return "not in a window";
            Settings.popIn();
            return "put back";
        }

        // Which of the two is holding it, and where. The whole failure mode this
        // feature has is the two halves disagreeing about who is drawing, and
        // from a screenshot that looks identical to nothing being open at all.
        function status(): string {
            return [`open       ${Settings.open}`, `page       ${Settings.page || "-"}`, `held by    ${Settings.floating ? "a window" : "the shell"}`, `screen     ${Settings.screenName || "-"}`, `window     ${Settings.windowOpen ? Settings.address || "opening" : "none"}`, `placed     ${Settings.placed}`, `handoff    ${Settings.handoff ? `${Settings.handoff.x},${Settings.handoff.y} ${Settings.handoff.w}x${Settings.handoff.h}` : "-"}`].join("\n");
        }
    }

    // One wheel notch, signed, shared by `up` and `down` so the comment about
    // what a step IS lives once. The step is Appearance's volumeStep, the same
    // five points the wheel and the sound menu's slider move by, because a
    // key, a wheel and a slider are one control on one value and a keybind
    // that moved by its own private amount would be a second control. `count`
    // lets a bind be a bigger jump without becoming a different verb;
    // anything unparseable or non-positive is one step.
    //
    // The reply is the value that was ASKED for, not the node read back:
    // PipeWire confirms on its own schedule, and the property on this same
    // tick can still be the old number wearing a straight face.
    function nudgeVolume(sign: int, count: string): string {
        if (!Audio.ready)
            return "no audio sink";
        const n = parseFloat(count);
        const steps = n > 0 ? n : 1;
        const target = Audio.quantise(Audio.volume + sign * steps * Appearance.sizes.volumeStep);
        Audio.setVolume(target);
        return `${Math.round(target * 100)}%`;
    }

    IpcHandler {
        target: "files"

        // The browser is a window rather than a panel, so "where" is not a
        // question here the way it is for the menus: a window is wherever it was
        // dragged to. What it takes instead is a PATH, because the useful thing
        // to bind is not "open the browser" but "open the browser here", and a
        // keybind that carries the directory it was pressed in is the difference
        // between a file manager and a file manager you actually reach for.
        function open(path: string): string {
            Files.show(path);
            return path ? `files ${path}` : "files";
        }

        function toggle(path: string): string {
            Files.toggle(path);
            return Files.windowOpen ? "open" : "closed";
        }

        function close(): string {
            Files.hide();
            return "closed";
        }

        // What the browser currently believes, in one line. The same reasoning
        // as `menu hover`: "the terminal is not responding" and "the terminal
        // was never started" look identical from a screenshot, and so do "the
        // grid is empty" and "the listing failed".
        function status(): string {
            const shell = Files.term ? `rows=${Files.term.rows} alt=${Files.term.altActive}` : "no session";
            return `open=${Files.windowOpen} cwd=${Files.cwd} entries=${Files.entries.length} focus=${Files.focus} terminal=[${shell}] error=[${Files.error}]`;
        }
    }

    // The output volume, driven through the Audio singleton the way settings
    // is driven through its own: sound is one value for the session, not a
    // per-window thing, so there is no window to guard for. No drawing here
    // either, and none needed: the volume rail's linger restarts on ANY change
    // to Audio.volume, whoever made it, so a hotkey through this handler gets
    // the same on-screen readout a wheel notch gets, for free.
    IpcHandler {
        target: "volume"

        function up(count: string): string {
            return root.nudgeVolume(1, count);
        }

        function down(count: string): string {
            return root.nudgeVolume(-1, count);
        }

        // `pct` is percent OF THE NORMAL RANGE: 100 means volume 1.0, full and
        // unamplified, so the numbers here mean what a mixer's numbers mean
        // everywhere else. Percent of the ceiling was rejected because then
        // `set 100` would be +50% amplification and nothing else on the
        // machine would agree with this CLI about what 67 sounds like. Values
        // above 100 still work and reach into the same headroom the slider
        // has; quantise clamps them to the ceiling.
        function set(pct: string): string {
            if (!Audio.ready)
                return "no audio sink";
            const n = parseFloat(pct);
            if (!isFinite(n))
                return `not a number: ${pct}`;
            const target = Audio.quantise(n / 100);
            Audio.setVolume(target);
            return `${Math.round(target * 100)}%`;
        }

        // Bare, it toggles, which is what a mute KEY means. `on` and `off`
        // exist for scripts, which cannot see the screen: a toggle is only a
        // mute button when you know the state it started from. The reply is
        // the state that was asked for, computed here rather than read back,
        // for the same reason the nudge replies with its target.
        function mute(state: string): string {
            if (!Audio.ready)
                return "no audio sink";
            if (state && state !== "on" && state !== "off")
                return `mute takes on or off, not: ${state}`;
            const want = state === "on" || (state !== "off" && !Audio.muted);
            if (want !== Audio.muted)
                Audio.toggleMute();
            return want ? "muted" : "unmuted";
        }

        // The ceiling is part of the answer because the range above 100 is
        // real: a readout of 130% is only alarming if you cannot see that the
        // scale runs to 150.
        function status(): string {
            if (!Audio.ready)
                return "no audio sink";
            return `volume=${Math.round(Audio.volume * 100)}% muted=${Audio.muted} ceiling=${Math.round(Audio.maxVolume * 100)}%`;
        }
    }

    // The reply every verb of the output target gives: the role, AND the device
    // that role currently means.
    //
    // Shared so a role reached by a key and the same role named on a command
    // line come back in exactly the same words. "headphones" on its own is the
    // CLI repeating what it was asked rather than saying what happened; the
    // label after it is the part that shows the shell and the hardware agree
    // about which box the sound just moved to.
    function roleLine(role: string): string {
        const node = Audio.roleNode(role);
        return node ? `${role} (${Audio.deviceLabel(node)})` : role;
    }

    // Named-role switching, for `speakers` and `headphones`, which are one verb
    // called twice rather than two verbs.
    function goRole(role: string): string {
        const landed = Audio.setOutputRole(role);
        return landed ? root.roleLine(landed) : `cannot switch to ${role}: ${Audio.roleProblem(role)}`;
    }

    // THE OUTPUT, as one key.
    //
    // Speakers or headphones is the audio question a keyboard actually gets
    // asked, and the one the volume keys cannot answer: they can turn the sound
    // down, not move it. Which sink each name means is a setting, because no
    // two machines have the same cards in them (config/Config.qml's `audio`
    // block), so this target is both the switch and the way to wire the switch
    // up: `list` prints the names, `assign` writes one, `toggle` is the verb to
    // bind.
    //
    // Nothing here draws anything, and nothing needs to. Moving the default
    // sink changes Audio.volume for the new device, and the volume rail's
    // linger restarts on any change to it whoever made it, so the switch shows
    // itself on screen the same way a wheel notch does.
    IpcHandler {
        target: "output"

        function toggle(): string {
            const landed = Audio.toggleOutput();
            if (landed)
                return root.roleLine(landed);
            if (Audio.rolesCollide)
                return "speakers and headphones name the same device, so there is nowhere to toggle to";
            // Standing on one of the two, only the OTHER one refused and it is
            // the only one worth a sentence. Standing on neither, both refused,
            // and both reasons print: the fix is a different sentence for each,
            // and a key that reported one of them would send you to plug in a
            // device that was never the problem.
            if (Audio.outputRole) {
                const other = Audio.outputRole === "speakers" ? "headphones" : "speakers";
                return `cannot switch to ${other}: ${Audio.roleProblem(other)}`;
            }
            return `cannot switch: speakers ${Audio.roleProblem("speakers")}; headphones ${Audio.roleProblem("headphones")}`;
        }

        // Where you asked for, regardless of where you are. The same argument
        // `volume mute on|off` makes one target up: a toggle is only a switch
        // when you can see the state it started from, and a script cannot.
        function speakers(): string {
            return root.goRole("speakers");
        }

        function headphones(): string {
            return root.goRole("headphones");
        }

        // Which role is playing, and what both of them resolve to right now.
        //
        // Both, always, including the one you are on, because the question this
        // gets asked is "why did the key do nothing" and the answer is nearly
        // always on the line for the role you are NOT standing on: a name that
        // was never set, or a device that is set and asleep in a drawer.
        function status(): string {
            const say = role => {
                const name = Audio.roleName(role);
                if (!name)
                    return "not assigned";
                const node = Audio.roleNode(role);
                return node ? `${Audio.deviceLabel(node)} · ${name}` : `${name} · not connected`;
            };

            const on = Audio.outputRole || (Audio.sink ? `neither, playing through ${Audio.deviceLabel(Audio.sink)}` : "no output device");
            const lines = [`playing     ${on}`, `speakers    ${say("speakers")}`, `headphones  ${say("headphones")}`];
            if (Audio.rolesCollide)
                lines.push("both roles name one device, so the toggle cannot move the sound");
            return lines.join("\n");
        }

        // NAME FIRST, because the name is the string you copy into `assign` and
        // a list that led with the label would make you hunt for it. What each
        // one is doing is in brackets after it, since the reason to run this is
        // usually to find out why a role resolved to nothing.
        function list(): string {
            if (!Audio.sinks.length)
                return "no output devices";
            return Audio.sinks.map(n => {
                const marks = [n.name === Audio.sink?.name ? "playing" : "", n.name === Audio.speakersName ? "speakers" : "", n.name === Audio.headphonesName ? "headphones" : ""].filter(m => m);
                return `${n.name}  ${Audio.deviceLabel(n)}${marks.length ? ` [${marks.join(", ")}]` : ""}`;
            }).join("\n");
        }

        // Write the setting. An empty name unassigns, which is the one edit the
        // settings page and this verb both have to be able to make: a role
        // pointing at a device that is gone for good is worse than a role
        // pointing at nothing, because only one of the two says so.
        //
        // A NAME THAT MATCHES NO SINK IS STILL WRITTEN, and still reported. It
        // is how you assign a device that is unplugged this minute, and
        // refusing it would mean the headphones can only be set up while they
        // are on. The reply is where a typo shows: the name comes back with a
        // note that nothing here answers to it.
        function assign(role: string, name: string): string {
            if (role !== "speakers" && role !== "headphones")
                return `assign takes speakers or headphones, not: ${role}`;
            Config.set(`audio.${role}`, name);
            if (!name)
                return `${role} unassigned`;
            const node = Audio.sinkByName(name);
            return node ? `${role} = ${Audio.deviceLabel(node)} (${name})` : `${role} = ${name}, which is not a sink that is here right now`;
        }
    }

    // THE WALLPAPER. Every verb here is a write to config.json that `set` could
    // already make, and that is exactly why the target exists: a keybind cannot
    // read a value before writing it, so "the other one" and "the opposite of
    // whatever it is now" are the two things a setter can never be asked for
    // from a key. `toggle` and `next` are those two questions; `on`, `off` and
    // `status` are here so the target answers the whole question rather than
    // only the halves a hotkey needs.
    IpcHandler {
        target: "wallpaper"

        function toggle(): string {
            Wallpaper.toggle();
            return Wallpaper.enabled ? "on" : "off";
        }

        function on(): string {
            Wallpaper.setEnabled(true);
            return "on";
        }

        function off(): string {
            Wallpaper.setEnabled(false);
            return "off";
        }

        // Through the list, wrapping, which is what the shell has instead of a
        // picker. Silent about the switch on purpose: changing wallpaper while
        // it is turned off is a perfectly sensible thing to do, and the answer
        // says which one it landed on rather than whether you can see it.
        //
        // ON ONE SCREEN unless told otherwise, which is the change per-screen
        // wallpapers make to this pair. Held down, `wallpaper next` walks the
        // folder on the monitor you are looking at and leaves the others alone;
        // `wallpaper next all` walks the whole desk together, off the default
        // rather than off each screen's own, so screens that had drifted apart
        // do not drift further with every press.
        function next(screen: string): string {
            return root.walkWallpaper(screen, 1);
        }

        function prev(screen: string): string {
            return root.walkWallpaper(screen, -1);
        }

        // PUT THIS PICTURE ON THAT SCREEN, which is the verb the picker's
        // gesture already was and which the CLI had no way to say.
        //
        // `banditshell set wallpaper.current <path>` still exists and still
        // means the DEFAULT, which is the honest reading of a key called
        // `current` in a file: it is the one every screen falls back to. What
        // it cannot say is "that monitor", because the per-screen map is keyed
        // by output name and config/Config.qml refuses a dotted path the
        // defaults do not name. That is the whole reason this verb is here.
        function set(path: string, screen: string): string {
            if (!path)
                return "usage: wallpaper set <path> [screen|all]";

            const where = root.wallpaperScreen(screen);
            if (!where)
                return `no such screen: ${screen}`;

            if (where === "all") {
                Wallpaper.setAll(path);
                return `all screens: ${Wallpaper.nameOf(path)}`;
            }
            Wallpaper.setOn(where, path);
            return `${where}: ${Wallpaper.nameOf(Wallpaper.currentOn(where))}`;
        }

        // HAND A SCREEN BACK TO THE DEFAULT, which is not the same deed as
        // setting it to whatever the default happens to be right now: the entry
        // goes, so the screen follows the default from here on rather than
        // being pinned to today's value of it. See services/Wallpaper.qml.
        function clear(screen: string): string {
            const where = root.wallpaperScreen(screen);
            if (!where)
                return `no such screen: ${screen}`;

            if (where === "all") {
                Wallpaper.setAll(Wallpaper.current);
                return `all screens follow the default: ${Wallpaper.name || "-"}`;
            }
            if (!Wallpaper.hasOwn(where))
                return `${where} already follows the default`;
            Wallpaper.clearOn(where);
            return `${where} follows the default: ${Wallpaper.nameOf(Wallpaper.currentOn(where))}`;
        }

        // WHAT THE WALLPAPER IS MADE OF, one colour per line with the fraction
        // of the picture it stands for. Measured on every change and published
        // whether or not anything wears it; `themeFromWallpaper` is the switch
        // that would, and it is not wired to anything yet on purpose. See
        // scripts/palette.py and config/Config.qml.
        function palette(): string {
            if (!Wallpaper.palette.length)
                return "no palette (nothing measured yet, or the file could not be read)";
            return Wallpaper.palette.map(c => `${c.colour} ${Math.round(c.share * 100)}%`).join("\n");
        }

        // Which one, whether it is showing, and how many there were to choose
        // from: the third is what tells a wrong `dir` from an empty one.
        //
        // AND ONE LINE PER SCREEN UNDERNEATH, because "which one" stopped being
        // a question with one answer. The first line is the shell's state and
        // the DEFAULT, since that is what the folder count and the switch are
        // about; the lines under it are the outputs, each saying whether it
        // wears the default or something of its own.
        //
        // The size is in there for the same reason ScreensPage prints it: `DP-1`
        // is not how anybody identifies the monitor in front of them, and a
        // resolution is. Through the device pixel ratio, so it is the number
        // written on the box rather than the logical one, and printed as the
        // pair the output actually reports, so a screen stood on its end reads
        // as taller than it is wide.
        function status(): string {
            const head = `${Wallpaper.enabled ? "on" : "off"} default ${Wallpaper.kindOf(Wallpaper.current) || "?"} ${Wallpaper.nameOf(Wallpaper.current) || "(nothing set)"} ${Wallpaper.available.length} in ${Wallpaper.dir}`;

            const rows = Quickshell.screens.map(s => {
                const own = Wallpaper.hasOwn(s.name);
                const path = Wallpaper.currentOn(s.name);
                const bits = [s.name === Hypr.focusedScreen ? "*" : " ", s.name, `${Math.round(s.width * s.devicePixelRatio)}x${Math.round(s.height * s.devicePixelRatio)}`, Wallpaper.nameOf(path) || "-", own ? "own" : "default"];
                // The preview, only while something is previewing it, because
                // that is the state where the desktop and the setting disagree
                // and the one thing a status line is genuinely needed for.
                const seen = Wallpaper.previewOn(s.name);
                if (seen)
                    bits.push(`showing ${Wallpaper.nameOf(seen)}`);
                return bits;
            });

            return rows.length ? `${head}\n${root.columns(rows)}` : head;
        }

        // THE FOLDER, AND WHICH OF IT SUITS ONE SCREEN.
        //
        // The picker predicts, and a prediction that cannot be inspected is one
        // you have to either trust or argue with by opening the panel and
        // counting cards. This is the same question asked in a form that fits
        // in a terminal: every wallpaper, its measured shape, and whether the
        // rule keeps it for this monitor.
        //
        // WHY THIS IS A VERB AT ALL. A filter is the one kind of control whose
        // failure is INVISIBLE by construction: a wallpaper wrongly excluded
        // does not appear anywhere for you to notice it missing, and the strip
        // looks exactly as correct as it would if the rule were right. So the
        // excluded ones are printed too, marked, rather than the verb answering
        // with the list the picker would show.
        //
        // The aspect is printed even for the ones that fit, because the two
        // numbers side by side are what makes an argument about the tolerance
        // possible: `wallpaper.fit` is a single factor in config.json and this
        // is the only place its consequences are all visible at once.
        function list(screen: string): string {
            const name = screen || Hypr.focusedScreen;
            const aspect = Wallpaper.screenAspect(name);
            if (!aspect)
                return `no such screen: ${name || "(none focused)"}`;

            const worn = Wallpaper.currentOn(name);
            const rows = Wallpaper.available.map(p => {
                const a = Wallpaper.aspectOf(p);
                return [
                    p === worn ? "*" : " ",
                    Wallpaper.fits(p, aspect) ? "fits" : "-",
                    // A shape that could not be measured is not a shape of 0,
                    // and printing one would be this line inventing the answer
                    // the fitting rule deliberately declines to give. See
                    // Wallpaper.shapes: unmeasured fits everything, and `?`
                    // beside `fits` is the whole of why.
                    a ? a.toFixed(2) : "?",
                    Wallpaper.nameOf(p)
                ];
            });

            const kept = rows.filter(r => r[1] === "fits").length;
            const head = `${name} ${aspect.toFixed(2)} · ${kept} of ${rows.length} fit · tolerance ${Config.values.wallpaper.fit}`;
            return rows.length ? `${head}\n${root.columns(rows)}` : head;
        }
    }

    // THE PICKER, which is a SURFACE and therefore its own target rather than
    // another verb on the one above.
    //
    // Plural against that one's singular, and the distinction is real: this
    // panel is about the folder, that target is about the one you are wearing.
    // Everything here opens and closes a thing on the screen and writes
    // nothing; everything there writes a setting and draws nothing.
    //
    // It is reached by GESTURE first (a second pull on the bottom edge, see
    // modules/wallpaper/WallpaperPicker.qml) and this is the second way in, for
    // the same reason every other surface in this file has one: a gesture
    // cannot be scripted, so a panel with no CLI is a panel that can only be
    // tested by hand.
    IpcHandler {
        target: "wallpapers"

        // The launcher's toggle and the launcher's reasoning: the strip that is
        // already out is what a second press is about, wherever the focus has
        // wandered to since the first one. `open` stays on the focused screen,
        // because a summon means here.
        //
        // AND BOTH TAKE A SCREEN NOW, which they did not need while a wallpaper
        // was one setting: the panel was the same panel wherever it stood, so
        // which monitor it came up on was a matter of taste. It is the control
        // for THAT screen's wallpaper now, and choosing a picture for the
        // monitor in the corner has to be askable. Same shape as `menu open
        // <key> [screen]` above: named is exact or an error, empty means here.
        function toggle(screen: string): string {
            const win = screen ? Shell.forScreen(screen) : Shell.showing(w => w.wallpapers.open);
            if (!win)
                return screen ? `no shell window on screen: ${screen}` : "no shell window";
            win.wallpapers.toggle();
            return win.wallpapers.open ? "open" : "closed";
        }

        function open(screen: string): string {
            const win = Shell.forScreen(screen);
            if (!win)
                return screen ? `no shell window on screen: ${screen}` : "no shell window";
            win.wallpapers.show();
            return "open";
        }

        function close(): string {
            for (const win of Shell.windows)
                win.wallpapers.hide();
            return "closed";
        }

        // What the strip is centred on, which is what the desktop is showing
        // while this is up, which is not yet what the setting says. All three
        // of those being different at once is exactly the state a preview is.
        //
        // Read off the window with the strip out, since a preview is only a
        // state while something is previewing it.
        //
        // AND EVERY NAME ON THIS LINE IS THAT WINDOW'S SCREEN'S, which is the
        // change per-screen wallpapers make here. The two names used to come
        // from the service unqualified and were "the session's"; there is no
        // such thing now. A picker open on DP-2 is previewing DP-2's desktop
        // against DP-2's setting, and a line that mixed in the focused screen's
        // wallpaper would be describing two monitors at once while claiming to
        // describe one. `scope` is the other half of the same fact: it says
        // which screens the next tap on that strip is going to repaint.
        function status(): string {
            const win = Shell.showing(w => w.wallpapers.open);
            if (!win)
                return "no shell window";
            const on = win.screen?.name ?? "";
            return `${win.wallpapers.open ? "open" : "closed"} on=${on || "?"} scope=${win.wallpapers.everywhere ? "all" : "here"} showing=${Wallpaper.shownNameOn(on) || "-"} set=${Wallpaper.nameOf(Wallpaper.currentOn(on)) || "-"} of ${Wallpaper.available.length}`;
        }
    }

    // The lock screen. ONE DIRECTION ONLY, deliberately: this can put the screen
    // up and cannot take it down.
    //
    // Not because an IPC unlock would be a hole in the lock - anything that can
    // reach this socket is already running as the user, which is the thing a
    // locked screen is not protecting against - but because there should be
    // exactly one documented way back in from outside, and logind already is
    // one. `loginctl unlock-session` works from a TTY or over SSH, needs a
    // session rather than a socket, and is honoured in services/Lock.qml. A
    // second route here would be a second thing to remember at the one moment
    // nobody wants to be remembering anything.
    IpcHandler {
        target: "lock"

        function lock(): string {
            Lock.lock();
            return "locked";
        }

        // Whether the shell believes it is locked, which is worth being able to
        // ask separately from what logind believes: those two disagreeing is
        // exactly the failure this shell would otherwise be blind to.
        function status(): string {
            return Lock.active ? "locked" : "unlocked";
        }
    }

    // ------------------------------------------------------------------
    // THE CLOCK: countdowns, alarms, and other people's afternoons. Three
    // targets and not one window between them.
    //
    // Driven off the singleton the way `settings` is, and for a stronger
    // version of the same reason. services/Clock.qml is a singleton precisely
    // because a countdown that only exists while somebody is looking at it is
    // not a countdown, and an alarm that only rings while its panel is open is
    // not an alarm; so there is no window to guard for here, no screen to name,
    // and every verb below works with every menu shut. The panel itself is an
    // ordinary menu with the key "clock" and is opened like any other, through
    // `menu open clock`, so it needs nothing of its own in this file.
    //
    // THE GUARD IS THE DISK INSTEAD. The service reads its state file once and,
    // when it lands, REPLACES its whole set of timers and alarms with what was
    // in it (Clock.adopt returns early ever after), so anything created in the
    // moment before that arrives is thrown away without a word. The window is
    // milliseconds wide and it is exactly the one an autostart bind or a login
    // script turns up in, which is the worst place to lose a timer quietly.
    readonly property string clockUnread: "the clock has not read its state file yet; ask again in a moment"

    // A human duration in SECONDS, or 0 for anything that is not one.
    //
    // The forms are a run of number-and-unit parts (10m, 90s, 2h, 1h30m,
    // 1h30m20s) and a bare number, WHICH IS MINUTES. A bare number has to mean
    // something, and minutes is what it means everywhere a timer is set out
    // loud: `timer start 5` off a keybind is five minutes, and five seconds is
    // not a timer anybody sets. Decimals go through the same arithmetic, so
    // 1.5h is ninety minutes and costs no extra code.
    //
    // A COLON FORM IS REFUSED rather than guessed at. "1:30" is an hour and a
    // half to anyone who has used a stopwatch and ninety seconds to anyone who
    // has used a microwave; there is nothing in the string to say which was
    // meant, and the failure is a countdown wrong by a factor of sixty in a
    // direction nobody checks until it goes off. "1h30" is refused for the same
    // reason in miniature: the trailing number has no unit and inventing one
    // for it is the same guess.
    function duration(text: string): int {
        const spec = String(text ?? "").trim().toLowerCase().replace(/\s+/g, "");
        if (/^\d+(\.\d+)?$/.test(spec))
            return Math.round(parseFloat(spec) * 60);
        if (!/^(\d+(\.\d+)?[hms])+$/.test(spec))
            return 0;
        let total = 0;
        for (const part of spec.match(/\d+(\.\d+)?[hms]/g))
            total += parseFloat(part) * (part.endsWith("h") ? 3600 : part.endsWith("m") ? 60 : 1);
        return Math.round(total);
    }

    // A wall-clock time as MINUTES SINCE MIDNIGHT, or -1 for anything that is
    // not one.
    //
    // Twenty-four hours first ("07:00", "7:00", "0700", "7"), because that is
    // what the alarm stores and what the panel draws, with an am/pm suffix
    // accepted because somebody who thinks in twelves should not have to do the
    // conversion in their head to write a keybind. A bare number is the hour
    // exactly, unlike `duration` above where a bare number is minutes, and the
    // asymmetry is the point: "start 7" is a length and "add 7" is a time on a
    // clock face, and nobody sets an alarm for seven minutes past midnight by
    // typing a single digit.
    function timeOfDay(text: string): int {
        const m = String(text ?? "").trim().toLowerCase().replace(/\s+/g, "").match(/^(\d{1,2}):?(\d{2})?(am|pm)?$/);
        if (!m)
            return -1;
        let hour = Number(m[1]);
        const minute = m[2] === undefined ? 0 : Number(m[2]);
        if (m[3]) {
            // A twelve-hour clock has no hour 0 and no hour 13, so those are a
            // typo rather than something to reinterpret; and 12am is midnight
            // while 12pm is noon, which is the one case the modulo exists for.
            if (hour < 1 || hour > 12)
                return -1;
            hour = (hour % 12) + (m[3] === "pm" ? 12 : 0);
        }
        return hour > 23 || minute > 59 ? -1 : hour * 60 + minute;
    }

    // The two digits a clock face has. Not the service's own pad2, which is not
    // part of what services/Clock.qml publishes: borrowing a helper across that
    // line would make an internal detail of another file into something this
    // one breaks when it moves.
    function hhmm(hour: int, minute: int): string {
        return `${String(hour).padStart(2, "0")}:${String(minute).padStart(2, "0")}`;
    }

    // MONDAY IS ZERO, which is the service's convention and not JavaScript's;
    // see the alarm block in services/Clock.qml for why (the panel's day pills
    // are labelled Monday-first, and the index that labels a pill has to be the
    // index that arms it). These names are ENGLISH AND FIXED rather than
    // Qt.locale()'s, deliberately: the panel should speak the user's language
    // and a script must not change meaning when LANG does.
    readonly property var dayNames: ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]

    // A repeat spec as those day numbers: [] for a one-shot, null for anything
    // unparseable, which the caller reports rather than quietly arming an alarm
    // for a week the user did not ask for.
    //
    // The named sets are computed from the day list rather than written out as
    // literals, so "weekdays" is defined by where Saturday sits and stays right
    // if the naming ever moves. A RANGE WALKS FORWARD AND WRAPS, so "fri-mon"
    // is the four days a person means by it instead of an error or an empty
    // set, and a single day is a range whose ends meet, which is why both go
    // through one loop with no branch that could disagree with itself.
    function repeatDays(spec: string): var {
        const want = String(spec ?? "").trim().toLowerCase().replace(/\s+/g, "");
        const all = root.dayNames.map((name, i) => i);
        if (!want || want === "once" || want === "never")
            return [];
        if (want === "daily" || want === "everyday" || want === "all")
            return all;
        if (want === "weekdays")
            return all.slice(0, root.dayNames.indexOf("sat"));
        if (want === "weekends" || want === "weekend")
            return all.slice(root.dayNames.indexOf("sat"));
        const out = [];
        for (const part of want.split(",")) {
            // Three letters, so "monday" and "mon" are the same word. A single
            // letter is refused by the same slice, which is right: "t" is both
            // Tuesday and Thursday and "s" is both weekend days.
            const ends = part.split("-").map(word => root.dayNames.indexOf(word.slice(0, 3)));
            if (ends.length > 2 || ends.some(i => i < 0))
                return null;
            for (let i = ends[0]; ; i = (i + 1) % all.length) {
                if (!out.includes(i))
                    out.push(i);
                if (i === ends[ends.length - 1])
                    break;
            }
        }
        return out.sort((a, b) => a - b);
    }

    // The same spec written back out, so what `alarm list` prints is what
    // `alarm add` would take. The named sets come first because they are what a
    // person reads: "weekdays" says in one word what "mon,tue,wed,thu,fri" says
    // in five, and both arm exactly the same days.
    function dayWords(days: var): string {
        const list = Array.isArray(days) ? days : [];
        const sat = root.dayNames.indexOf("sat");
        if (list.length === 0)
            return "once";
        if (list.length === root.dayNames.length)
            return "daily";
        if (list.length === sat && list.every(d => d < sat))
            return "weekdays";
        if (list.length === root.dayNames.length - sat && list.every(d => d >= sat))
            return "weekends";
        return list.map(d => root.dayNames[d]).join(",");
    }

    // A table, sized by what is actually in it. Fixed column widths were the
    // alternative and they are wrong in both directions at once: too narrow for
    // a label somebody really typed and too wide for the four short fields
    // beside it. The LAST column is never padded, because trailing spaces on
    // every line of a terminal are invisible until something copies them.
    // WHICH SCREEN A WALLPAPER VERB IS ABOUT, and the three answers a caller
    // can give in the one argument slot.
    //
    //   ""      the focused one, because a keybind and a bare CLI call both mean
    //           "here"; services/Shell.qml's forScreen("") makes this argument
    //           at length for the twenty verbs that go through it
    //   "DP-1"  that one, exactly, or "" for the caller to turn into an error.
    //           A name that quietly resolved to some other monitor would report
    //           success while repainting the wrong screen
    //   "all"   every screen, as one decision
    //
    // `all` is a screen NAME rather than a second parameter or a flag, because
    // Quickshell's IPC hands a function a fixed list of typed arguments and has
    // no options: a flag would be a parameter that is meaningless whenever the
    // screen one is set, and two arguments that can contradict each other are
    // two arguments somebody will make contradict each other. A word in the
    // slot that already means "where" cannot disagree with itself. No output is
    // called `all`; they are `DP-1`, `HDMI-A-1`, `eDP-1`.
    //
    // ASKED OF Quickshell.screens rather than of Shell.windows: this is a
    // question about monitors, and a monitor the shell has not built a window
    // on yet still has a wallpaper surface and still has a wallpaper.
    //
    // NOT the same helper as `Shell.forScreen`, deliberately. That one answers
    // with a shell WINDOW, and half of these verbs act on a screen that has no
    // window: `wallpaper set DP-3 ...` for a monitor whose surfaces are still
    // being built is a perfectly good thing to ask for, and the config takes it.
    // These two are the same rule about the empty string over different nouns.
    function wallpaperScreen(screen: string): string {
        if (screen === "all")
            return "all";
        if (screen)
            return Quickshell.screens.some(s => s.name === screen) ? screen : "";

        // THE FIRST SCREEN IS THE LAST RESORT, not the default, which is
        // services/Shell.qml's `?? root.windows[0]` said again for outputs
        // rather than for windows. `focusedScreen` is empty in the moment
        // before the compositor has named a monitor, and it is empty for the
        // whole session under a compositor that is not Hyprland; without this,
        // `wallpaper next` in either case answers "no such screen: " about a
        // screen nobody named, which reads as a bug in the argument you did not
        // pass. Caught by running the shell under a bare wlroots compositor,
        // where it is not an edge case at all.
        return Hypr.focusedScreen || Quickshell.screens[0]?.name || "";
    }

    // One step through the folder, on one screen or on all of them. Both verbs
    // are this function, because "which direction" is the only thing that
    // differs between them and a second copy is a second thing to keep in step.
    function walkWallpaper(screen: string, delta: int): string {
        if (!Wallpaper.available.length)
            return "nothing to step to";

        const where = root.wallpaperScreen(screen);
        if (!where)
            return `no such screen: ${screen}`;

        if (where === "all") {
            Wallpaper.stepAll(delta);
            return `all screens: ${Wallpaper.name || "-"}`;
        }
        Wallpaper.stepOn(where, delta);
        return `${where}: ${Wallpaper.nameOf(Wallpaper.currentOn(where))}`;
    }

    function columns(rows: var): string {
        const width = [];
        for (const row of rows)
            row.forEach((cell, i) => width[i] = Math.max(width[i] ?? 0, String(cell).length));
        return rows.map(row => row.map((cell, i) => i === row.length - 1 ? String(cell) : String(cell).padEnd(width[i])).join("  ")).join("\n");
    }

    // WHICH TIMER a verb means. A handle names one: either the id that `timer
    // status` prints or the position it prints beside it, and the two cannot be
    // confused because an id always carries a dash (Clock.newId builds it from
    // two base-36 numbers with one between them) and a position never does.
    //
    // Without a handle the verb means the timer a PERSON means, which is the
    // one about to go off: `matches` is the state that verb can act on, and the
    // nearest deadline among those wins. That is what makes `timer pause` worth
    // binding to a key, where there is nothing to type an id with.
    //
    // The filter is deliberately NOT applied to a named handle. "Pause timer 2"
    // is about timer 2 whatever state it is in, and the verb says so; pausing
    // timer 3 instead because 2 was already paused would be the CLI doing
    // something nobody asked for, to a countdown somebody is relying on.
    function pickTimer(handle: string, matches: var): var {
        const want = String(handle ?? "").trim();
        if (want)
            return (/^\d+$/.test(want) ? Clock.timers[Number(want) - 1] : Clock.timers.find(t => t.id === want)) ?? null;
        const at = Date.now();
        return Clock.timers.filter(matches).sort((a, b) => Clock.remainingOf(a, at) - Clock.remainingOf(b, at))[0] ?? null;
    }

    // The same two handles for an alarm, and NO bare form: a timer has an
    // obvious "the one that matters" and a list of alarms does not. Disarming
    // whichever alarm happens to be next is a thing you would find out about at
    // seven the following morning.
    function pickAlarm(handle: string): var {
        const want = String(handle ?? "").trim();
        if (!want)
            return null;
        return (/^\d+$/.test(want) ? Clock.alarms[Number(want) - 1] : Clock.alarms.find(a => a.id === want)) ?? null;
    }

    // One row of `timer status`, and also the whole of what `timer start`
    // answers with: what a verb prints after making something is the row the
    // list would show it as, so there is one format to learn and the id needed
    // by every other verb is in front of you the moment there is one.
    function timerFields(timer: var, index: int, at: double): var {
        return [`${index}`, Clock.spanLabel(Clock.remainingOf(timer, at)), timer.finished ? "done" : timer.paused ? "paused" : "running", timer.label || "-", `(${timer.id})`];
    }

    // One row of `alarm list`, on the same bargain. The state column is a union
    // of four things that are each worth seeing and cannot happen at once, and
    // `missed` earns its place in it: an alarm that rang unanswered or came due
    // too late to ring looks exactly like an alarm that never worked, and this
    // is the shell saying which.
    function alarmFields(alarm: var, index: int, at: double): var {
        const next = Clock.nextFor(alarm, at);
        const state = Clock.ringing && Clock.ringing.id === alarm.id ? "ringing" : alarm.missed ? "missed" : alarm.armed ? "armed" : "off";
        // Snoozed is not a state of its own here but a fact about WHEN: the
        // alarm is still armed and still repeating, it is merely due nine
        // minutes from now instead of at its own hour, and nextFor already
        // returns that instant.
        const when = alarm.snoozedUntil > at ? `snoozed, in ${Clock.spanLabel(next - at)}` : next > 0 ? `in ${Clock.spanLabel(next - at)}` : "-";
        const action = alarm.mode === "command" ? `run: ${alarm.payload}` : alarm.mode === "cloud" ? `ask: ${alarm.payload}` : "-";
        return [`${index}`, root.hhmm(alarm.hour, alarm.minute), root.dayWords(alarm.days), state, when, alarm.label || "-", action, `(${alarm.id})`];
    }

    // `enable` and `disable`, which are one function with a boolean and are two
    // verbs on purpose: a script cannot see the screen, and a toggle is only a
    // switch when you already know which way it was thrown. The row comes back
    // rather than a word, because the question behind disarming an alarm is
    // always what the NEXT one is now.
    function armAlarm(handle: string, on: bool): string {
        if (!Clock.loaded)
            return root.clockUnread;
        const alarm = root.pickAlarm(handle);
        if (!alarm)
            return handle ? `no such alarm: ${handle}` : "which alarm? (banditshell alarm list)";
        Clock.setAlarmArmed(alarm.id, on);
        return root.columns([root.alarmFields(alarm, Clock.alarms.indexOf(alarm) + 1, Date.now())]);
    }

    // The one spelling every place name in the zone verbs is compared in. The
    // tz database writes a space as an underscore, a person writes it as a
    // space, and the panel draws it as a space again (Clock.cityOf), so
    // "new york", "New_York" and "America/New_York" all have to meet somewhere
    // and this is where.
    function zoneKey(text: string): string {
        return String(text ?? "").trim().toLowerCase().replace(/[\s_]+/g, "_");
    }

    // Every place that could be meant by what was typed, exact spellings first.
    // Shared by `zone find` and `zone add` so that what one prints is what the
    // other resolves against, which is the difference between a suggestion and
    // a promise.
    function zoneMatches(text: string): var {
        const want = root.zoneKey(text);
        const exact = Clock.allZones.filter(id => root.zoneKey(id) === want);
        return exact.length > 0 ? exact : Clock.allZones.filter(id => root.zoneKey(id).includes(want));
    }

    // COUNTDOWNS. `start` is the verb worth binding and the rest are what a
    // person does to the thing they started.
    IpcHandler {
        target: "timer"

        function start(spec: string, label: string): string {
            if (!Clock.loaded)
                return root.clockUnread;
            const secs = root.duration(spec);
            if (secs <= 0)
                return `not a duration: "${spec}" (10m, 90s, 1h30m, 2h, or a bare number of minutes)`;
            const id = Clock.startTimer(secs, label ?? "");
            // The service gives up a FINISHED timer's slot before it refuses, so
            // reaching this line means every one of them is genuinely counting.
            if (!id)
                return `no room: ${Clock.timerMax} timers at a time and all of them are running`;
            const timer = Clock.timers.find(t => t.id === id);
            return root.columns([root.timerFields(timer, Clock.timers.indexOf(timer) + 1, Date.now())]);
        }

        function pause(handle: string): string {
            if (!Clock.loaded)
                return root.clockUnread;
            const timer = root.pickTimer(handle, t => !t.finished && !t.paused);
            if (!timer)
                return handle ? `no such timer: ${handle}` : "nothing is counting";
            if (timer.finished)
                return `that one has already gone off (${timer.id})`;
            if (timer.paused)
                return `already paused, ${Clock.spanLabel(timer.left)} left (${timer.id})`;
            Clock.toggleTimer(timer.id);
            return `paused, ${Clock.spanLabel(timer.left)} left (${timer.id})`;
        }

        function resume(handle: string): string {
            if (!Clock.loaded)
                return root.clockUnread;
            const timer = root.pickTimer(handle, t => t.paused && !t.finished);
            if (!timer)
                return handle ? `no such timer: ${handle}` : "nothing is paused";
            if (timer.finished)
                return `that one has already gone off (${timer.id})`;
            if (!timer.paused)
                return `already running, ${Clock.spanLabel(Clock.remainingOf(timer, Date.now()))} left (${timer.id})`;
            Clock.toggleTimer(timer.id);
            return `running, ${Clock.spanLabel(Clock.remainingOf(timer, Date.now()))} left (${timer.id})`;
        }

        // The verb A KEY wants, and the same bargain `volume mute` makes: one
        // press means the other thing, whichever thing it currently is, while
        // `pause` and `resume` sit beside it for a script that must not have to
        // guess the state it is starting from. It picks the timer FIRST and then
        // hands that id to whichever of the two applies, so a bare toggle cannot
        // pause one countdown and resume a different one on the next press.
        function toggle(handle: string): string {
            if (!Clock.loaded)
                return root.clockUnread;
            const timer = root.pickTimer(handle, t => !t.finished);
            if (!timer)
                return handle ? `no such timer: ${handle}` : "no timer to pause";
            if (timer.finished)
                return `that one has already gone off (${timer.id})`;
            return timer.paused ? resume(timer.id) : pause(timer.id);
        }

        function cancel(handle: string): string {
            if (!Clock.loaded)
                return root.clockUnread;
            // A SPENT TIMER FIRST when nothing was named. A countdown that has
            // already gone off is sitting in the panel waiting to be
            // acknowledged, "cancel" is what acknowledging it is called, and the
            // one still running beside it is the one you still want. Naming a
            // handle makes both picks answer with the same row, so the
            // preference costs nothing there.
            const timer = root.pickTimer(handle, t => t.finished) ?? root.pickTimer(handle, t => true);
            if (!timer)
                return handle ? `no such timer: ${handle}` : "no timers";
            Clock.removeTimer(timer.id);
            return `cancelled ${timer.label || Clock.spanLabel(timer.total)} (${timer.id})`;
        }

        // The list IS the status here, unlike the alarm target below, which has
        // both: three countdowns fit on three lines with nothing summarised
        // away, and a summary of them would be the same lines with the numbers
        // taken out.
        function status(): string {
            if (!Clock.loaded)
                return root.clockUnread;
            if (Clock.timers.length === 0)
                return `no timers (${Clock.timerMax} at a time)`;
            const at = Date.now();
            return root.columns(Clock.timers.map((timer, i) => root.timerFields(timer, i + 1, at)));
        }
    }

    // ALARMS.
    //
    // THE ARGUMENT SHAPE, which is the part worth getting right, because this
    // is the target with options and options in a keybind are the thing to get
    // wrong once and never notice.
    //
    // `add` takes FIVE POSITIONAL STRINGS here and FLAGS in bin/banditshell,
    // and that is a division of labour rather than a mismatch: an IpcHandler
    // function has a fixed, named parameter list and no way to be variadic, so
    // the options must arrive in a known order, while nobody writing a keybind
    // should have to remember what that order is or count empty strings to
    // reach the last one. The CLI parses --days, --label, --run and --ask and
    // fills the five in; anything calling `qs ipc call alarm add` by hand
    // passes them itself, empty for the ones it does not want.
    //
    // ONE FLAG SETS BOTH HALVES OF AN ACTION: `--run` is mode command with the
    // payload it was given, `--ask` is mode cloud with the same. A --mode and a
    // --payload that had to agree could be given as a mode with no payload,
    // which is an alarm that announces it will do something and then does
    // nothing; one flag cannot be spelled that way at all.
    //
    // THERE IS NO EDIT VERB, deliberately, and it is the one thing the service
    // can do that is not here. Clock.setAlarm's fields are the panel's editor,
    // and an editor is precisely what a keybind is not: you cannot scrub a time
    // from a key. `remove` and `add` together say anything a `set` would, in one
    // line, and `add` hands back the id to remove it with.
    IpcHandler {
        target: "alarm"

        function add(time: string, days: string, label: string, mode: string, payload: string): string {
            if (!Clock.loaded)
                return root.clockUnread;
            const minutes = root.timeOfDay(time);
            if (minutes < 0)
                return `not a time: "${time}" (07:00, 7:30pm, 0700, or a bare hour)`;
            const repeat = root.repeatDays(days);
            if (repeat === null)
                return `not a repeat: "${days}" (mon,wed / mon-fri / weekdays / weekends / daily / once)`;
            const action = mode || "none";
            if (!["none", "command", "cloud"].includes(action))
                return `not an action: "${mode}" (command or cloud)`;
            // An action with nothing to do is refused HERE rather than stored,
            // because the service would take it (mode without payload is a legal
            // record) and Clock.run would then quietly return, which is an alarm
            // that says it will do something and does not.
            if (action !== "none" && !payload)
                return `${action} needs something to ${action === "command" ? "run" : "say"}`;
            const id = Clock.addAlarm();
            if (!id)
                return `no room: ${Clock.alarmMax} alarms is the lot`;
            // Created and then patched, which is the service's own shape: every
            // field an editor can touch goes through setAlarm so there is one
            // place that re-derives the schedule afterwards.
            Clock.setAlarm(id, {
                hour: Math.floor(minutes / 60),
                minute: minutes % 60,
                days: repeat,
                label: label ?? "",
                mode: action,
                payload: payload ?? ""
            });
            const alarm = Clock.alarms.find(a => a.id === id);
            return root.columns([root.alarmFields(alarm, Clock.alarms.indexOf(alarm) + 1, Date.now())]);
        }

        function list(): string {
            if (!Clock.loaded)
                return root.clockUnread;
            if (Clock.alarms.length === 0)
                return `no alarms (${Clock.alarmMax} is the lot)`;
            const at = Date.now();
            return root.columns(Clock.alarms.map((alarm, i) => root.alarmFields(alarm, i + 1, at)));
        }

        function remove(handle: string): string {
            if (!Clock.loaded)
                return root.clockUnread;
            const alarm = root.pickAlarm(handle);
            if (!alarm)
                return handle ? `no such alarm: ${handle}` : "which alarm? (banditshell alarm list)";
            Clock.removeAlarm(alarm.id);
            return `removed ${root.hhmm(alarm.hour, alarm.minute)}${alarm.label ? ` ${alarm.label}` : ""} (${alarm.id})`;
        }

        function enable(handle: string): string {
            return root.armAlarm(handle, true);
        }

        function disable(handle: string): string {
            return root.armAlarm(handle, false);
        }

        // Nine more minutes, and done with it. Both take no argument because
        // there is only ever one alarm ringing (the service fires them one at a
        // time on purpose), and both are here for the moment the panel is not
        // the easiest thing to reach.
        function snooze(): string {
            if (!Clock.ringing)
                return "nothing is ringing";
            const alarm = Clock.ringing;
            Clock.snooze();
            return `snoozed ${root.hhmm(alarm.hour, alarm.minute)} for ${Clock.snoozeMinutes}m (${alarm.id})`;
        }

        function stop(): string {
            if (!Clock.ringing)
                return "nothing is ringing";
            const alarm = Clock.ringing;
            Clock.stop();
            // What it did next, because the two answers are different and
            // silence between them is a question: a repeating alarm has rolled
            // to its next day and a one-shot has disarmed itself.
            return `stopped ${root.hhmm(alarm.hour, alarm.minute)}, ${alarm.days.length === 0 ? "disarmed" : `next ${root.dayWords(alarm.days)}`} (${alarm.id})`;
        }

        // The summary, where `list` is the rows: how many, what is next, what is
        // ringing, and the three policy numbers underneath. Those last are what
        // somebody asking "why did it not go off" actually needs, and they are
        // config rather than code, so reading them back beats reading the source.
        function status(): string {
            if (!Clock.loaded)
                return root.clockUnread;
            const at = Date.now();
            const armed = Clock.alarms.filter(a => a.armed);
            let soonest = null;
            for (const alarm of armed) {
                const when = Clock.nextFor(alarm, at);
                if (when > 0 && (!soonest || when < soonest.when))
                    soonest = {
                        alarm,
                        when
                    };
            }
            // HEADED BY THE ALARM'S OWN TIME, with "snoozed" said out loud when
            // the instant the countdown is measuring is not that time. Heading
            // it with the occurrence instead, the way the service titles a
            // notification, was tried and reads as a lie: a 07:00 weekday alarm
            // snoozed at 22:38 comes out as "22:47 weekdays", which describes an
            // alarm nobody set. The rows in `alarm list` say it this way too,
            // and the two agreeing matters more than either shape alone.
            const ring = Clock.ringing;
            const next = soonest ? `${root.hhmm(soonest.alarm.hour, soonest.alarm.minute)} ${root.dayWords(soonest.alarm.days)}, ${soonest.alarm.snoozedUntil > at ? "snoozed, " : ""}in ${Clock.spanLabel(soonest.when - at)}` : "-";
            return [`alarms     ${Clock.alarms.length} of ${Clock.alarmMax}`, `armed      ${armed.length}`, `next       ${next}`, `ringing    ${ring ? `${root.hhmm(ring.hour, ring.minute)}${ring.label ? ` ${ring.label}` : ""}, ${Clock.spanLabel(at - Clock.ringingSince)} so far${Clock.ringingLate > 60000 ? `, late by ${Clock.spanLabel(Clock.ringingLate)}` : ""}` : "none"}`, `policy     snooze ${Clock.snoozeMinutes}m, gives up after ${Clock.ringMinutes}m, catches up within ${Clock.catchUpMinutes}m`].join("\n");
        }
    }

    // OTHER PEOPLE'S AFTERNOONS.
    //
    // A place is named by its IANA id and has no label of its own: the city the
    // panel draws is read off the id (Clock.cityOf turns "America/New_York" into
    // "New York"), so there is nothing to pass a second argument for and this
    // file invents no field to hold one.
    IpcHandler {
        target: "zone"

        // The local zone first and always, because it is the block the panel
        // draws above the list and it is real information even when the list is
        // empty.
        //
        // THE TIMES ARE COMPUTED HERE rather than read off the rows. Clock.zones
        // carries a snapshot that is only kept fresh while something is watching
        // (see Clock.watch), and nothing is watching when a CLI asks, so those
        // fields can be up to an hour stale; zoneTime is pure arithmetic on an
        // epoch millisecond and is what the service itself tells a caller to
        // drive off its own clock.
        function list(): string {
            if (!Clock.loaded)
                return root.clockUnread;
            const at = Date.now();
            const rows = [[Clock.localCity || "-", Clock.zoneTime(Clock.localOffset, at).text, "here", `(${Clock.localZone || "unknown"})`]];
            for (const zone of Clock.zones) {
                const there = Clock.zoneTime(zone.offsetMinutes, at);
                const day = there.dayDelta === 0 ? "" : there.dayDelta < 0 ? " yesterday" : " tomorrow";
                rows.push([zone.city, there.text, `${Clock.offsetLabel(zone.deltaMinutes)}${day}`, `(${zone.id})`]);
            }
            // A place whose offset has not come back from the system yet is not
            // in `zones` at all, and saying so is the difference between a
            // measurement in flight and an id that went nowhere.
            const pending = Clock.places.filter(id => !Clock.zones.some(z => z.id === id));
            const table = rows.length > 1 ? root.columns(rows) : `${root.columns(rows)}\nno places yet (banditshell zone add <place>)`;
            return pending.length > 0 ? `${table}\nmeasuring ${pending.join(", ")}` : table;
        }

        // Everything this machine's tz database has that matches, one per line,
        // uncapped: a terminal scrolls, and a cap would be this file deciding
        // that the twelfth Europe/ entry is the one you did not want.
        function find(text: string): string {
            const want = String(text ?? "").trim();
            if (!want)
                return "which place? (banditshell zone find <text>)";
            if (Clock.allZones.length === 0) {
                Clock.loadZoneList();
                return "reading this machine's zone list; ask again in a moment";
            }
            const near = root.zoneMatches(want);
            return near.length > 0 ? near.join("\n") : `nothing here is called that: ${want}`;
        }

        // THE LIST IS CONSULTED FIRST and the add is refused until it is here,
        // which is a whole extra command once per session and buys a guarantee
        // worth having: Clock.validZone only checks the SHAPE of an id, so
        // "Europe/Tokoy" passes it, is stored, comes back +0000 from `TZ=... date`
        // and draws a city that does not exist at a time that is not its own,
        // with nothing anywhere saying anything is wrong. The list is one
        // process and is kept for the life of the shell.
        //
        // A UNIQUE SUBSTRING IS ACCEPTED as well as an exact id, so "tokyo" is
        // Asia/Tokyo: a CLI you have to look things up for before using is a CLI
        // with a manual. Two matches are refused rather than guessed between,
        // because two places are equally meant, and the answer names what was
        // actually added so a wrong guess is visible in the same breath.
        function add(place: string): string {
            if (!Clock.loaded)
                return root.clockUnread;
            const want = String(place ?? "").trim();
            if (!want)
                return "which place? (banditshell zone find <text>)";
            if (Clock.allZones.length === 0) {
                Clock.loadZoneList();
                return "reading this machine's zone list; ask again in a moment";
            }
            const near = root.zoneMatches(want);
            if (near.length === 0)
                return `no such place: ${want} (banditshell zone find ${want})`;
            if (near.length > 1)
                return `${want} could be any of ${near.length} (banditshell zone find ${want})`;
            const id = near[0];
            // Both of these are things Clock.addZone declines in silence, which
            // is right for a panel and useless to a terminal.
            if (id === Clock.localZone)
                return `${Clock.cityOf(id)} is this machine's own zone, which the panel draws already`;
            if (Clock.places.includes(id))
                return `already on the list: ${id}`;
            Clock.addZone(id);
            return `added ${Clock.cityOf(id)} (${id})`;
        }

        // BY ID OR BY CITY, and by nothing else: no position, unlike the timers
        // and alarms above. Their lists are stored orders, while `zone list` is
        // sorted by offset and silently drops any place whose measurement has
        // not landed, so a number printed by one command could address a
        // different row by the time it was typed into the next.
        function remove(place: string): string {
            if (!Clock.loaded)
                return root.clockUnread;
            const want = root.zoneKey(place);
            if (!want)
                return "which place? (banditshell zone list)";
            const hits = Clock.places.filter(id => root.zoneKey(id) === want || root.zoneKey(Clock.cityOf(id)) === want);
            if (hits.length === 0)
                return `not on the list: ${place} (banditshell zone list)`;
            if (hits.length > 1)
                return `${place} is ${hits.length} of them; name the id (banditshell zone list)`;
            Clock.removeZone(hits[0]);
            return `removed ${Clock.cityOf(hits[0])} (${hits[0]})`;
        }
    }

    IpcHandler {
        target: "shell"

        // Enough to see whether the shell agrees with the compositor, which is
        // the thing most likely to be quietly wrong and hardest to see.
        //
        // Everything above the launcher lines is the session's and has one
        // answer. The launcher is a window's, so it is read off the window that
        // HAS one open (Shell.showing), and read once into a name rather than
        // four times into one string: four lookups can be four different windows
        // the moment a screen appears mid-line, and a report whose height and
        // scroll came from a different launcher than its open-ness would be
        // wrong in the way that is hardest to notice.
        function status(): string {
            const win = Shell.showing(w => w.launcher.open);
            return [`compositor  ${Compositor.name}`, `following   ${Appearance.follows}`, `theme       ${Themes.activeName}`, `rounding    ${Appearance.rounding.base}`, `corner      power ${Appearance.rounding.power} (compositor says ${Compositor.roundingPower})`, `tiers       ${Appearance.rounding.small} / ${Appearance.rounding.normal} / ${Appearance.rounding.large} from base ${Appearance.rounding.base}, available=${Compositor.available}`, `gap         ${Appearance.sizes.gap} outer, ${Compositor.gapsIn} inner`, `wm border   ${Compositor.borderSize}`, `window edge ${Appearance.sizes.windowRadius} (the one radius)`, `band        ${Appearance.sizes.band}`, `bar         ${Appearance.sizes.sidebarWidth}`, `apps        ${Apps.all.length} listed, ${DesktopEntries.applications.values.length} on disk`, `launcher    ${win?.launcher.open ? "open" : "closed"}, ${win?.launcher.resultCount ?? 0} results, ${Math.round(win?.launcher.drawnHeight ?? 0)}px tall`, `scroll      ${win?.launcher.scrollInfo ?? "-"}`, `screens     ${Shell.screenNames().join(", ")}`].join("\n");
        }

        function themes(): string {
            // Every palette theme-set can render, with the applied one marked.
            // Themes.names is the shell's own view and collapses to one while a
            // render is live, which is the wrong answer for "what can I pick".
            return Themes.availableNames.map(n => n === Themes.activeName ? `* ${n}` : `  ${n}`).join("\n");
        }

        function get(key: string): string {
            const v = Config.get(key);
            return v === undefined ? `no such setting: ${key}` : JSON.stringify(v);
        }

        // Values arrive as text. Parse them as JSON so numbers and booleans land
        // as numbers and booleans, and fall back to the raw string, which is a
        // perfectly good value for a theme name.
        function set(key: string, value: string): string {
            let parsed = value;
            try {
                parsed = JSON.parse(value);
            } catch (e) {}
            Config.set(key, parsed);
            return `${key} = ${JSON.stringify(parsed)}`;
        }
    }

    // THE TABLET MAPPING, WITHOUT THE TABLET. Everything about PenMap is meant
    // to be driven from the pad: hold a button, drag with the pen, let go. That
    // is the whole point of it, and it is also a single point of failure, since
    // the pad arrives over Bluetooth and a tablet that is asleep, out of
    // battery or unpaired has no buttons at all. A feature whose only way in is
    // the device it configures cannot be used to rescue itself.
    //
    // So the same verbs are here, reachable from a keybind or a terminal. Not
    // as the intended route, and deliberately not bound to a key by default,
    // but so that "the mapper will not open" is a thing the user can work
    // around in one command rather than a thing that needs the shell restarted.
    //
    // `status` prints the region and the monitor it is homed to, which is the
    // one question worth asking when the pen is landing somewhere unexpected.
    IpcHandler {
        target: "penmap"

        function open(): string {
            PenMap.begin();
            return "open";
        }

        function commit(): string {
            PenMap.commit();
            return "committed";
        }

        function cancel(): string {
            PenMap.cancel();
            return "cancelled";
        }

        function aspect(): string {
            PenMap.toggleAspect();
            return PenMap.aspectLocked ? "locked" : "free";
        }

        // The same rectangle the pad's third button states, for the same reason
        // every other verb here exists: a region small enough to have shed its
        // controls has no pill to press, and a pad that is asleep has no button.
        function centre(): string {
            PenMap.fitAndCentre();
            return root.penmapStatus();
        }

        // The window picker, as a verb, for the same reason the rest of this
        // handler exists: the mode is toggled from a pill drawn inside the
        // region, and a region small enough to have dropped its controls has no
        // pill to press. That corner is reachable by snapping to a narrow
        // window, which is a thing this very mode does.
        function follow(): string {
            PenMap.toggleFollowWindow();
            return PenMap.followWindow ? "following" : "off";
        }

        // Absolute, in global layout coordinates, because that is the frame the
        // service thinks in and the frame `hyprctl monitors` prints. The
        // service clamps and re-homes whatever lands here, so a nonsense
        // rectangle is corrected rather than rejected.
        function set(x: string, y: string, w: string, h: string): string {
            const nums = [x, y, w, h].map(Number);
            if (nums.some(isNaN))
                return "four numbers: x y w h";
            PenMap.proposeRegion(nums[0], nums[1], nums[2], nums[3]);
            PenMap.commit();
            return root.penmapStatus();
        }

        function status(): string {
            return root.penmapStatus();
        }
    }
}
