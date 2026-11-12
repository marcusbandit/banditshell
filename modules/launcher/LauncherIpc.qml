pragma ComponentBehavior: Bound

import QtQml
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.config
import qs.services
import qs.modules.panel
import "../../services/chords.js" as Chords

Scope {
    id: root

    property alias handler: served

    Binding {
        target: Shell
        property: "launcherScreen"
        value: Config.values.launcher.screen
    }

    Component {
        id: rowRunner

        LauncherSearch {
            onLaunch: what => {
                what();
                Hypr.claimNextWindow();
            }
            onLeave: what => what()
        }
    }

    function toggleApp(entry: var): string {
        const windows = Hyprland.toplevels.values.filter(t => Hypr.keyOf(t) !== "" && Apps.entryFor(t.lastIpcObject?.class || t.lastIpcObject?.initialClass || "")?.id === entry.id).map(t => ({
                    address: Hypr.windowAddress(t.address),
                    workspace: t.lastIpcObject?.workspace?.name ?? ""
                }));
        const focused = Hypr.windowAddress(Hyprland.activeToplevel?.address ?? "");
        const todo = Chords.toggleStep(windows, focused);
        const here = Hyprland.focusedMonitor?.activeWorkspace;
        switch (todo.step) {
        case "hide":
            todo.addresses.forEach(a => Hypr.moveToWorkspace(a, Chords.HIDING_PLACE));
            return `hid ${entry.name}`;
        case "bring":
            todo.addresses.forEach(a => Hypr.moveToWorkspace(a, String(here?.id ?? "")));
            Hypr.focusAddress(todo.addresses[0]);
            return `brought back ${entry.name}`;
        case "focus":
            Hypr.focusAddress(todo.addresses[0]);
            return `focused ${entry.name}`;
        }
        return "";
    }

    IpcHandler {
        id: served

        target: "launcher"

        function toggle(): string {
            return PanelWindows.toggle("launcher", "") || PanelWindows.missing("");
        }

        function open(query: string): string {
            const win = Shell.launcherHome();
            if (!win)
                return PanelWindows.missing("");
            win.launcher.show(query);
            return "open";
        }

        function close(): string {
            return PanelWindows.close("launcher");
        }

        function status(): string {
            const win = Shell.showing(w => w.launcher.open);
            return `open=${win?.launcher.open ?? false}`;
        }

        function query(): string {
            const win = Shell.showing(w => w.launcher.open);
            return win?.launcher.concept?.input?.text ?? "";
        }

        function run(id: string, how: string): string {
            if (/^[a-z]+:/.test(id)) {
                const runner = rowRunner.createObject(root, {
                    query: "",
                    screenName: Hypr.focusedScreen
                });
                const ran = runner.runById(id);
                runner.destroy();
                if (ran || /^(app|command|setting):/.test(id))
                    return ran ? `ran ${ran}` : `no launcher row is called ${id}`;
            }
            const entry = Apps.entryById(id) ?? Apps.search(id)[0];
            if (!entry)
                return `no application matches "${id}"`;
            if (how === "toggle") {
                const settled = root.toggleApp(entry);
                if (settled)
                    return settled;
            }
            Apps.launch(entry);
            Hypr.claimNextWindow();
            return `launched ${entry.name}`;
        }

        function add(row: string): string {
            return PushedRows.add(row);
        }

        function remove(tool: string, id: string): string {
            return PushedRows.remove(tool, id);
        }

        function list(tool: string): string {
            return PushedRows.list(tool);
        }

        function reloadPlugin(id: string): string {
            return PluginHost.reload(id);
        }

        function scrub(fraction: string): string {
            const win = Shell.showing(w => w.launcher.open);
            if (!win)
                return "no shell window";
            win.launcher.scrub(parseFloat(fraction));
            return `scrubbed to ${fraction}`;
        }
    }
}
