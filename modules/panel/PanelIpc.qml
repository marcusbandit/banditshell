import Quickshell.Io

IpcHandler {
    function toggle(): string {
        return PanelWindows.toggle(target, "") || PanelWindows.missing("");
    }

    function open(): string {
        PanelWindows.open(target, "");
        return "open";
    }

    function close(): string {
        return PanelWindows.close(target);
    }
}
