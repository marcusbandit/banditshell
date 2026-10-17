import Quickshell.Io
import qs.services
import qs.modules.panel

IpcHandler {
    target: "menu"

    function list(): string {
        const win = Shell.forScreen("");
        return win ? win.statusKeys.join("\n") : "";
    }

    function open(key: string, screen: string): string {
        const win = Shell.forScreen(screen);
        if (!win)
            return PanelWindows.missing(screen);
        return win.openMenu(key) ? `open ${key}` : `no such menu: ${key}`;
    }

    function close(): string {
        for (const win of Shell.windows)
            win.menus.hide();
        return "closed";
    }

    function toggle(key: string, screen: string): string {
        const win = screen ? Shell.forScreen(screen) : Shell.showing(w => w.menus.currentKey === key);
        if (win?.menus.currentKey === key)
            return close();
        return open(key, screen);
    }

    function current(): string {
        const win = Shell.showing(w => w.menus.currentKey);
        return win?.menus.currentKey ?? "";
    }

    function hover(): string {
        const win = Shell.showing(w => w.menus.currentKey);
        if (!win)
            return "no shell window";
        return `shell=${win.cursorOnShell} panel=${win.menus.hovered} open=[${win.menus.currentKey}] keyboard=${win.menus.needsKeyboard}`;
    }
}
