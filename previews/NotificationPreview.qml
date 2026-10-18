import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.config
import qs.components
import qs.services
import qs.modules.island
import qs.modules.notifications

ShellRoot {
    id: preview

    readonly property string picture: "/usr/share/pixmaps/archlinux-logo.png"

    readonly property var steps: [
        {
            name: "arrive: three popups, the corner shows them and nothing else",
            run: () => preview.seed(3),
            expect: () => Notifications.popups.length === 3 && Notifications.unread === 3 && corner.items.length === 3
        },
        {
            name: "dismiss the middle popup",
            run: () => Notifications.dismiss(Notifications.popups[1]),
            expect: () => Notifications.popups.length === 2
        },
        {
            name: "pin the first, then dismiss it: it stays in history",
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
            name: "notifications in the launcher: one row per thread, who, count and age",
            run: () => preview.ask("notifications"),
            expect: () => preview.rows.length === 3 && preview.rows.some(r => r.kind === "thread" && r.detail.startsWith("Signal \u00b7 4"))
        },
        {
            name: "unread keeps what has not been seen",
            run: () => preview.ask("notifications unread"),
            expect: () => preview.rows.length > 0 && preview.rows.every(r => !r.entry.seen)
        },
        {
            name: "from signal keeps one app",
            run: () => preview.ask("notifications from signal"),
            expect: () => preview.rows.length === 1 && preview.rows[0].entry.appName === "Signal"
        },
        {
            name: "free text lists messages, not threads",
            run: () => preview.ask("notifications film eight"),
            expect: () => preview.rows.length === 1 && preview.rows[0].kind === "notification" && preview.rows[0].entry.body === "the film starts at eight"
        },
        {
            name: "a plain word never shows message text",
            run: () => preview.ask("ida"),
            expect: () => preview.rows.length === 0
        },
        {
            name: "the thread row offers show all, open, copy, snooze, mute and dismiss",
            run: () => preview.ask("notifications from signal"),
            expect: () => {
                const labels = preview.source.actionsFor(preview.rows[0]).map(a => a.label);
                return labels[0] === "Show all 4" && labels.includes("Open Signal") && labels.includes("Copy text") && labels.includes("Snooze") && labels.includes("Mute Signal") && labels.includes("Dismiss 4");
            }
        },
        {
            name: "the row's card sits beside the launcher",
            run: () => preview.peek(preview.rows[0]),
            expect: () => !!preview.rows[0].peekCard && peekCard.item !== null && peekCard.item.density === "page" && peekCard.item.entry === preview.rows[0].entry
        },
        {
            name: "enter on a thread drills in",
            run: () => preview.source.activate(preview.rows[0]),
            expect: () => preview.retyped.startsWith("notifications from signal ida")
        },
        {
            name: "snooze puts a popup away and it comes back later",
            run: () => {
                preview.arrive(preview.make({ appName: "Mail", summary: "Standup moved", body: "Ten minutes later." }, 5), true);
                preview.snoozed = Notifications.history[0];
                Notifications.snooze(preview.snoozed, 60000);
            },
            expect: () => Notifications.snoozed.length === 1 && Notifications.snoozed[0].entry === preview.snoozed && !Notifications.popups.includes(preview.snoozed)
        },
        {
            name: "wake the snoozed one: it pops again",
            run: () => Notifications.wake(preview.snoozed),
            expect: () => Notifications.popups.includes(preview.snoozed)
        },
        {
            name: "an entry held back while quiet is found by held",
            run: () => {
                Notifications.history[0].withheld = true;
                preview.ask("notifications held");
            },
            expect: () => preview.rows.length === 1 && preview.rows[0].detail.endsWith("held")
        },
        {
            name: "a progress notification arrives",
            run: () => preview.seedProgress(),
            expect: () => Notifications.history[0].progress === 63 && Notifications.unread > 0
        },
        {
            name: "a critical notification arrives",
            run: () => preview.seedCritical(),
            expect: () => Notifications.history[0].urgency === NotificationUrgency.Critical && Notifications.front() === Notifications.history[0]
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
            name: "the row for it offers a reply that asks a question",
            run: () => preview.ask("notifications from signal mia"),
            expect: () => {
                const row = preview.rows[0];
                const reply = preview.source.actionsFor(row).find(a => a.label === "Reply");
                if (!reply)
                    return false;
                reply.run();
                return preview.inquired !== null && preview.inquired.ask.prompt === "Reply to Mia";
            }
        },
        {
            name: "send the reply: the sender gets it and the card goes",
            run: () => {
                preview.inquired.ask.take("on my way");
                preview.sent = preview.mock.replies.slice();
            },
            expect: () => preview.sent.length === 1 && preview.sent[0] === "on my way"
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
            name: "forget everything: the history is empty and the corner draws nothing",
            run: () => {
                for (const e of [...Notifications.history])
                    Notifications.forget(e);
            },
            expect: () => Notifications.history.length === 0 && corner.items.length === 0
        }
    ]

    property int step: 0
    property int failures: 0
    property int made: 0
    property var mock: null
    property var sent: []
    property var snoozed: null
    property var inquired: null
    property string retyped: ""
    property string typed: ""
    property var peeked: null

    readonly property var source: sourceLoader.item
    readonly property var rows: source?.groups[0].items ?? []

    function ask(text: string): void {
        preview.typed = text;
    }

    function peek(row: var): void {
        preview.peeked = row;
    }

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
        console.log(`${ok ? "PASS" : "FAIL"} ${label} | popups=${Notifications.popups.length} history=${Notifications.history.length} unread=${Notifications.unread} threads=${Notifications.threadsOf(Notifications.history).length} pinned=${Notifications.history.filter(e => e.pinned).length} snoozed=${Notifications.snoozed.length} | query="${preview.typed}" rows=${preview.rows.length} cornerItems=${corner.items.length} cornerHeight=${Math.round(corner.maskItem.height)} | top=${top ? `${top.appName}:${top.summary}` : "-"} age="${top ? Notifications.ageOf(top.time) : ""}" unfolded=${top?.unfolded ?? "-"} brief="${top?.brief ?? ""}"`);
    }

    QtObject {
        id: stub

        readonly property string text: preview.typed
        readonly property string screenName: ""
        readonly property bool onStage: true

        function launch(what: var): void {
            what();
        }

        function leave(what: var): void {
            what();
        }

        function retype(text: string): void {
            preview.retyped = text;
        }

        function inquire(row: var): void {
            preview.inquired = row;
        }

        function copyText(text: string): void {
        }
    }

    Loader {
        id: sourceLoader

        Component.onCompleted: sourceLoader.setSource("../modules/launcher/sources/NotificationSource.qml", {
            search: stub
        })
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
        implicitWidth: 960
        implicitHeight: 700
        color: Appearance.colour.surfaceSolid

        Column {
            x: 20
            y: 20
            width: 440
            spacing: 8

            Repeater {
                model: preview.rows

                delegate: StyledText {
                    required property var modelData

                    width: parent.width
                    text: `${modelData.label}   ${modelData.detail}`
                    elide: Text.ElideRight
                }
            }

            Loader {
                id: peekCard

                sourceComponent: preview.peeked?.peekCard ?? null
            }

            Binding {
                target: peekCard.item
                property: "entry"
                value: preview.peeked?.entry ?? null
                when: peekCard.item !== null
            }
        }

        NotificationCorner {
            id: corner

            anchors.fill: parent
            inset: 20
            onStage: true
            wanted: true
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
                let ok = false;
                try {
                    ok = !!s.expect();
                } catch (err) {
                    console.log(`ERROR ${preview.step}. ${s.name}: ${err}`);
                }
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
