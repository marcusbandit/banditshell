pragma Singleton

import Quickshell
import qs.config
import qs.services

Singleton {
    function missing(screen: string): string {
        return screen ? `no shell window on screen: ${screen}` : "no shell window";
    }

    function toggle(part: string, screen: string): string {
        Appearance.instantly();
        const win = screen ? Shell.forScreen(screen) : Shell.showing(w => w[part].open);
        if (!win)
            return "";
        win[part].toggle();
        return win[part].open ? "open" : "closed";
    }

    function open(part: string, screen: string): string {
        Appearance.instantly();
        const win = Shell.forScreen(screen);
        if (!win)
            return "";
        win[part].show();
        return "open";
    }

    function close(part: string): string {
        Appearance.instantly();
        for (const win of Shell.windows)
            win[part]?.hide();
        return "closed";
    }

    function pin(win: var, part: string, on: bool): string {
        Appearance.instantly();
        if (!win)
            return "";
        const span = win[part].pinned === on ? null : Trace.begin(`${part} ${on ? "open" : "close"}`);
        win[part].pinned = on;
        Trace.step(on ? "shown" : "hidden", span);
        return on ? "open" : "closed";
    }

    function unpin(part: string): string {
        Appearance.instantly();
        for (const win of Shell.windows)
            if (win[part]?.pinned) {
                const span = Trace.begin(`${part} close`);
                win[part].pinned = false;
                Trace.step("hidden", span);
            }
        return "closed";
    }

    function resolveScreen(screen: string): string {
        if (screen === "all")
            return "all";
        if (screen)
            return Quickshell.screens.some(s => s.name === screen) ? screen : "";

        return Hypr.focusedScreen || Quickshell.screens[0]?.name || "";
    }
}
