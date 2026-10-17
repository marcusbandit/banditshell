import qs.services
import qs.modules

ScreenPanelIpc {
    target: "hotkeys"

    function status(screen: string): string {
        const win = screen ? Shell.forScreen(screen) : Shell.showing(w => w.hotkeys.open);
        if (!win)
            return PanelWindows.missing(screen);
        const sheet = win.hotkeys.item;
        if (!sheet)
            return "open=false";
        return `open=${sheet.open} binds=${sheet.rows.length} woven=${sheet.woven} groups=${sheet.sections.length}`;
    }
}
