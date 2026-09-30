import QtQuick
import Quickshell
import qs.services
import qs.modules.notifications

ShellRoot {
    id: preview

    readonly property var steps: [
        {
            name: "arrive: three popups, tray collapsed",
            run: () => preview.seed(3)
        },
        {
            name: "hover a card: must NOT expand",
            run: () => {}
        },
        {
            name: "dismiss the middle popup",
            run: () => Notifications.dismiss(Notifications.popups[1])
        },
        {
            name: "pin the first, then dismiss it",
            run: () => {
                Notifications.popups[0].pinned = true;
                Notifications.dismiss(Notifications.popups[0]);
            }
        },
        {
            name: "expand the tray",
            run: () => tray.pinned = true
        },

        {
            name: "a qBittorrent release name arrives",
            run: () => preview.seedQbit()
        },
        {
            name: "unfold it: all of it, brackets and all",
            run: () => Notifications.history[0].unfolded = true
        },
        {
            name: "fold it back",
            run: () => Notifications.history[0].unfolded = false
        },
        {
            name: "forget everything left in the hub",
            run: () => {
                for (const e of [...Notifications.history])
                    Notifications.forget(e);
            }
        },
        {
            name: "collapse the empty tray",
            run: () => tray.pinned = false
        }
    ]

    property int step: 0

    function seed(n: int): void {
        const made = [];
        for (let i = 0; i < n; i++)
            made.push(entryComponent.createObject(preview, {
                appName: `App ${i}`,
                summary: `Summary ${i}`,
                body: `The body of notification ${i}.`,

                timeout: 0,
                live: true
            }));
        Notifications.popups = made;
        Notifications.history = made;
    }

    function seedQbit(): void {
        const entry = entryComponent.createObject(preview, {
            appName: "qBittorrent",
            desktopEntry: "org.qbittorrent.qBittorrent",
            summary: "Download completed",
            body: "'[Erai-raws] Yomi no Tsugai - 20 [1080p CR WEB-DL AVC AAC][MultiSub].mkv' has finished downloading.",
            timeout: 0,
            live: true
        });
        Notifications.history = [entry, ...Notifications.history];
    }

    function report(label: string): void {
        const t = tray.maskItem;
        const top = Notifications.history[0];
        console.log(`${label} | popups=${Notifications.popups.length} history=${Notifications.history.length} pinned=${Notifications.history.filter(e => e.pinned).length} | expanded=${tray.expanded} rows=${tray.items.length} trayVisible=${t.visible} trayHeight=${Math.round(t.height)} | unfolded=${top?.unfolded ?? "-"} brief="${top?.brief ?? ""}"`);
    }

    Component {
        id: entryComponent

        NotificationEntry {}
    }

    FloatingWindow {
        implicitWidth: 520
        implicitHeight: 700
        color: "#16211c"

        NotificationTray {
            id: tray

            anchors.fill: parent
            inset: 20
            edgeInset: 10
        }
    }

    Timer {
        interval: 700
        repeat: true
        running: true

        onTriggered: {
            if (preview.step >= preview.steps.length) {
                preview.report("settled");
                Qt.exit(0);
                return;
            }
            const s = preview.steps[preview.step++];
            s.run();
            Qt.callLater(() => preview.report(`${preview.step}. ${s.name}`));
        }
    }
}
