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
