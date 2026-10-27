import Quickshell
import Quickshell.Io
import qs.config
import qs.services

IpcHandler {
    target: "shell"

    function status(): string {
        const win = Shell.showing(w => w.launcher.open);
        return [`compositor  ${Compositor.name}`, `following   ${Appearance.follows}`, `theme       ${Themes.activeName}`, `rounding    ${Appearance.rounding.base}`, `corner      power ${Appearance.rounding.power} (compositor says ${Compositor.roundingPower})`, `tiers       ${Appearance.rounding.small} / ${Appearance.rounding.normal} / ${Appearance.rounding.large} from base ${Appearance.rounding.base}, available=${Compositor.available}`, `gap         ${Appearance.sizes.gap} outer, ${Compositor.gapsIn} inner`, `wm border   ${Compositor.borderSize}`, `window edge ${Appearance.sizes.windowRadius} (the one radius)`, `band        ${Appearance.sizes.band}`, `bar         ${Appearance.sizes.sidebarWidth}`, `apps        ${Apps.all.length} listed, ${DesktopEntries.applications.values.length} on disk`, `launcher    ${win?.launcher.open ? "open" : "closed"}, ${win?.launcher.resultCount ?? 0} results, ${Math.round(win?.launcher.drawnHeight ?? 0)}px tall`, `scroll      ${win?.launcher.scrollInfo ?? "-"}`, `screens     ${Shell.screenNames().join(", ")}`].join("\n");
    }

    function themes(): string {
        return Themes.availableNames.map(n => n === Themes.activeName ? `* ${n}` : `  ${n}`).join("\n");
    }

    function get(key: string): string {
        const v = Config.get(key);
        return v === undefined ? `no such setting: ${key}` : JSON.stringify(v);
    }

    function set(key: string, value: string): string {
        let parsed = value;
        try {
            parsed = JSON.parse(value);
        } catch (e) {}
        const span = Trace.begin("config write", key);
        Config.set(key, parsed);
        Trace.step("set", span);
        Config.flush();
        return `${key} = ${JSON.stringify(parsed)}`;
    }

    function flush(): string {
        Config.flush();
        return "saved";
    }
}
