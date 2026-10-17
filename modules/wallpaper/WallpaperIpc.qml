pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.modules.panel
import "../cli.js" as Words

Scope {
    id: root

    function walkWallpaper(screen: string, delta: int): string {
        if (!Wallpaper.available.length)
            return "nothing to step to";

        const where = PanelWindows.resolveScreen(screen);
        if (!where)
            return `no such screen: ${screen}`;

        if (where === "all") {
            Wallpaper.stepAll(delta);
            return `all screens: ${Wallpaper.name || "-"}`;
        }
        Wallpaper.stepOn(where, delta);
        return `${where}: ${Wallpaper.nameOf(Wallpaper.currentOn(where))}`;
    }

    IpcHandler {
        target: "wallpaper"

        function toggle(): string {
            Wallpaper.toggle();
            return Wallpaper.enabled ? "on" : "off";
        }

        function on(): string {
            Wallpaper.setEnabled(true);
            return "on";
        }

        function off(): string {
            Wallpaper.setEnabled(false);
            return "off";
        }

        function next(screen: string): string {
            return root.walkWallpaper(screen, 1);
        }

        function prev(screen: string): string {
            return root.walkWallpaper(screen, -1);
        }

        function set(path: string, screen: string): string {
            if (!path)
                return "usage: wallpaper set <path> [screen|all]";

            const where = PanelWindows.resolveScreen(screen);
            if (!where)
                return `no such screen: ${screen}`;

            if (where === "all") {
                Wallpaper.setAll(path);
                return `all screens: ${Wallpaper.nameOf(path)}`;
            }
            Wallpaper.setOn(where, path);
            return `${where}: ${Wallpaper.nameOf(Wallpaper.currentOn(where))}`;
        }

        function clear(screen: string): string {
            const where = PanelWindows.resolveScreen(screen);
            if (!where)
                return `no such screen: ${screen}`;

            if (where === "all") {
                Wallpaper.setAll(Wallpaper.current);
                return `all screens follow the default: ${Wallpaper.name || "-"}`;
            }
            if (!Wallpaper.hasOwn(where))
                return `${where} already follows the default`;
            Wallpaper.clearOn(where);
            return `${where} follows the default: ${Wallpaper.nameOf(Wallpaper.currentOn(where))}`;
        }

        function palette(): string {
            if (!Wallpaper.palette.length)
                return "no palette (nothing measured yet, or the file could not be read)";
            return Wallpaper.palette.map(c => `${c.colour} ${Math.round(c.share * 100)}%`).join("\n");
        }

        function status(): string {
            const head = `${Wallpaper.enabled ? "on" : "off"} default ${Wallpaper.kindOf(Wallpaper.current) || "?"} ${Wallpaper.nameOf(Wallpaper.current) || "(nothing set)"} ${Wallpaper.available.length} in ${Wallpaper.dir}`;

            const rows = Quickshell.screens.map(s => {
                const own = Wallpaper.hasOwn(s.name);
                const path = Wallpaper.currentOn(s.name);
                const bits = [s.name === Hypr.focusedScreen ? "*" : " ", s.name, `${Math.round(s.width * s.devicePixelRatio)}x${Math.round(s.height * s.devicePixelRatio)}`, Wallpaper.nameOf(path) || "-", own ? "own" : "default"];

                const seen = Wallpaper.previewOn(s.name);
                if (seen)
                    bits.push(`showing ${Wallpaper.nameOf(seen)}`);
                return bits;
            });

            return rows.length ? `${head}\n${Words.columns(rows)}` : head;
        }

        function list(screen: string): string {
            const name = screen || Hypr.focusedScreen;
            const aspect = Wallpaper.screenAspect(name);
            if (!aspect)
                return `no such screen: ${name || "(none focused)"}`;

            const worn = Wallpaper.currentOn(name);
            const rows = Wallpaper.available.map(p => {
                const a = Wallpaper.aspectOf(p);
                return [
                    p === worn ? "*" : " ",
                    Wallpaper.fits(p, aspect) ? "fits" : "-",

                    a ? a.toFixed(2) : "?",
                    Wallpaper.nameOf(p)
                ];
            });

            const kept = rows.filter(r => r[1] === "fits").length;
            const head = `${name} ${aspect.toFixed(2)} · ${kept} of ${rows.length} fit · tolerance ${Config.values.wallpaper.fit}`;
            return rows.length ? `${head}\n${Words.columns(rows)}` : head;
        }
    }

    ScreenPanelIpc {
        target: "wallpapers"

        function status(): string {
            const win = Shell.showing(w => w.wallpapers.open);
            if (!win)
                return "no shell window";
            const on = win.screen?.name ?? "";
            return `${win.wallpapers.open ? "open" : "closed"} on=${on || "?"} scope=${win.wallpapers.item?.everywhere ? "all" : "here"} showing=${Wallpaper.shownNameOn(on) || "-"} set=${Wallpaper.nameOf(Wallpaper.currentOn(on)) || "-"} of ${Wallpaper.available.length}`;
        }
    }
}
