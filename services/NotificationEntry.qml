import QtQuick
import Quickshell
import Quickshell.Services.Notifications

QtObject {
    id: root

    property var notification: null
    property double time: 0

    property string appName: ""
    property string summary: ""
    property string body: ""
    property string appIcon: ""
    property string image: ""
    property int urgency: NotificationUrgency.Normal
    property bool hasActions: false

    function pressable(actions: var): var {
        return (actions ?? []).filter(a => a.identifier !== "default" && a.text);
    }

    property real progress: -1

    property string desktopEntry: ""

    property string cacheDir: ""

    property bool live: false

    readonly property bool borrowed: root.borrows(root.image)

    function borrows(url: string): bool {
        return url.startsWith("image://") && !url.startsWith("image://icon/");
    }

    readonly property string copyPath: root.copyPathFor(root.image)

    function copyPathFor(url: string): string {
        if (!root.cacheDir || !root.borrows(url))
            return "";
        return `${root.cacheDir}/${url.replace(/[^a-zA-Z0-9]+/g, "-")}.png`;
    }

    property string cached: ""

    property bool copying: false

    signal orphaned(path: string)

    readonly property bool wantsCopy: root.live && root.copyPath !== "" && root.cached !== root.copyPath && !root.copying

    function keep(path: string): void {
        if (path !== root.copyPath)
            return root.orphaned(path);

        if (path === root.cached)
            return;

        root.retire();
        root.cached = path;
    }

    function retire(): void {
        if (!root.cached)
            return;
        root.orphaned(root.cached);
        root.cached = "";
    }

    readonly property string picture: (root.live || !root.cached) ? root.image : root.cached

    readonly property string mark: root.markFor()

    function markFor(): string {
        if (root.appIcon.startsWith("/") || root.appIcon.startsWith("file:"))
            return root.appIcon;

        const themed = root.appIcon ? Quickshell.iconPath(root.appIcon, true) : "";
        if (themed)
            return themed;

        const names = [root.desktopEntry, root.appName].filter(n => n);

        for (const name of names) {
            const picked = AppIcons.specFor(name);
            if (AppIcons.isFile(picked))
                return picked.slice(picked.indexOf(":") + 1);
        }

        return Apps.iconSourceFor(names);
    }

    readonly property string brief: NotificationBrief.briefFor(root)

    property bool unfolded: false

    function snapshot(): void {
        const n = root.notification;
        if (!n)
            return;
        root.appName = n.appName;
        root.summary = n.summary;
        root.body = n.body;
        root.appIcon = n.appIcon;
        root.desktopEntry = n.desktopEntry;

        if (n.image !== root.image) {
            root.retire();
            root.image = n.image;
            root.copying = false;
        }

        root.urgency = n.urgency;
        root.hasActions = root.pressable(n.actions).length > 0;

        const v = n.hints?.value;
        root.progress = typeof v === "number" && isFinite(v) ? Math.max(0, Math.min(100, v)) : -1;

        root.live = true;
    }

    onNotificationChanged: root.snapshot()
    Component.onCompleted: root.snapshot()

    readonly property Connections follow: Connections {
        target: root.notification

        function onAppNameChanged(): void {
            root.snapshot();
        }
        function onSummaryChanged(): void {
            root.snapshot();
        }
        function onBodyChanged(): void {
            root.snapshot();
        }
        function onAppIconChanged(): void {
            root.snapshot();
        }
        function onDesktopEntryChanged(): void {
            root.snapshot();
        }
        function onImageChanged(): void {
            root.snapshot();
        }
        function onUrgencyChanged(): void {
            root.snapshot();
        }
        function onActionsChanged(): void {
            root.snapshot();
        }

        function onHintsChanged(): void {
            root.snapshot();
        }

        function onClosed(): void {
            root.live = false;
        }
    }

    property int timeout: 0

    property real remaining: timeout > 0 ? 1 : 0

    property var heldBy: []

    readonly property bool held: root.heldBy.length > 0

    function hold(card: var): void {
        if (root.heldBy.includes(card))
            return;
        root.heldBy = [...root.heldBy.filter(c => c), card];
    }

    function release(card: var): void {
        root.heldBy = root.heldBy.filter(c => c && c !== card);
    }

    property bool pinned: false

    property bool leaving: false
    property int leaveElapsed: 0

    property bool forget: false

    readonly property bool running: timeout > 0 && remaining > 0 && !held && !pinned && !leaving

    function tick(ms: int): bool {
        if (!root.running)
            return false;
        root.remaining = Math.max(0, root.remaining - ms / root.timeout);
        return root.remaining <= 0;
    }
}
