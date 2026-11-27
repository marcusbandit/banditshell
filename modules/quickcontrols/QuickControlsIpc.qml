import Quickshell.Io
import qs.services
import qs.modules.panel

IpcHandler {
    target: "quickcontrols"

    function toggle(): string {
        const win = Shell.showing(w => w.quickControls.pinned);
        return PanelWindows.pin(win, "quickControls", !win?.quickControls.pinned) || PanelWindows.missing("");
    }

    function open(): string {
        return PanelWindows.pin(Shell.forScreen(""), "quickControls", true) || PanelWindows.missing("");
    }

    function page(key: string): string {
        const win = Shell.forScreen("");
        if (!win)
            return PanelWindows.missing("");
        if (key && !Object.prototype.hasOwnProperty.call(win.quickControls.pages, key))
            return `no page ${key}; pages: ${Object.keys(win.quickControls.pages).join(", ")}`;
        if (key)
            win.quickControls.openPage(key, true);
        else
            win.quickControls.back(true);
        return key ? `page ${key}` : "back";
    }

    function close(): string {
        return PanelWindows.unpin("quickControls");
    }

    function status(): string {
        const win = Shell.forScreen("");
        return `pinned=${win?.quickControls.pinned ?? false}`;
    }
}
