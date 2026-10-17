pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "events.js" as Logic

Singleton {
    id: root

    readonly property bool ready: Config.loaded && Modes.loaded && Notifications.restored

    readonly property var snapshot: Logic.snapshotOf({
        workspace: Hypr.activeId,
        windows: Shell.windows,
        extraPanels: Files.windowOpen ? ["files"] : [],
        mode: Modes.current,
        quiet: Notifications.quieted,
        media: {
            title: Media.hasTrack ? Media.title : "",
            artist: Media.artist,
            app: Media.app,
            playing: Media.playing
        },
        activities: Activities.entries,
        notifications: Notifications.history,
        update: { state: Update.state, behind: Update.behind }
    })

    property var previous: null
    property var queue: []

    function observe(): void {
        if (!root.ready) {
            root.previous = null;
            return;
        }
        const events = Logic.diff(root.previous, root.snapshot, { notificationText: Config.values.events.notificationText });
        root.previous = root.snapshot;
        if (events.length === 0)
            return;
        const now = Date.now();
        root.queue = [...root.queue, ...events.map(e => Logic.line(e, now))].slice(-500);
        root.flush();
    }

    function flush(): void {
        if (!writer.running || root.queue.length === 0)
            return;
        writer.write(root.queue.join(""));
        root.queue = [];
    }

    function ensureWriter(): void {
        if (root.ready && !writer.running)
            writer.running = true;
    }

    onSnapshotChanged: root.observe()

    onReadyChanged: {
        root.observe();
        root.ensureWriter();
    }

    Process {
        id: writer

        command: ["sh", "-c", Logic.WRITER_SCRIPT, "sh", String(Logic.SIZE_CAP)]
        stdinEnabled: true

        onRunningChanged: if (writer.running)
            root.flush()

        onExited: revive.restart()
    }

    Timer {
        id: revive

        interval: 3000
        onTriggered: root.ensureWriter()
    }
}
