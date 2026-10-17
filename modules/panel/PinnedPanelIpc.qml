import Quickshell.Io
import qs.services

IpcHandler {
    function open(screen: string): string {
        return PanelWindows.pin(Shell.forScreen(screen), target, true) || PanelWindows.missing(screen);
    }

    function close(): string {
        return PanelWindows.unpin(target);
    }

    function toggle(screen: string): string {
        const win = Shell.forScreen(screen);
        return PanelWindows.pin(win, target, !win?.[target].pinned) || PanelWindows.missing(screen);
    }
}
