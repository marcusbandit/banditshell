pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.config
import "quiet-hours.js" as QuietHours
import "notification-rules.js" as Rules

Singleton {
    id: root

    readonly property alias server: server

    property var history: []
    property var popups: []

    readonly property int count: history.length
    readonly property bool any: count > 0

    function timeoutFor(n: var): int {
        if (n?.urgency === NotificationUrgency.Critical)
            return 0;
        return n?.expireTimeout > 0 ? n.expireTimeout : root.defaultTimeout;
    }

    readonly property int maxHistory: Config.values.notifications.maxHistory
    readonly property int defaultTimeout: Config.values.notifications.timeout
    readonly property int maxPopups: Config.values.notifications.maxPopups

    readonly property bool quiet: Config.values.notifications.quiet
    readonly property double quietUntil: Config.values.notifications.quietUntil
    readonly property bool letAlarms: Config.values.notifications.letAlarms
    readonly property bool nightly: Config.values.notifications.nightly
    readonly property string nightFrom: Config.values.notifications.nightFrom
    readonly property string nightTo: Config.values.notifications.nightTo
    readonly property var rules: Config.values.notifications.rules

    readonly property string categoryPrefix: "x-banditshell."

    property double stamp: Date.now()

    readonly property bool nightHolding: root.nightly && QuietHours.nightlyActive(root.stamp, root.nightFrom, root.nightTo)

    readonly property bool quieted: root.holdingAt(root.stamp)

    readonly property string note: {
        if (root.quiet && root.quietUntil > root.stamp)
            return `until ${QuietHours.clockTime(root.quietUntil)} · still collects them`;
        if (!root.quiet && root.nightHolding)
            return `quiet until ${root.nightTo} · every night`;
        return "still collects them";
    }

    readonly property string endsNote: root.quietUntil > Date.now() ? `until ${QuietHours.clockTime(root.quietUntil)}` : "until you turn it off"

    function holdingAt(at: double): bool {
        return QuietHours.holding({
            quiet: root.quiet,
            until: root.quietUntil,
            nightly: root.nightly,
            from: root.nightFrom,
            to: root.nightTo
        }, at);
    }

    function deadlineFor(choice: string): double {
        return QuietHours.deadlineFor(choice, Date.now(), root.nightTo);
    }

    function endsLabel(until: double): string {
        return QuietHours.endsLabel(until, Date.now(), root.nightTo);
    }

    function parseEnds(text: string): string {
        return QuietHours.parseEnds(text);
    }

    function setQuiet(on: bool, ends: string): void {
        const keep = root.quietUntil > Date.now() ? root.quietUntil : 0;
        const until = !on ? 0 : ends ? root.deadlineFor(ends) : keep;
        Config.setMany([["notifications.quiet", on], ["notifications.quietUntil", until]]);
    }

    onQuietChanged: {
        if (Config.loaded && root.quietUntil > 0 && (!root.quiet || root.quietUntil <= Date.now()))
            Config.set("notifications.quietUntil", 0);
    }

    Timer {
        interval: root.quiet && root.quietUntil > 0 ? 1000 : 20000
        repeat: true
        running: Config.loaded && (root.nightly || (root.quiet && root.quietUntil > 0))
        triggeredOnStart: true

        onTriggered: {
            root.stamp = Date.now();
            if (root.quiet && root.quietUntil > 0 && root.stamp >= root.quietUntil)
                Config.setMany([["notifications.quiet", false], ["notifications.quietUntil", 0]]);
        }
    }

    function kindOf(entry: var): string {
        const category = entry?.category ?? "";
        return category.startsWith(root.categoryPrefix) ? category.slice(root.categoryPrefix.length) : "";
    }

    function categoryFor(kind: string): string {
        return `${root.categoryPrefix}${kind}`;
    }

    function rulesFromList(list: var): var {
        return Rules.fromList(list);
    }

    function ruleKeyFor(entry: var): string {
        return Rules.keyFor(entry?.appName, entry?.desktopEntry, AppNotifications.appIdFor(entry));
    }

    function ruleFor(entry: var): var {
        return Rules.ruleFor(root.rules, root.ruleKeyFor(entry));
    }

    function ruleAt(key: string): var {
        return Rules.ruleFor(root.rules, key);
    }

    function setRule(key: string, changes: var): void {
        Config.set("notifications.rules", Rules.withRule(root.rules, key, changes));
    }

    readonly property int candidateLimit: 12

    readonly property var candidates: Rules.candidates(root.history.map(e => root.ruleKeyFor(e)), root.rules, root.candidateLimit)

    function alert(kind: string): void {
        if (!root.holdingAt(Date.now()))
            AlertSounds.play(kind);
    }

    property var pausedBy: []

    readonly property bool paused: root.pausedBy.length > 0

    function pause(who: var): void {
        if (root.pausedBy.includes(who))
            return;
        root.pausedBy = [...root.pausedBy.filter(w => w), who];
    }

    function resume(who: var): void {
        root.pausedBy = root.pausedBy.filter(w => w && w !== who);
    }

    readonly property int exitMs: Appearance.animation.normal

    function beginLeave(entry: var, forget: bool): void {
        if (!entry || entry.leaving)
            return;
        entry.forget = forget;
        entry.leaveElapsed = 0;
        entry.leaving = true;
        root.leaving = [...root.leaving, entry];
    }

    function dismiss(entry: var): void {
        if (!entry || entry.leaving)
            return;
        const spare = entry.pinned;
        entry.pinned = false;
        root.beginLeave(entry, !spare);
    }

    function forget(entry: var): void {
        if (!entry || entry.leaving)
            return;
        entry.pinned = false;
        root.beginLeave(entry, true);
    }

    function expire(entry: var): void {
        root.beginLeave(entry, false);
    }

    function drop(entry: var): void {
        root.leaving = root.leaving.filter(e => e !== entry);
        root.popups = root.popups.filter(e => e !== entry);

        if (!entry.forget && root.history.includes(entry)) {
            entry.leaving = false;
            entry.leaveElapsed = 0;
            return;
        }

        root.history = root.history.filter(e => e !== entry);
        entry.notification?.dismiss();

        root.erase(entry.cached);

        entry.destroy();
    }

    function clear(): void {

        const all = [...new Set([...root.history, ...root.popups, ...root.leaving])];

        root.history = [];
        root.popups = [];
        root.leaving = [];

        for (const entry of all) {

            entry.notification?.dismiss();

            root.erase(entry.cached);

            entry.destroy();
        }
    }

    property var leaving: []

    readonly property string cacheRoot: `${Config.cacheDir}/notifications`

    readonly property string cacheName: `${Quickshell.processId}-${Date.now()}`
    readonly property string cacheDir: `${root.cacheRoot}/${root.cacheName}`

    Process {
        id: sweep

        command: ["sh", "-c", `
            umask 077
            mkdir -p -- "$1/$2" && chmod 700 -- "$1" "$1/$2" && cd -- "$1" || exit 0
            for n in *; do
                case "$n" in
                *.png)
                    rm -f "./$n"
                    ;;
                [0-9]*-[0-9]*)
                    [ "$n" = "$2" ] && continue
                    p=\${n%%-*}
                    [ "$p" != "$3" ] && [ -d "/proc/$p" ] && continue
                    rm -rf "./$n"
                    ;;
                esac
            done
        `, "sh", root.cacheRoot, root.cacheName, `${Quickshell.processId}`]
        running: true
    }

    property var doomed: []

    function erase(path: string): void {
        if (!path)
            return;
        root.doomed = [...root.doomed, path];

        Qt.callLater(root.flush);
    }

    function flush(): void {

        if (eraser.running || root.doomed.length === 0)
            return;
        eraser.command = ["rm", "-f", ...root.doomed];
        root.doomed = [];
        eraser.running = true;
    }

    Process {
        id: eraser

        onExited: Qt.callLater(root.flush)
    }

    function icon(n: var): string {
        if (n?.urgency === NotificationUrgency.Critical)
            return "priority_high";
        return "notifications";
    }

    Component {
        id: entryComponent

        NotificationEntry {}
    }

    readonly property bool counting: !root.paused && root.popups.some(e => e.running)

    Timer {
        interval: 50
        repeat: true
        running: root.counting || root.leaving.length > 0

        onTriggered: {
            if (root.counting) {
                const done = [];
                for (const entry of root.popups)
                    if (entry.tick(interval))
                        done.push(entry);
                for (const entry of done)
                    root.expire(entry);
            }

            const gone = [];
            for (const entry of root.leaving) {
                entry.leaveElapsed += interval;
                if (entry.leaveElapsed >= root.exitMs)
                    gone.push(entry);
            }
            for (const entry of gone)
                root.drop(entry);
        }
    }

    NotificationServer {
        id: server

        keepOnReload: false
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        actionsSupported: true
        persistenceSupported: true

        onNotification: notification => {

            notification.tracked = true;

            const entry = entryComponent.createObject(root, {
                notification: notification,
                time: Date.now(),
                timeout: root.timeoutFor(notification),

                cacheDir: root.cacheDir
            });

            entry.orphaned.connect(path => root.erase(path));

            entry.liveChanged.connect(() => {
                if (!entry.live && root.popups.includes(entry))
                    root.expire(entry);
            });

            const evicted = [entry, ...root.history].slice(root.maxHistory);
            root.history = [entry, ...root.history].slice(0, root.maxHistory);
            for (const old of evicted) {

                root.popups = root.popups.filter(e => e !== old);
                root.leaving = root.leaving.filter(e => e !== old);

                old.notification?.dismiss();

                root.erase(old.cached);
                old.destroy();
            }

            if (notification.transient)
                root.history = root.history.filter(e => e !== entry);

            const kind = root.kindOf(entry);
            const held = root.holdingAt(Date.now()) && !(kind === "alarm" && root.letAlarms);
            const rule = root.ruleFor(entry);

            if (!held && rule.pop) {
                const shown = [entry, ...root.popups];
                root.popups = shown.slice(0, root.maxPopups);
                for (const old of shown.slice(root.maxPopups))
                    root.expire(old);
            }

            if (!held && rule.snd)
                AlertSounds.play(AlertSounds.kinds.includes(kind) ? kind : "notification");
        }
    }

}
