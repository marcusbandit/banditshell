import Quickshell.Io

IpcHandler {
    function toggle(screen: string): string {
        return PanelWindows.toggle(target, screen) || PanelWindows.missing(screen);
    }

    function open(screen: string): string {
        return PanelWindows.open(target, screen) || PanelWindows.missing(screen);
    }

    function close(): string {
        return PanelWindows.close(target);
    }
}
