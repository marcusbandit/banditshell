import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.services
import qs.modules.island

ShellRoot {
    id: preview

    readonly property string shots: Quickshell.env("BANDITSHELL_SHOTS") ?? ""

    readonly property var steps: [
        {
            name: "dictating",
            run: () => preview.speak("listening"),
            expect: "dictation"
        },
        {
            name: "the pointer comes up to it: dictation alone tucks into the band",
            run: () => island.near = true,
            expect: "dictation, tucked away from the pointer"
        },
        {
            name: "the pointer leaves: it drips back out",
            run: () => island.near = false,
            expect: "dictation"
        },
        {
            name: "pin the island while dictating: the bars travel",
            run: () => island.pinned = true,
            wait: 140,
            expect: "overview"
        },
        {
            name: "overview, the bars fill the row",
            run: () => {},
            expect: "overview"
        },
        {
            name: "unpin: the bars travel back",
            run: () => island.pinned = false,
            wait: 140,
            expect: "dictation"
        },
        {
            name: "a notification while dictating takes the island, dictation buds off",
            run: () => preview.notify("Discord", "marcus", "are you coming tonight?", false),
            wait: 200,
            expect: "one notification, beside it: dictation"
        },
        {
            name: "the notification settles beside the dictation bubble",
            run: () => {},
            expect: "one notification, beside it: dictation"
        },
        {
            name: "dictation ends: its bubble goes",
            run: () => preview.speak("idle"),
            expect: "one notification"
        },
        {
            name: "two more arrive: a stack",
            run: () => {
                preview.notify("Firefox", "Download finished", "linux-zen-6.17.tar.zst", false);
                preview.notify("Discord", "marcus", "bring the switch", false);
            },
            expect: "3 notifications stacked"
        },
        {
            name: "hovering the stack spreads it",
            run: () => island.fanning = true,
            wait: 150,
            expect: "3 notifications spread out"
        },
        {
            name: "pinning while notifications are up: they travel into the overview",
            run: () => {
                island.fanning = false;
                island.pinned = true;
            },
            wait: 120,
            expect: "overview, notifications arriving inside it"
        },
        {
            name: "the overview holds them under the clock",
            run: () => {},
            expect: "overview, notifications arriving inside it"
        },
        {
            name: "dictation starts inside the overview",
            run: () => preview.speak("listening"),
            expect: "overview, notifications arriving inside it"
        },
        {
            name: "unpin: dictation started while the notifications showed, so it waits beside them",
            run: () => island.pinned = false,
            expect: "3 notifications stacked, beside it: dictation"
        },
        {
            name: "dictation ends: the stack comes back",
            run: () => preview.speak("idle"),
            expect: "3 notifications stacked"
        },
        {
            name: "dictation again while they show: it appears below the card first",
            run: () => preview.speak("listening"),
            expect: "3 notifications stacked, below it: dictation"
        },
        {
            name: "then it glides into a bubble beside the card",
            run: () => {},
            wait: 2600,
            expect: "3 notifications stacked, beside it: dictation"
        },
        {
            name: "a critical notification takes the island",
            run: () => preview.notify("BanditShell", "Battery at 4%", "Plug in now.", true),
            expect: "4 notifications stacked, beside it: dictation"
        },
        {
            name: "flick the front one away: the next one rises into place",
            run: () => island.flickFront(1),
            expect: "3 notifications stacked, beside it: dictation"
        },
        {
            name: "flick the next one too: the one behind rises into its place",
            run: () => island.flickFront(1),
            expect: "2 notifications stacked, beside it: dictation"
        },
        {
            name: "clear all: the stack flies off at once",
            run: () => island.clearNotifications(null),
            expect: "dictation"
        },
        {
            name: "dismiss everything, dictation alone again",
            run: () => {
                for (const e of [...Notifications.popups])
                    Notifications.dismiss(e);
            },
            expect: "dictation"
        },
        {
            name: "tucked away from the pointer",
            run: () => island.near = true,
            expect: "dictation, tucked away from the pointer"
        },
        {
            name: "a notification while it is tucked: the island comes back for it",
            run: () => preview.notify("Signal", "Mum", "call me when you get a minute", false),
            wait: 200,
            expect: "one notification, beside it: dictation"
        },
        {
            name: "the notification goes and the pointer is still there: tucked again",
            run: () => {
                for (const e of [...Notifications.popups])
                    Notifications.dismiss(e);
            },
            expect: "dictation, tucked away from the pointer"
        },
        {
            name: "the pointer leaves",
            run: () => island.near = false,
            expect: "dictation"
        },
        {
            name: "processing",
            run: () => preview.speak("processing"),
            expect: "dictation"
        },
        {
            name: "an app opens",
            run: () => {
                preview.speak("idle");
                preview.launch("firefox", "Firefox", "waiting");
            },
            expect: "launch"
        },
        {
            name: "a second app opens: two lines",
            run: () => preview.launch("spotify", "Spotify", "waiting"),
            expect: "2 launches"
        },
        {
            name: "dictation starts while they open: it appears below them first",
            run: () => preview.speak("listening"),
            expect: "2 launches, below it: dictation"
        },
        {
            name: "then it takes the big spot and the apps glide into a stacked bubble",
            run: () => {},
            wait: 2600,
            expect: "dictation, beside it: 2 launches"
        },
        {
            name: "a notification on top of it all",
            run: () => preview.notify("Discord", "marcus", "on my way", false),
            expect: "one notification, beside it: dictation, 2 launches"
        },
        {
            name: "the music changes: it has its moment below the card",
            run: () => Notices.pass({
                    key: "music",
                    kind: "music"
                }),
            expect: "one notification, below it: music, beside it: dictation, 2 launches"
        },
        {
            name: "ninety more pile up: one card in front, the rest behind it",
            run: () => {
                for (let i = 0; i < 90; i++)
                    preview.notify(["Discord", "Firefox", "Steam"][i % 3], `message ${i + 1}`, "the same old story", false);
            },
            wait: 6000,
            expect: "91 notifications stacked, beside it: dictation, 2 launches"
        },
        {
            name: "spread, ninety stop at about half the screen and scroll",
            run: () => island.fanning = true,
            wait: 150,
            expect: "91 notifications spread out, beside it: dictation, 2 launches",
            holds: () => island.restHeight <= (island.host?.height ?? 900) * 0.62
        }
    ]

    property int step: 0
    property int made: 0
    property int failures: 0

    function speak(phase: string): void {
        Dictation.phase = phase;
        if (phase === "listening") {
            const levels = [];
            for (let i = 0; i < Dictation.levelCount; i++)
                levels.push(Math.abs(Math.sin(i * 0.37)) * (0.35 + 0.65 * Math.abs(Math.sin(i * 0.11))));
            Dictation.levels = levels;
        }
    }

    function launch(id: string, name: string, state: string): void {
        Launching.shown = [...Launching.shown, {
                id: id,
                name: name,
                mark: `symbol:public`,
                marks: [id],
                at: Date.now(),
                state: state,
                done: state === "waiting" ? 0 : Date.now()
            }];
    }

    function notify(app: string, summary: string, body: string, urgent: bool): void {
        const entry = entryComponent.createObject(preview, {
            appName: app,
            summary: summary,
            body: body,
            urgency: urgent ? NotificationUrgency.Critical : NotificationUrgency.Normal,
            timeout: 0,
            live: true,
            time: Date.now() + preview.made++
        });
        Notifications.popups = [entry, ...Notifications.popups];
        Notifications.history = [entry, ...Notifications.history];
    }

    function shoot(name: string): void {
        if (!preview.shots)
            return;
        const file = `${preview.shots}/${String(preview.step).padStart(2, "0")}-${name.replace(/[^a-z0-9]+/gi, "-").toLowerCase().slice(0, 48)}.png`;
        island.stage.grabToImage(r => r.saveToFile(file));
    }

    Component {
        id: entryComponent

        NotificationEntry {}
    }

    FloatingWindow {
        implicitWidth: 200
        implicitHeight: 100
        color: "#16211c"

        Island {
            id: island

            anchors.fill: parent
            border: 12
        }
    }

    Timer {
        id: ticker

        property var pending: null

        interval: 900
        running: true

        onTriggered: {
            if (ticker.pending) {
                const s = ticker.pending;
                ticker.pending = null;
                const ok = island.situation === s.expect && (!s.holds || s.holds());
                if (!ok)
                    preview.failures++;
                console.log(`${ok ? "PASS" : "FAIL"} ${preview.step}. ${s.name} | situation="${island.situation}"${ok ? "" : ` expected="${s.expect}"`} presentation=${island.presentation} alerting=${island.alerting} alerts=${island.alerts.length}`);
                preview.shoot(s.name);
                ticker.interval = 900;
                ticker.start();
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
            ticker.interval = s.wait ?? 900;
            ticker.start();
        }
    }
}
