import qs.services
import qs.modules

PinnedPanelIpc {
    target: "island"

    function status(screen: string): string {
        const win = Shell.forScreen(screen);
        if (!win)
            return PanelWindows.missing(screen);
        return `pinned=${win.island.pinned} showing=${win.island.presentation} activities=${win.island.activities.length} notifications=${win.island.alerts.length} situation="${win.island.situation}"`;
    }
}
