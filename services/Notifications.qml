pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.config
import "quiet-hours.js" as QuietHours
import "notification-rules.js" as Rules
import "notification-search.js" as Search
import "notification-shelf.js" as Shelf
import "notification-store.js" as Store
import "notification-timing.js" as Timing

Singleton {
    id: root

    readonly property alias server: server

    property var history: []
    property var popups: []

    readonly property int count: history.length
    readonly property bool any: count > 0

    readonly property int unread: root.history.filter(e => !e.seen && !e.leaving).length

    property double now: Date.now()

    readonly property bool muting: Object.values(root.rules).some(rule => rule?.muteUntil > root.now)

    onRulesChanged: root.now = Date.now()

    Timer {
        interval: 30000
        repeat: true
        running: root.history.length > 0 || root.muting
        onTriggered: root.now = Date.now()
    }

    function ageOf(time: double): string {
        return Search.age(time, root.now);
    }

    function threadsOf(list: var): var {
        return Search.threads(list);
    }

    function byApp(list: var): var {
        return Search.byApp(list);
    }

    readonly property int heldCount: root.history.filter(e => e.withheld && !e.leaving).length

    function asking(text: string): bool {
        return Search.ask(text).explicit;
    }

    function find(text: string): var {
        return Search.find(root.history, Search.ask(text));
    }

    function muteLength(text: string): double {
        return Timing.muteLength(text);
    }

    function snoozeLength(text: string): double {
        return Timing.snoozeLength(text);
    }

    function markSeenOf(list: var): void {
        let changed = false;
        for (const entry of list ?? [])
            if (entry && !entry.seen) {
                entry.seen = true;
                changed = true;
            }
        if (changed)
            root.save();
    }

    function markSeen(): void {
        let changed = false;
        for (const entry of root.history)
            if (!entry.seen) {
                entry.seen = true;
                changed = true;
            }
        if (changed)
            root.save();
    }

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
    readonly property bool criticalThrough: Config.values.notifications.criticalThrough
    readonly property bool nightly: Config.values.notifications.nightly
    readonly property string nightFrom: Config.values.notifications.nightFrom
    readonly property string nightTo: Config.values.notifications.nightTo
    readonly property var rules: Config.values.notifications.rules

    property double stamp: Date.now()

    readonly property bool nightHolding: root.nightly && QuietHours.nightlyActive(root.stamp, root.nightFrom, root.nightTo)

    readonly property bool quieted: root.holdingAt(root.stamp)

    readonly property string quietLine: QuietHours.quietLine({
        quiet: root.quiet,
        until: root.quietUntil,
        nightly: root.nightly,
        from: root.nightFrom,
        to: root.nightTo
    }, root.stamp)

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

    function quietTill(until: double): void {
        Config.setMany([["notifications.quiet", true], ["notifications.quietUntil", until > Date.now() ? until : 0]]);
    }

    function dropSpentDeadline(): void {
        if (Config.loaded && root.quietUntil > 0 && (!root.quiet || root.quietUntil <= Date.now()))
            Config.set("notifications.quietUntil", 0);
    }

    property double quietSince: 0

    signal heldReleased(int count)

    onQuietedChanged: {
        if (root.quieted || !Config.loaded)
            return;
        const waiting = root.history.filter(e => e.withheld && !e.seen && !e.leaving).length;
        if (waiting > 0)
            root.heldReleased(waiting);
    }

    onQuietChanged: {
        root.quietSince = root.quiet && Config.loaded ? Date.now() : 0;
        Qt.callLater(root.dropSpentDeadline);
    }

    Timer {
        interval: root.quiet && root.quietUntil > 0 ? 1000 : 20000
        repeat: true
        running: Config.loaded && (root.nightly || (root.quiet && root.quietUntil > 0))
        triggeredOnStart: true

        onTriggered: {
            root.stamp = Date.now();
            if (root.quiet && root.quietUntil > root.quietSince && root.stamp >= root.quietUntil)
                Config.setMany([["notifications.quiet", false], ["notifications.quietUntil", 0]]);
        }
    }

    function kindOf(entry: var): string {
        return Notify.kindOf(entry?.category ?? "");
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

    function keyForApp(text: string): string {
        const want = String(text ?? "").trim().toLowerCase();
        if (!want)
            return "";
        const known = Object.keys(root.rules).find(k => k.toLowerCase() === want);
        if (known)
            return known;
        const entry = root.history.find(e => root.ruleKeyFor(e).toLowerCase() === want || Search.appMatches(e, want));
        return entry ? root.ruleKeyFor(entry) : want;
    }

    function mute(appKey: string, ms: double): void {
        if (!appKey)
            return;
        if (ms > 0)
            root.setRule(appKey, { muteUntil: Date.now() + ms });
        else
            root.setRule(appKey, { pop: false, snd: false });
    }

    function unmute(appKey: string): void {
        if (appKey)
            root.setRule(appKey, { pop: true, snd: true, muteUntil: 0 });
    }

    function mutedUntil(appKey: string): double {
        const rule = root.ruleAt(appKey);
        return Timing.muted(rule, Date.now()) ? rule.muteUntil : 0;
    }

    function hushUntil(choice: string, at: double): double {
        return QuietHours.hushUntil(choice, at, root.nightTo);
    }

    function endsAt(until: double, at: double): string {
        return QuietHours.endsAt(until, at);
    }

    function mutedLabel(appKey: string): string {
        const rule = root.ruleAt(appKey);
        if (rule.muteUntil > root.now)
            return `until ${root.endsAt(rule.muteUntil, root.now)}`;
        return Rules.muted(rule, root.now) ? "until I\u00a0unmute" : "";
    }

    function endMute(appKey: string): void {
        if (appKey)
            root.setRule(appKey, Rules.unmuted(root.ruleAt(appKey), Date.now()));
    }

    function isMuted(appKey: string): bool {
        const rule = root.ruleAt(appKey);
        return !rule.pop || Timing.muted(rule, Date.now());
    }

    readonly property int candidateLimit: 12

    readonly property var candidates: Rules.candidates(root.history.map(e => root.ruleKeyFor(e)), root.rules, root.candidateLimit)

    function alert(kind: string): void {
        if (!root.holdingAt(Date.now()))
            AlertSounds.play(kind);
    }

    Connections {
        target: Notify

        function onAlertRequested(kind: string): void {
            root.alert(kind);
        }

        function onPostRequested(spec: var): void {
            Quickshell.execDetached(Notify.commandFor(spec));
        }
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
        root.beginLeave(entry, true);
    }

    function answered(entry: var): void {
        if (!entry || entry.leaving)
            return;
        entry.answered = true;
        root.dismiss(entry);
    }

    function openApp(entry: var): bool {
        const id = AppNotifications.appIdFor(entry);
        const app = id ? Apps.entryById(id) : null;
        if (!app)
            return false;
        const mine = { marks: Launching.marksFor(app) };
        const window = [].concat(...Object.values(Hypr.clients)).find(c => Launching.fits(mine, Hypr.classOf(c)));
        if (window) {
            Hypr.focusClient(window);
        } else {
            Apps.launch(app);
            Hypr.claimNextWindow();
        }
        return true;
    }

    signal reading(var entry)

    function activate(entry: var): bool {
        if (!entry || entry.leaving)
            return false;
        const primary = entry.live ? (entry.notification?.actions ?? []).find(a => a.identifier === "default") : null;
        if (primary)
            primary.invoke();
        else if (!root.openApp(entry)) {
            root.reading(entry);
            return false;
        }
        root.markSeenOf([entry]);
        if (root.popups.includes(entry))
            root.expire(entry);
        return true;
    }

    function reply(entry: var, text: string): bool {
        if (!entry?.reply(text))
            return false;
        root.answered(entry);
        return true;
    }

    function front(): var {
        const standing = root.popups.filter(e => !e.leaving);
        return standing.find(e => e.urgency === NotificationUrgency.Critical) ?? standing[0] ?? null;
    }

    property var snoozed: []

    function snooze(entry: var, ms: double): bool {
        if (!entry || entry.leaving || !(ms > 0))
            return false;
        root.snoozed = Timing.snoozeAdd(root.snoozed, entry, Date.now() + ms);
        entry.seen = false;
        if (root.popups.includes(entry))
            root.expire(entry);
        return true;
    }

    property var hushed: null

    function hush(entry: var, kind: string, until: double): bool {
        if (!entry || entry.leaving)
            return false;
        const key = root.ruleKeyFor(entry);
        const ms = kind === "unmute" || until === 0 ? 0 : until - Date.now();
        if (!Timing.hushAllowed(kind, ms, key))
            return false;
        const record = {
            kind: kind,
            entry: entry,
            app: entry.appName,
            key: key,
            until: until,
            was: Object.prototype.hasOwnProperty.call(root.rules, key) ? root.rules[key] : undefined,
            popups: Shelf.hushedPopups(root.popups, root.popups.map(e => root.ruleKeyFor(e)), entry, key, kind),
            snooze: root.snoozed.find(item => item.entry === entry) ?? null,
            seen: entry.seen
        };
        root.letGo();
        if (kind === "snooze")
            root.snooze(entry, ms);
        else if (kind === "unmute")
            root.endMute(key);
        else {
            root.mute(key, ms);
            for (const p of record.popups)
                root.expire(p.entry);
        }
        root.hushed = record;
        return true;
    }

    function unhush(record: var): void {
        if (record.kind === "snooze") {
            root.snoozed = root.snoozed.filter(item => item.entry !== record.entry).concat(record.snooze ? [record.snooze] : []);
            if (record.entry)
                record.entry.seen = record.seen;
        } else {
            Config.set("notifications.rules", Rules.restored(root.rules, record.key, record.was));
        }
        const back = record.popups.filter(p => p.entry && root.history.includes(p.entry));
        for (const p of back) {
            p.entry.leaving = false;
            p.entry.leaveElapsed = 0;
        }
        root.leaving = root.leaving.filter(e => !back.some(p => p.entry === e));
        if (back.length > 0)
            root.showPopups(Shelf.placed(root.popups, back));
    }

    function wake(entry: var): void {
        if (!root.history.includes(entry) || entry.leaving)
            return;
        if (!(entry.timeout > 0) && entry.urgency !== NotificationUrgency.Critical)
            entry.timeout = root.defaultTimeout;
        entry.remaining = 1;
        entry.seen = false;
        root.showPopups([entry, ...root.popups.filter(e => e !== entry)]);
        if (!root.holdingAt(Date.now()))
            AlertSounds.play("notification");
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.snoozed.length > 0

        onTriggered: {
            const split = Timing.due(root.snoozed, Date.now());
            if (split.ready.length === 0)
                return;
            root.snoozed = split.waiting;
            for (const item of split.ready)
                if (item.entry)
                    root.wake(item.entry);
        }
    }

    function showPopups(shown: var): void {
        root.popups = shown.slice(0, root.maxPopups);
        for (const old of shown.slice(root.maxPopups))
            root.expire(old);
    }

    function expire(entry: var): void {
        root.beginLeave(entry, false);
    }

    function drop(entry: var): void {
        const popup = root.popups.indexOf(entry);
        root.leaving = root.leaving.filter(e => e !== entry);
        root.popups = root.popups.filter(e => e !== entry);

        if (entry.forget && !entry.answered) {
            root.shelve([root.shelfRecord(entry, popup)]);
            return;
        }

        if (!entry.forget && root.history.includes(entry)) {
            entry.answered = false;
            entry.leaving = false;
            entry.leaveElapsed = 0;
            return;
        }

        root.finish(entry);
    }

    function finish(entry: var): void {
        root.history = root.history.filter(e => e !== entry);
        root.snoozed = root.snoozed.filter(item => item.entry !== entry);
        entry.notification?.dismiss();

        root.erase(entry.cached);

        if (root.hushed?.entry === entry && root.hushed.kind === "snooze")
            root.hushed = null;

        entry.destroy();
    }

    function clear(): void {
        const all = [...new Set([...root.history, ...root.popups, ...root.leaving])];
        const shown = e => e.leaving && !e.forget ? -1 : root.popups.indexOf(e);
        const records = all.map(e => root.shelfRecord(e, shown(e))).sort((a, b) => b.popup - a.popup);
        root.leaving = [];
        root.shelve(records);
    }

    readonly property int undoMs: 5000

    property var shelf: []
    property int shelfElapsed: 0
    property var shelfHeldBy: []

    readonly property int shelved: root.shelf.length
    readonly property bool undoable: root.shelf.length > 0 || root.hushed !== null

    function holdShelf(who: var): void {
        if (!root.shelfHeldBy.includes(who))
            root.shelfHeldBy = [...root.shelfHeldBy.filter(w => w), who];
    }

    function releaseShelf(who: var): void {
        root.shelfHeldBy = root.shelfHeldBy.filter(w => w && w !== who);
    }

    function shelfRecord(entry: var, popup: int): var {
        return {
            entry: entry,
            listed: root.history.includes(entry),
            popup: popup,
            snooze: root.snoozed.find(item => item.entry === entry) ?? null
        };
    }

    function shelve(records: var): void {
        root.hushed = null;
        const entries = records.map(r => r.entry);
        root.history = root.history.filter(e => !entries.includes(e));
        root.popups = root.popups.filter(e => !entries.includes(e));
        root.snoozed = root.snoozed.filter(item => !entries.includes(item.entry));
        for (const entry of entries) {
            entry.leaving = false;
            entry.leaveElapsed = 0;
        }
        root.shelf = Shelf.shelve(root.shelf, records);
        root.shelfElapsed = 0;
    }

    function unshelve(records: var): void {
        const entries = records.map(r => r.entry);
        root.shelf = root.shelf.filter(r => !entries.includes(r.entry));
        for (const entry of entries)
            entry.forget = false;
        const homes = Shelf.homes(records.map(r => Object.assign({}, r, {
                live: r.entry.live
            })));
        for (const entry of homes.gone)
            root.finish(entry);
        root.history = root.trimmed(Shelf.restored(root.history, homes.history));
        root.showPopups(Shelf.placed(root.popups, homes.popups.filter(p => homes.history.includes(p.entry) ? root.history.includes(p.entry) : true)));
        const snoozes = records.map(r => r.snooze).filter(s => s && root.history.includes(s.entry));
        if (snoozes.length > 0)
            root.snoozed = [...root.snoozed, ...snoozes];
    }

    function undo(): bool {
        const record = root.hushed;
        if (record) {
            root.hushed = null;
            root.shelfElapsed = 0;
            root.unhush(record);
            return true;
        }
        const records = root.shelf;
        if (records.length === 0)
            return false;
        root.shelfElapsed = 0;
        root.unshelve(records);
        return true;
    }

    function updatedOnShelf(entry: var): void {
        const record = root.shelf.find(r => r.entry === entry);
        if (!record || !entry.live)
            return;
        const shown = !root.holdingAt(Date.now()) && root.ruleFor(entry).pop;
        root.unshelve([Object.assign({}, record, {
                popup: shown ? 0 : -1
            })]);
    }

    function letGo(): void {
        const records = root.shelf;
        root.hushed = null;
        root.shelf = [];
        root.shelfElapsed = 0;
        for (const r of records)
            root.finish(r.entry);
    }

    Timer {
        interval: 100
        repeat: true
        running: root.undoable && root.shelfHeldBy.length === 0

        onTriggered: {
            root.shelfElapsed += interval;
            if (root.shelfElapsed >= root.undoMs)
                root.letGo();
        }
    }

    property var leaving: []

    readonly property bool persistent: !Quickshell.env("BANDITSHELL_PREVIEW")
    readonly property string path: `${Config.stateDir}/notifications.json`
    readonly property string pictures: `${Config.stateDir}/notification-pictures`
    readonly property int pictureLimit: 40

    property bool restored: false
    property int serial: 0
    property string lastWritten: ""

    Process {
        id: prepare

        command: ["sh", "-c", 'umask 077; mkdir -p -- "$1" && chmod 700 -- "$3" "$1"; rm -rf -- "$2"', "sh", root.pictures, `${Config.cacheDir}/notifications`, Config.stateDir]
        running: root.persistent
    }

    Process {
        id: prune

        function run(): void {
            const names = Store.pictureNames(Store.serialise(root.history, root.pictureLimit));
            prune.command = ["sh", "-c", 'cd -- "$1" 2>/dev/null || exit 0; shift; for f in *.png; do [ -e "$f" ] || continue; for k in "$@"; do [ "$f" = "$k" ] && continue 2; done; [ -n "$(find "$f" -mmin +1 2>/dev/null)" ] && rm -f -- "$f"; done; exit 0', "sh", root.pictures, ...names];
            prune.running = true;
        }
    }

    function newId(time: double): string {
        root.serial += 1;
        return `${Math.round(time)}-${root.serial}`;
    }

    function adopt(entry: var): void {
        entry.orphaned.connect(path => root.erase(path));
        entry.pinnedChanged.connect(root.save);
        entry.updated.connect(() => root.updatedOnShelf(entry));
    }

    function revive(record: var): var {
        const entry = entryComponent.createObject(root, {
            id: record.id,
            time: record.time,
            appName: record.appName,
            summary: record.summary,
            body: record.body,
            appIcon: record.appIcon,
            desktopEntry: record.desktopEntry,
            category: record.category,
            urgency: record.urgency,
            progress: record.progress,
            image: record.image,
            cached: record.cached,
            pinned: record.pinned,
            seen: record.seen,
            withheld: record.withheld,
            durable: true,
            live: false,
            timeout: 0,
            cacheDir: root.pictures
        });
        root.adopt(entry);
        return entry;
    }

    function restore(raw: string): void {
        if (root.restored)
            return;
        const records = Store.restore(raw, root.maxHistory, root.history.map(e => e.id), root.pictures);
        const revived = records.map(r => root.revive(r));
        root.restored = true;
        if (revived.length > 0)
            root.history = root.trimmed([...root.history, ...revived].sort((a, b) => b.time - a.time));
        prune.run();
    }

    function trimmed(list: var): var {
        const evicted = Store.trim(Search.threads(list), root.maxHistory);
        for (const old of evicted) {
            root.popups = root.popups.filter(e => e !== old);
            root.leaving = root.leaving.filter(e => e !== old);
            old.notification?.dismiss();
            root.erase(old.cached);
            old.destroy();
        }
        return evicted.length > 0 ? list.filter(e => !evicted.includes(e)) : list;
    }

    function save(): void {
        if (root.persistent && root.restored && !saveDelay.running)
            saveDelay.start();
    }

    function write(): void {
        saveDelay.stop();
        if (!root.persistent || !root.restored)
            return;
        const text = JSON.stringify(Store.serialise(root.history, root.pictureLimit));
        if (text === root.lastWritten)
            return;
        root.lastWritten = text;
        store.setText(text);
    }

    onHistoryChanged: root.save()

    Timer {
        id: saveDelay

        interval: 2000
        onTriggered: root.write()
    }

    FileView {
        id: store

        path: root.persistent ? root.path : ""
        printErrors: false

        onLoaded: root.restore(text())

        onLoadFailed: err => {
            if (err !== FileViewError.FileNotFound)
                console.warn(`Notifications: could not read ${root.path} (${err}); starting with an empty history.`);
            root.restore("");
        }

        onSaveFailed: err => {
            root.lastWritten = "";
            console.warn(`Notifications: could not write ${root.path} (${err}).`);
        }
    }

    Component.onDestruction: {
        for (const r of root.shelf)
            r.entry.notification?.dismiss();
        if (!saveDelay.running)
            return;
        store.blockWrites = true;
        root.write();
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
        inlineReplySupported: true

        onNotification: notification => {

            notification.tracked = true;

            const arrived = Date.now();

            const entry = entryComponent.createObject(root, {
                notification: notification,
                id: root.newId(arrived),
                time: arrived,
                timeout: root.timeoutFor(notification),
                durable: true,

                cacheDir: root.pictures
            });

            root.adopt(entry);

            entry.liveChanged.connect(() => {
                if (!entry.live && root.popups.includes(entry))
                    root.expire(entry);
            });

            root.history = root.trimmed([entry, ...root.history]);

            if (notification.transient)
                root.history = root.history.filter(e => e !== entry);

            const kind = root.kindOf(entry);
            const ours = (entry?.appName ?? "") === "banditshell";
            const critical = entry.urgency === NotificationUrgency.Critical;
            const held = root.holdingAt(Date.now()) && !(ours && kind === "battery") && !(kind === "alarm" && root.letAlarms) && !(critical && root.criticalThrough);
            const rule = root.ruleFor(entry);
            const silenced = Timing.muted(rule, arrived);

            entry.withheld = held;

            if (!held && rule.pop && !silenced)
                root.showPopups([entry, ...root.popups]);

            if (!held && rule.snd && !silenced)
                AlertSounds.play(AlertSounds.kinds.includes(kind) ? kind : "notification");
        }
    }

}
