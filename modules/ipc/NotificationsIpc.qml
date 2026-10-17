pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.modules
import "../cli.js" as Words

Scope {
    id: root

    function quietState(): string {
        if (Notifications.quiet)
            return `on ${Notifications.endsNote}`;
        return Notifications.holdingAt(Date.now()) ? `on until ${Notifications.nightTo}, every night` : "off";
    }

    function setQuiet(on: bool, ends: string): string {
        const label = ends ? Notifications.parseEnds(ends) : "";
        if (ends && !label)
            return `refused: ends how? (hour, evening, tomorrow or never; not ${ends})`;
        if (!Config.writable)
            return `refused: ${Config.path} has not been read, so nothing can be changed`;
        Notifications.setQuiet(on, label);
        return `quiet: ${root.quietState()}`;
    }

    PinnedPanelIpc {
        target: "notifications"

        function clear(): string {
            Notifications.clear();
            return "cleared";
        }

        function status(screen: string): string {
            const win = Shell.forScreen(screen);
            if (!win)
                return PanelWindows.missing(screen);
            return `count=${Notifications.count} pinned=${win.notifications.pinned} expanded=${win.notifications.expanded}`;
        }

        function held(app: string): string {
            if (!app)
                return "0";
            const key = app.toLowerCase();
            const attended = e => e?.held && (e.appName ?? "").toLowerCase() === key;
            return Notifications.popups.some(attended) || Notifications.history.some(attended) ? "1" : "0";
        }
    }

    IpcHandler {
        target: "quiet"

        function on(ends: string): string {
            return root.setQuiet(true, ends);
        }

        function off(): string {
            return root.setQuiet(false, "");
        }

        function toggle(ends: string): string {
            return root.setQuiet(!Notifications.quiet, ends);
        }

        function status(): string {
            return Words.columns([["quiet", root.quietState()], ["every night", Notifications.nightly ? `${Notifications.nightFrom} to ${Notifications.nightTo}` : "off"], ["alarms", Notifications.letAlarms ? "let through" : "held back"]]);
        }
    }
}
