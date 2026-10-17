import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.services
import qs.modules.island
import qs.modules.notifications

ShellRoot {
    id: preview

    readonly property string picture: "/usr/share/pixmaps/archlinux-logo.png"

    readonly property var steps: [
        {
            name: "arrive: three popups, tray collapsed",
            run: () => preview.seed(3),
            expect: () => Notifications.popups.length === 3 && Notifications.unread === 3 && !tray.expanded
        },
        {
            name: "hover a card: must NOT expand",
            run: () => {},
            expect: () => !tray.expanded
        },
        {
            name: "dismiss the middle popup",
            run: () => Notifications.dismiss(Notifications.popups[1]),
            expect: () => Notifications.popups.length === 2
        },
        {
            name: "pin the first, then dismiss it: it stays",
            run: () => {
                Notifications.popups[0].pinned = true;
                Notifications.dismiss(Notifications.popups[0]);
            },
            expect: () => Notifications.history.length === 2
        },
        {
            name: "a chat thread of four messages arrives with ages",
            run: () => preview.seedChat(),
            expect: () => Notifications.threadsOf(Notifications.history).some(t => t.entries.length === 4) && Notifications.ageOf(Date.now() - 125000) === "2m"
        },
        {
            name: "expand the tray: the thread is one card with a count, everything is seen",
            run: () => tray.pinned = true,
            expect: () => tray.expanded && Notifications.unread === 0 && tray.groups.length < Notifications.history.length
        },
        {
            name: "open the thread",
            run: () => tray.toggleThread(tray.groups.find(g => g.entries.length === 4).id),
            expect: () => tray.opened.length === 1
        },
        {
            name: "close the thread",
            run: () => tray.opened = [],
            expect: () => tray.opened.length === 0
        },
        {
            name: "a progress notification arrives",
            run: () => preview.seedProgress(),
            expect: () => Notifications.history[0].progress === 63 && Notifications.unread === 0
        },
        {
            name: "a critical notification arrives",
            run: () => preview.seedCritical(),
            expect: () => Notifications.history[0].urgency === NotificationUrgency.Critical
        },
        {
            name: "a notification with a picture and an app badge arrives",
            run: () => preview.seedPicture(),
            expect: () => Notifications.history[0].picture !== ""
        },
        {
            name: "a chat app that takes replies: the field shows",
            run: () => preview.seedReply(),
            expect: () => Notifications.history[0].canReply && Notifications.history[0].replyPlaceholder === "Message Mia"
        },
        {
            name: "send the reply: the sender gets it and the card goes",
            run: () => {
                Notifications.reply(Notifications.history[0], "on my way");
                preview.sent = preview.mock.replies.slice();
            },
            expect: () => preview.sent.length === 1 && preview.sent[0] === "on my way" && Notifications.history.length === 9
        },
        {
            name: "a restored entry is dead: no buttons, no reply",
            run: () => preview.seedDead(),
            expect: () => !Notifications.history[0].live && !Notifications.history[0].canReply
        },
        {
            name: "a qBittorrent release name arrives",
            run: () => preview.seedQbit(),
            expect: () => Notifications.history[0].brief !== ""
        },
        {
            name: "unfold it: all of it, brackets and all",
            run: () => Notifications.history[0].unfolded = true,
            expect: () => Notifications.history[0].unfolded
        },
        {
            name: "fold it back",
            run: () => Notifications.history[0].unfolded = false,
            expect: () => !Notifications.history[0].unfolded
        },
        {
            name: "forget everything left in the hub",
            run: () => {
                for (const e of [...Notifications.history])
                    Notifications.forget(e);
            },
            expect: () => Notifications.history.length === 0
        },
        {
            name: "collapse the empty tray",
            run: () => tray.pinned = false,
            expect: () => !tray.expanded
        }
    ]

    property int step: 0
    property int failures: 0
    property int made: 0
    property var mock: null
    property var sent: []

    function make(props: var, ago: int): var {
        preview.made += 1;
        return entryComponent.createObject(preview, Object.assign({
            id: `preview-${preview.made}`,
            time: Date.now() - ago * 1000,
            timeout: 0,
            live: true
        }, props));
    }

    function arrive(entry: var, popup: bool): void {
        Notifications.history = [entry, ...Notifications.history];
        if (popup)
            Notifications.popups = [entry, ...Notifications.popups];
        Notifications.now = Date.now();
    }

    function seed(n: int): void {
        const made = [];
        for (let i = 0; i < n; i++)
            made.push(preview.make({
                appName: `App ${i}`,
                summary: `Summary ${i}`,
                body: `The body of notification ${i}.`
            }, 5 + i * 60));
        Notifications.popups = made;
        Notifications.history = made;
        Notifications.now = Date.now();
    }

    function seedChat(): void {
        const lines = ["are you coming tonight?", "I saved you a seat", "the film starts at eight", "bring the tickets"];
        for (let i = 0; i < lines.length; i++)
            preview.arrive(preview.make({
                appName: "Signal",
                desktopEntry: "signal-desktop",
                summary: "Ida",
                body: lines[i]
            }, 125 - i * 20), false);
    }

    function seedProgress(): void {
        preview.arrive(preview.make({
            appName: "Files",
            summary: "Copying 12 items",
            body: "to Backups",
            progress: 63
        }, 30), true);
    }

    function seedCritical(): void {
        preview.arrive(preview.make({
            appName: "Battery",
            summary: "Battery critically low",
            body: "Plug in the charger now.",
            urgency: NotificationUrgency.Critical
        }, 90), true);
    }

    function seedPicture(): void {
        preview.arrive(preview.make({
            appName: "Telegram",
            desktopEntry: "org.telegram.desktop",
            summary: "Jonas sent a photo",
            body: "Look at this",
            image: preview.picture
        }, 3700), true);
    }

    function seedReply(): void {
        preview.mock = mockComponent.createObject(preview, {
            hasInlineReply: true,
            inlineReplyPlaceholder: "Message Mia",
            appName: "Signal",
            desktopEntry: "signal-desktop",
            summary: "Mia",
            body: "where are you?"
        });
        preview.arrive(preview.make({
            notification: preview.mock
        }, 45), true);
    }

    function seedDead(): void {
        preview.arrive(preview.make({
            appName: "Mail",
            summary: "Your invoice is ready",
            body: "Restored from the last session, so it has no buttons.",
            live: false
        }, 86400 + 3600 * 3), false);
    }

    function seedQbit(): void {
        preview.arrive(preview.make({
            appName: "qBittorrent",
            desktopEntry: "org.qbittorrent.qBittorrent",
            summary: "Download completed",
            body: "'[Erai-raws] Yomi no Tsugai - 20 [1080p CR WEB-DL AVC AAC][MultiSub].mkv' has finished downloading."
        }, 10), false);
    }

    function report(label: string, ok: bool): void {
        const top = Notifications.history[0];
        const t = tray.maskItem;
        console.log(`${ok ? "PASS" : "FAIL"} ${label} | popups=${Notifications.popups.length} history=${Notifications.history.length} unread=${Notifications.unread} threads=${tray.groups.length} pinned=${Notifications.history.filter(e => e.pinned).length} | expanded=${tray.expanded} rows=${tray.items.length} trayVisible=${t.visible} trayHeight=${Math.round(t.height)} | top=${top ? `${top.appName}:${top.summary}` : "-"} age="${top ? Notifications.ageOf(top.time) : ""}" unfolded=${top?.unfolded ?? "-"} brief="${top?.brief ?? ""}"`);
    }

    Component {
        id: entryComponent

        NotificationEntry {}
    }

    Component {
        id: mockComponent

        MockNotification {}
    }

    FloatingWindow {
        implicitWidth: 520
        implicitHeight: 700
        color: Appearance.colour.surfaceSolid

        NotificationTray {
            id: tray

            anchors.fill: parent
            inset: 20
            edgeInset: 10
        }
    }

    Timer {
        id: ticker

        property var pending: null

        interval: 700
        repeat: true
        running: true

        onTriggered: {
            if (ticker.pending) {
                const s = ticker.pending;
                ticker.pending = null;
                const ok = !!s.expect();
                if (!ok)
                    preview.failures++;
                preview.report(`${preview.step}. ${s.name}`, ok);
                ticker.interval = 200;
                return;
            }
            if (preview.step >= preview.steps.length) {
                console.log(`DONE ${preview.steps.length - preview.failures}/${preview.steps.length}`);
                Qt.exit(preview.failures > 0 ? 1 : 0);
                return;
            }
            const s = preview.steps[preview.step++];
            s.run();
            ticker.pending = s;
            ticker.interval = 700;
        }
    }
}
