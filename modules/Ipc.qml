pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// The shell's control surface, for the `banditshell` CLI and later for keybinds.
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

        function open(): string {
            Settings.show();
            return "open";
        }

        function close(): string {
            Settings.hide();
            return "closed";
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
            return [`open       ${Settings.open}`, `held by    ${Settings.floating ? "a window" : "the shell"}`, `screen     ${Settings.screenName || "-"}`, `window     ${Settings.windowOpen ? Settings.address || "opening" : "none"}`, `placed     ${Settings.placed}`, `handoff    ${Settings.handoff ? `${Settings.handoff.x},${Settings.handoff.y} ${Settings.handoff.w}x${Settings.handoff.h}` : "-"}`].join("\n");
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
