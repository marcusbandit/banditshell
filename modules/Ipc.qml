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
        function hover(): string {
            const win = Shell.forScreen("");
            if (!win)
                return "no shell window";
            return `shell=${win.cursorOnShell} panel=${win.menus.hovered} open=[${win.menus.currentKey}]`;
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
