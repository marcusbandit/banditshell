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

    function close(): string {
        return PanelWindows.unpin("quickControls");
    }

    function status(): string {
        const win = Shell.forScreen("");
        return `pinned=${win?.quickControls.pinned ?? false}`;
    }
}
