pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.modules
import "../cli.js" as Words

Scope {
    id: root

    function showHistory(screen: string, query: string): string {
        const win = Shell.forScreen(screen);
        if (!win)
            return PanelWindows.missing(screen);
        win.launcher.show(query ? `notifications ${query}` : "notifications ");
        return "open";
    }

    function oneLine(entry: var): string {
        const said = entry.summary && entry.body ? `${entry.summary}: ${entry.body}` : entry.summary || entry.body || "";
        return said.replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim().slice(0, 120);
    }

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

    IpcHandler {
        target: "notifications"

        function open(screen: string): string {
            return root.showHistory(screen, "");
        }

        function search(query: string): string {
            return root.showHistory("", query);
        }

        function close(): string {
            for (const win of Shell.windows)
                if (win.launcher.open && Notifications.asking(win.launcher.concept?.input?.text ?? ""))
                    win.launcher.hide();
            return "closed";
        }

        function toggle(screen: string): string {
            const win = screen ? Shell.forScreen(screen) : Shell.showing(w => w.launcher.open);
            if (!win)
                return PanelWindows.missing(screen);
            if (win.launcher.open && Notifications.asking(win.launcher.concept?.input?.text ?? "")) {
                win.launcher.hide();
                return "closed";
            }
            return root.showHistory(screen, "");
        }

        function status(screen: string): string {
            const win = Shell.forScreen(screen);
            if (!win)
                return PanelWindows.missing(screen);
            return `count=${Notifications.count} unread=${Notifications.unread} held=${Notifications.heldCount} alerts=${Notifications.popups.length} open=${win.launcher.open && Notifications.asking(win.launcher.concept?.input?.text ?? "")}`;
        }

        function clear(): string {
            Notifications.clear();
            return "cleared";
        }

        function held(app: string): string {
            if (!app)
                return "0";
            const key = app.toLowerCase();
            const attended = e => e?.held && (e.appName ?? "").toLowerCase() === key;
            return Notifications.popups.some(attended) || Notifications.history.some(attended) ? "1" : "0";
        }

        function list(filter: string, app: string): string {
            const word = filter === "unread" || filter === "held" ? filter : "";
            const rows = Notifications.find(`notifications ${word} ${app ? `from ${app}` : ""}`);
            if (rows.length === 0)
                return "nothing";
            return rows.map((thread, i) => `${i + 1}\t${thread.newest.appName}\t${Notifications.ageOf(thread.newest.time) || "now"}\t${thread.entries.length}\t${root.oneLine(thread.newest)}`).join("\n");
        }

        function act(): string {
            const entry = Notifications.front();
            if (!entry)
                return "refused: no alert is showing";
            Notifications.activate(entry);
            return `opened ${entry.appName}`;
        }

        function dismiss(which: string): string {
            if (which === "all") {
                const all = Notifications.popups.filter(e => !e.leaving);
                for (const entry of all)
                    Notifications.dismiss(entry);
                return `dismissed ${all.length}`;
            }
            if (which && which !== "front")
                return `refused: dismiss front or all, not ${which}`;
            const entry = Notifications.front();
            if (!entry)
                return "refused: no alert is showing";
            Notifications.dismiss(entry);
            return `dismissed ${entry.appName}`;
        }

        function reply(text: string): string {
            const entry = Notifications.front();
            if (!entry)
                return "refused: no alert is showing";
            if (!entry.canReply)
                return `refused: ${entry.appName} does not take a reply`;
            if (!text.trim())
                return "refused: reply with what?";
            return Notifications.reply(entry, text) ? `replied to ${entry.appName}` : "refused: the reply was not sent";
        }

        function snooze(duration: string): string {
            const entry = Notifications.front();
            if (!entry)
                return "refused: no alert is showing";
            const ms = Notifications.snoozeLength(duration);
            if (!(ms > 0))
                return `refused: snooze for how long? (10m, 1h, day; not ${duration})`;
            Notifications.snooze(entry, ms);
            return `snoozed ${entry.appName} for ${duration || "10m"}`;
        }

        function mute(app: string, duration: string): string {
            if (!app)
                return "refused: mute which app?";
            const ms = Notifications.muteLength(duration);
            if (ms < 0)
                return `refused: for how long? (hour, day, 30m or never; not ${duration})`;
            if (!Config.writable)
                return `refused: ${Config.path} has not been read, so nothing can be changed`;
            const key = Notifications.keyForApp(app);
            Notifications.mute(key, ms);
            return ms > 0 ? `muted ${key} until ${TimeFormat.time(new Date(Date.now() + ms), false)}` : `muted ${key}`;
        }

        function unmute(app: string): string {
            if (!app)
                return "refused: unmute which app?";
            if (!Config.writable)
                return `refused: ${Config.path} has not been read, so nothing can be changed`;
            const key = Notifications.keyForApp(app);
            Notifications.unmute(key);
            return `unmuted ${key}`;
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
