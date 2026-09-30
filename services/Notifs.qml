pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.config

Singleton {
    id: root

    readonly property alias server: server

    property var history: []
    property var popups: []

    readonly property int count: history.length
    readonly property bool any: count > 0

    readonly property bool anyUrgent: history.some(e => e.urgency === NotificationUrgency.Critical)

    function timeoutFor(n: var): int {
        if (n?.urgency === NotificationUrgency.Critical)
            return 0;
        return n?.expireTimeout > 0 ? n.expireTimeout : root.defaultTimeout;
    }

    readonly property int maxHistory: Config.values.notifications.maxHistory
    readonly property int defaultTimeout: Config.values.notifications.timeout
    readonly property int maxPopups: Config.values.notifications.maxPopups

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

    readonly property int exitMs: Appearance.anim.normal

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

    readonly property string cacheRoot: `${Quickshell.env("XDG_CACHE_HOME") || `${Quickshell.env("HOME")}/.cache`}/banditshell/notifications`

    readonly property string cacheName: `${Quickshell.processId}-${Date.now()}`
    readonly property string cacheDir: `${root.cacheRoot}/${root.cacheName}`

    Process {
        id: sweep

        command: ["sh", "-c", `
            mkdir -p '${root.cacheDir}' && cd '${root.cacheRoot}' || exit 0
            for n in *; do
                case "$n" in
                *.png)
                    rm -f "./$n"
                    ;;
                [0-9]*-[0-9]*)
                    [ "$n" = '${root.cacheName}' ] && continue
                    p=\${n%%-*}
                    [ "$p" != '${Quickshell.processId}' ] && [ -d "/proc/$p" ] && continue
                    rm -rf "./$n"
                    ;;
                esac
            done
        `]
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

        NotifEntry {}
    }

    Timer {
        interval: 50
        repeat: true
        running: root.popups.length > 0 || root.leaving.length > 0

        onTriggered: {
            if (!root.paused) {
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

            const shown = [entry, ...root.popups];
            root.popups = shown.slice(0, root.maxPopups);
            for (const old of shown.slice(root.maxPopups))
                root.expire(old);

        }
    }

}
