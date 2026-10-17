import Quickshell.Io
import qs.services
import qs.modules

IpcHandler {
    target: "keyboard"

    function toggle(screen: string): string {
        return PanelWindows.toggle("keyboard", screen) || "no shell window";
    }

    function open(screen: string): string {
        return PanelWindows.open("keyboard", screen) || "no shell window";
    }

    function close(): string {
        return PanelWindows.close("keyboard");
    }

    function status(screen: string): string {
        const win = screen ? Shell.forScreen(screen) : Shell.showing(w => w.keyboard.open);
        if (!win)
            return "no shell window";
        if (!win.keyboard.item)
            return "closed";
        return `${win.keyboard.open ? "open" : "closed"} on "${win.keyboard.item.page}"`;
    }

    function dock(): string {
        Tablet.setDocked(true);
        return "docked";
    }

    function float(): string {
        Tablet.setDocked(false);
        return "floating";
    }

    function page(name: string, screen: string): string {
        const win = screen ? Shell.forScreen(screen) : Shell.showing(w => w.keyboard.open);
        if (!win)
            return "no shell window";
        win.keyboard.build().page = name;
        return `page ${name}`;
    }
}
