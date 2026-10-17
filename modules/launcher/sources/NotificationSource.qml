import QtQuick
import qs.config
import qs.services
import "../../../services/notification-search.js" as NotificationSearch
import "../../../services/notification-timing.js" as Timing

QtObject {
    id: root

    required property var search

    readonly property var kinds: ["notification", "thread"]

    readonly property var asked: NotificationSearch.ask(root.search.text)
    readonly property bool explicit: root.asked.explicit

    readonly property bool blending: !root.explicit && Config.values.launcher.typing.notifications && root.asked.term.length >= 3

    readonly property string screenName: root.search.screenName
    readonly property bool onStage: !root.screenName || !Shell.offStageScreen || root.screenName === Shell.offStageScreen

    readonly property bool active: (root.explicit || root.blending) && root.onStage && root.search.text.length > 0

    readonly property var found: root.active ? NotificationSearch.find(Notifications.history, root.asked).slice(0, root.explicit ? 40 : 3) : []

    readonly property bool intent: root.explicit && root.onStage

    readonly property var groups: [
        {
            key: "notifications",
            title: "Notifications",
            items: root.found.map(thread => root.row(thread))
        }
    ]

    readonly property var caps: ({
            notifications: 40
        })

    readonly property var phrases: [
        {
            head: "notifications ",
            picks: ["unread", "held", "from "].concat(NotificationSearch.apps(Notifications.history, 8).map(app => `from ${app}`))
        }
    ]

    property var lastShown: []

    onFoundChanged: if (root.explicit)
        root.lastShown = root.found.reduce((out, thread) => out.concat(thread.entries), [])

    onExplicitChanged: if (!root.explicit) {
        Notifications.markSeenOf(root.lastShown);
        root.lastShown = [];
    }

    function firstLine(text: string): string {
        const line = String(text ?? "").split("\n").find(l => l.trim() !== "") ?? "";
        return line.replace(/<[^>]*>/g, "").trim().slice(0, 160);
    }

    function row(thread: var): var {
        const entry = thread.newest;
        const count = thread.entries.length;
        const parts = [NotificationSearch.line(entry, count, Notifications.now)];
        if (entry.withheld)
            parts.push("held");
        return {
            key: `${count > 1 ? "thread" : "notification"}:${entry.id}`,
            kind: count > 1 ? "thread" : "notification",
            entry: entry,
            thread: thread,
            label: root.firstLine(entry.summary) || root.firstLine(entry.body) || "(no message)",
            detail: parts.filter(p => p).join(" · "),
            icon: entry.urgency === 2 ? "priority_high" : "notifications",
            iconSource: entry.mark ?? "",
            score: root.explicit ? Infinity : 0.3
        };
    }

    function appWord(entry: var): string {
        return String(entry.appName ?? "").toLowerCase().split(" ")[0];
    }

    function drill(row: var): bool {
        const entry = row.entry;
        const word = root.appWord(entry);
        if (!word || row.kind !== "thread")
            return false;
        root.search.retype(`notifications from ${word} ${String(entry.summary ?? "").trim().toLowerCase()} `);
        return true;
    }

    function open(row: var): void {
        const entries = row.thread.entries;
        root.search.launch(() => {
            Notifications.activate(entries[0]);
            for (const older of entries.slice(1))
                Notifications.dismiss(older);
        });
    }

    function activate(row: var): void {
        if (!root.drill(row))
            root.open(row);
    }

    function complete(row: var): bool {
        const word = root.appWord(row.entry);
        if (!word)
            return false;
        root.search.retype(`notifications from ${word} `);
        return true;
    }

    function inquire(row: var, prompt: string, suggestion: string, take: var): void {
        root.search.inquire({
            key: row.key,
            kind: row.kind,
            label: row.label,
            ask: {
                prompt: prompt,
                icon: "notifications",
                suggestion: suggestion,
                take: take
            }
        });
    }

    function ruleKey(row: var): string {
        return Notifications.ruleKeyFor(row.entry);
    }

    function who(row: var): string {
        return row.entry.appName || "this app";
    }

    function actionsFor(row: var): var {
        const entry = row.entry;
        const entries = row.thread.entries;
        const key = root.ruleKey(row);
        const muted = Notifications.isMuted(key);
        const acts = [];
        if (row.kind === "thread")
            acts.push({
                icon: "forum",
                label: `Show all ${entries.length}`,
                short: "All",
                run: () => root.drill(row)
            });
        acts.push({
            icon: "open_in_new",
            label: `Open ${root.who(row)}`,
            short: "Open",
            run: () => root.open(row)
        });
        if (entry.canReply)
            acts.push({
                icon: "reply",
                label: "Reply",
                run: () => root.inquire(row, `Reply to ${entry.summary || root.who(row)}`, "", text => {
                    Notifications.reply(entry, text);
                })
            });
        acts.push({
            icon: "content_copy",
            label: "Copy text",
            run: () => {
                const text = entry.body || entry.summary;
                root.search.leave(() => Clipboard.copy({
                        text: text
                    }));
            }
        }, {
            icon: "snooze",
            label: "Snooze",
            tucked: true,
            run: () => root.inquire(row, "Snooze for how long? (10m, 1h, day)", "10m", text => {
                const ms = Timing.snoozeLength(text);
                if (ms > 0)
                    for (const e of entries)
                        Notifications.snooze(e, ms);
            })
        }, {
            icon: muted ? "notifications_active" : "notifications_off",
            label: muted ? `Unmute ${root.who(row)}` : `Mute ${root.who(row)}`,
            tucked: true,
            run: () => {
                if (muted)
                    Notifications.unmute(key);
                else
                    root.inquire(row, `Mute ${root.who(row)} for how long? (1h, day, always)`, "1h", text => {
                        const ms = Timing.muteLength(text);
                        if (ms >= 0)
                            Notifications.mute(key, ms);
                    });
            }
        }, {
            icon: "delete",
            label: row.kind === "thread" ? `Dismiss ${entries.length}` : "Dismiss",
            short: "Dismiss",
            run: () => {
                for (const e of entries)
                    Notifications.forget(e);
            }
        });
        return acts;
    }

    readonly property var commands: [
        {
            id: "dismiss",
            icon: "clear_all",
            label: "Clear notifications",
            words: "dismiss clear notifications history",
            detail: Notifications.count === 1 ? "1 notification" : `${Notifications.count} notifications`,
            hidden: !Notifications.count,
            stay: true,
            run: () => Notifications.clear()
        },
        {
            id: "quiet",
            icon: "do_not_disturb_on",
            label: "Do not disturb",
            words: "do not disturb dnd quiet silence notifications",
            toggle: Notifications.quiet,
            stay: true,
            run: () => Notifications.setQuiet(!Notifications.quiet, "")
        },
        root.quietFor("hour", "Do not disturb for an hour", "dnd 1h hour"),
        root.quietFor("evening", "Do not disturb until evening", "dnd evening tonight"),
        root.quietFor("tomorrow", "Do not disturb until tomorrow", "dnd tomorrow morning")
    ]

    function quietFor(choice: string, label: string, words: string): var {
        const ends = Notifications.parseEnds(choice);
        return {
            id: `quiet:${choice}`,
            icon: "do_not_disturb_on",
            label: label,
            words: `${words} do not disturb quiet notifications`,
            detail: `until ${TimeFormat.time(new Date(Notifications.deadlineFor(ends)), false)}`,
            stay: true,
            run: () => Notifications.setQuiet(true, ends)
        };
    }
}
