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

    IpcHandler {
        target: "menu"

        // Every menu key, one per line.
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

        function toggle(key: string, screen: string): string {
            const win = Shell.forScreen(screen);
            if (win?.menus.currentKey === key)
                return close();
            return open(key, screen);
        }

        // What is open, or nothing.
        function current(): string {
            const win = Shell.forScreen("");
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
        function hover(): string {
            const win = Shell.forScreen("");
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

        function toggle(): string {
            const win = Shell.forScreen("");
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
        function scrub(fraction: string): string {
            const win = Shell.forScreen("");
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

        function toggle(): string {
            const win = Shell.forScreen("");
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
        function status(): string {
            const win = Shell.forScreen("");
            const kinds = {};
            for (const e of Clipboard.entries)
                kinds[e.kind] = (kinds[e.kind] ?? 0) + 1;
            const tally = Object.keys(kinds).sort().map(k => `${k}=${kinds[k]}`).join(" ");
            return `recording=${Clipboard.recording} entries=${Clipboard.entries.length} pinned=${Clipboard.entries.filter(e => e.pinned).length} open=${win?.clipboard.open ?? false} ${tally}`;
        }
    }

    // The power panel. Opened on the FIRST screen rather than the focused one,
    // the same way every other handler here works: a keybind that ends the
    // session should put the question in one known place, not wherever the
    // cursor happened to be resting.
    IpcHandler {
        target: "session"

        function toggle(): string {
            const win = Shell.forScreen("");
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

    // The calculator, driven exactly like the power panel above and for the same
    // reason: it is summoned by name from wherever you were, so it belongs on ONE
    // known screen rather than on whichever one holds the focused window, and
    // `close` reaches every screen because "put it away" is not a question about
    // a monitor.
    //
    // THIS IS ALSO WHAT THE .desktop ENTRY RUNS. A desktop file is a keybind
    // somebody else's menu owns, so the route has to be the CLI rather than
    // anything that assumes a shell already has the pointer: see
    // assets/applications/banditshell-calculator.desktop, which is nothing but
    // `banditshell calculator`.
    IpcHandler {
        target: "calculator"

        function toggle(): string {
            const win = Shell.forScreen("");
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
        function app(): string {
            const win = Shell.forScreen("");
            if (!win)
                return "no shell window";
            if (win.calculator.open && win.calculator.full)
                return close();
            win.calculator.app();
            return "open";
        }

        // Its twin, for symmetry and for a keybind that wants the small one
        // whatever you were last in. Same toggle rule, read the same way.
        function panel(): string {
            const win = Shell.forScreen("");
            if (!win)
                return "no shell window";
            if (win.calculator.open && !win.calculator.full)
                return close();
            win.calculator.panel();
            return "open";
        }

        // Which shape it is in, and whether it is out at all. The one question a
        // script cannot otherwise ask, and the one the two verbs above are
        // deciding on.
        function status(): string {
            const win = Shell.forScreen("");
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

        // WHERE THE BELIEF CAME FROM, and not just what it is. `folded` is false
        // both when the machine is flat and when nothing has managed to tell the
        // shell anything, and those two are worth telling apart: a fold that
        // never arrives is a switch bind that is not firing, and this line is
        // how that gets diagnosed without attaching a debugger to a compositor.
        function status(): string {
            const state = Tablet.folded ? "folded" : "flat";
            return `${state} (${Tablet.known ? "known" : "assumed"}, via ${Tablet.source})`;
        }
    }

    // THE BOARD ITSELF, separately from the hinge, because the two are genuinely
    // different questions and conflating them would remove the useful cases at
    // both ends: a keyboard on an unfolded machine (a bind, when the real one is
    // across the desk) and a folded machine with no keyboard (reading something,
    // where the board is just in the way).
    IpcHandler {
        target: "keyboard"

        function toggle(screen: string): string {
            const win = Shell.forScreen(screen);
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
        // the only one worth reporting.
        function status(screen: string): string {
            const win = Shell.forScreen(screen);
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

        function page(name: string, screen: string): string {
            const win = Shell.forScreen(screen);
            if (!win)
                return "no shell window";
            win.keyboard.page = name;
            return `page ${name}`;
        }
    }

    // The hotkey sheet: every bind the compositor knows about, read off it
    // rather than out of a list in this repo. Driven exactly like the power
    // panel above, and for the same reason: it is summoned by name from
    // wherever you were, so it belongs on ONE known screen rather than on
    // whichever one happens to hold the focused window, and `close` reaches
    // every screen because "put it away" is not a question about a monitor.
    //
    // This is also the target that the keybind actually goes through. The sheet
    // is the one panel here whose whole content is the user's own config, so it
    // has to be openable the moment that config changes, without the shell
    // being restarted or knowing anything about which key was pressed.
    //
    // AN OPTIONAL SCREEN, exactly as `menu open` takes one, and the empty string
    // still means the first window, so every keybind and every line of
    // docs/hyprland-binds.example.conf goes on meaning what it meant. The
    // paragraph above is about the DEFAULT and it stands: a sheet you summoned by
    // name belongs in one known place rather than under whichever window has the
    // focus. What it was never an argument for is the sheet being the one panel
    // in this file that CANNOT be named a screen, which is what it had become:
    // `menu` and `settings` both take one, so a sweep can put them on a headless
    // output and photograph them there, and this panel alone had to be opened on
    // the user's own display, over the user's own work, to be looked at at all.
    // A default is not the same thing as a restriction.
    IpcHandler {
        target: "hotkeys"

        function toggle(screen: string): string {
            const win = Shell.forScreen(screen);
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
        function status(screen: string): string {
            const win = Shell.forScreen(screen);
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
    // `menu` take one, with the empty string still meaning the first window so
    // every existing keybind goes on meaning what it meant. The paragraph above
    // is about WHICH INPUT the CLI stands in for and it is untouched; what the
    // tray had additionally become was the panel that could only be pinned on
    // Shell.windows[0], and that is a restriction nobody argued for.
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
        function next(): string {
            Wallpaper.step(1);
            return Wallpaper.name || "nothing to step to";
        }

        function prev(): string {
            Wallpaper.step(-1);
            return Wallpaper.name || "nothing to step to";
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
        function status(): string {
            return `${Wallpaper.enabled ? "on" : "off"} ${Wallpaper.kind || "?"} ${Wallpaper.name || "(nothing set)"} ${Wallpaper.available.length} in ${Wallpaper.dir}`;
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

        function toggle(): string {
            const win = Shell.forScreen("");
            if (!win)
                return "no shell window";
            win.wallpapers.toggle();
            return win.wallpapers.open ? "open" : "closed";
        }

        function open(): string {
            Shell.forScreen("")?.wallpapers.show();
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
        function status(): string {
            const win = Shell.forScreen("");
            if (!win)
                return "no shell window";
            return `${win.wallpapers.open ? "open" : "closed"} showing=${Wallpaper.shownName || "-"} set=${Wallpaper.name || "-"} of ${Wallpaper.available.length}`;
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
        function status(): string {
            return [`compositor  ${Compositor.name}`, `following   ${Appearance.follows}`, `theme       ${Config.values.theme}`, `rounding    ${Appearance.rounding.base}`, `smoothing   ${Appearance.rounding.smoothing.toFixed(3)} (power ${Compositor.roundingPower})`, `gap         ${Appearance.sizes.gap} outer, ${Compositor.gapsIn} inner`, `wm border   ${Compositor.borderSize}`, `window edge ${Appearance.sizes.windowRadius} (the one radius)`, `band        ${Appearance.sizes.band}`, `bar         ${Appearance.sizes.sidebarWidth}`, `apps        ${Apps.all.length} listed, ${DesktopEntries.applications.values.length} on disk`, `launcher    ${Shell.forScreen("")?.launcher.open ? "open" : "closed"}, ${Shell.forScreen("")?.launcher.resultCount ?? 0} results, ${Math.round(Shell.forScreen("")?.launcher.drawnHeight ?? 0)}px tall`, `scroll      ${Shell.forScreen("")?.launcher.scrollInfo ?? "-"}`, `screens     ${Shell.screenNames().join(", ")}`].join("\n");
        }

        function themes(): string {
            return Themes.names.join("\n");
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
}
