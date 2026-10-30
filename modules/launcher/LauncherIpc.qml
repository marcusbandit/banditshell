pragma ComponentBehavior: Bound

import QtQml
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.panel

Scope {
    id: root

    property alias handler: served

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

    IpcHandler {
        id: served

        target: "launcher"

        function toggle(): string {
            return PanelWindows.toggle("launcher", "") || PanelWindows.missing("");
        }

        function open(query: string): string {
            const win = Shell.forScreen("");
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

        function run(id: string): string {
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

        function scrub(fraction: string): string {
            const win = Shell.showing(w => w.launcher.open);
            if (!win)
                return "no shell window";
            win.launcher.scrub(parseFloat(fraction));
            return `scrubbed to ${fraction}`;
        }
    }
}
