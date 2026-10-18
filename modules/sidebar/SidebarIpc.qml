import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.panel
import "../cli.js" as Words

IpcHandler {
    target: "sidebar"

    function off(screen: string): string {
        const where = PanelWindows.resolveScreen(screen);
        if (!where)
            return `no such screen: ${screen}`;

        if (where === "all") {
            const was = Quickshell.screens.every(s => !SidebarState.visibleOn(s.name));
            SidebarState.setAll(false);
            return was ? "all screens: off (was already)" : "all screens: off";
        }
        if (!SidebarState.visibleOn(where))
            return `${where} already off`;
        SidebarState.setOn(where, false);
        return `${where}: off`;
    }

    function on(screen: string): string {
        const where = PanelWindows.resolveScreen(screen);
        if (!where)
            return `no such screen: ${screen}`;

        if (where === "all") {
            const was = Quickshell.screens.every(s => SidebarState.visibleOn(s.name));
            SidebarState.setAll(true);
            return was ? "all screens: on (was already)" : "all screens: on";
        }
        if (SidebarState.visibleOn(where))
            return `${where} already on`;
        SidebarState.setOn(where, true);
        return `${where}: on`;
    }

    function toggle(screen: string): string {
        const where = PanelWindows.resolveScreen(screen);
        if (!where)
            return `no such screen: ${screen}`;

        if (where === "all") {
            const next = !SidebarState.enabled;
            SidebarState.setAll(next);
            return `all screens: ${next ? "on" : "off"}`;
        }
        const next = !SidebarState.visibleOn(where);
        SidebarState.setOn(where, next);
        return `${where}: ${next ? "on" : "off"}`;
    }

    function status(): string {
        const head = `${SidebarState.enabled ? "on" : "off"} default`;
        const rows = Quickshell.screens.map(s => [
                s.name === Hypr.focusedScreen ? "*" : " ",
                s.name,
                SidebarState.visibleOn(s.name) ? "on" : "off",
                s.name in SidebarState.perScreen ? "own" : "default"
            ]);
        return rows.length ? `${head}\n${Words.columns(rows)}` : head;
    }
}
