import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.config
import "../components/markup.js" as Markup
import "notification-store.js" as Store

QtObject {
    id: root

    property var notification: null
    property string id: ""
    property double time: 0

    property bool durable: false
    property bool seen: false

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

    property string category: ""

    property string cacheDir: ""

    property bool live: false

    readonly property bool borrowed: root.borrows(root.image)

    function borrows(url: string): bool {
        return Store.isBorrowed(url) || Store.isTemporary(url);
    }

    readonly property string copyPath: root.copyPathFor(root.image)

    function copyPathFor(url: string): string {
        if (!root.cacheDir || !root.borrows(url))
            return "";
        return `${root.cacheDir}/${root.id || Math.round(root.time)}-${url.replace(/[^a-zA-Z0-9]+/g, "-").slice(0, 80)}.png`;
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

    readonly property string appId: AppNotifications.appIdFor(root)

    readonly property string appKey: root.appId || root.desktopEntry || root.appName

    readonly property string markSpec: root.markSpecFor()

    function markSpecFor(): string {
        const file = root.appIcon.startsWith("/") || root.appIcon.startsWith("file:");
        const chosen = file || !root.appKey ? "" : AppIcons.markFor(root.appKey, Config.values.sidebar.workspaces.iconMode);
        if (chosen)
            return chosen;
        return root.mark ? `image:${root.mark}` : "";
    }

    readonly property bool canReply: root.live && (root.notification?.hasInlineReply ?? false)

    readonly property string replyPlaceholder: root.notification?.inlineReplyPlaceholder || "Reply"

    function reply(text: string): bool {
        const said = text.trim();
        if (!root.canReply || !said)
            return false;
        root.notification.sendInlineReply(said);
        return true;
    }

    readonly property string brief: NotificationBrief.briefFor(root)

    property bool unfolded: false

    function snapshot(): void {
        const n = root.notification;
        if (!n)
            return;
        root.appName = n.appName;
        root.summary = n.summary;
        root.body = Markup.sanitise(n.body);
        root.appIcon = n.appIcon;
        root.desktopEntry = n.desktopEntry;
        root.category = String(n.hints?.category ?? "");

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
