import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.services
import qs.modules.island
import "../services/activities.js" as Logic
import "../services/moments.js" as MomentLogic
import "../services/privacy.js" as PrivacyLogic

ShellRoot {
    id: preview

    readonly property string shots: Quickshell.env("BANDITSHELL_SHOTS") ?? ""

    readonly property var steps: [
        {
            name: "a timer runs: a row with a ring and the time left",
            run: () => Activities.staged = [preview.timer("tea", "Tea", 450000, 600000, false)],
            expect: "timer"
        },
        {
            name: "a second timer, paused: two lines, the paused ring holds",
            run: () => Activities.staged = [preview.timer("tea", "Tea", 450000, 600000, false), preview.timer("laundry", "Laundry", 1500000, 3000000, true)],
            expect: "2 timers"
        },
        {
            name: "dictation starts while a timer runs: it shows below first",
            run: () => {
                Activities.staged = [preview.timer("tea", "Tea", 450000, 600000, false)];
                preview.speak("listening");
            },
            expect: "timer, below it: dictation"
        },
        {
            name: "then dictation takes the big spot and the timer is a ring bubble with its time",
            run: () => {},
            wait: 2600,
            expect: "dictation, beside it: timer"
        },
        {
            name: "the timer enters its last seconds: it grows to a row in the big spot",
            run: () => Activities.staged = [preview.timer("tea", "Tea", 8000, 600000, false)],
            expect: "timer, beside it: dictation"
        },
        {
            name: "the timer is done: the alarm takes the big spot with Stop",
            run: () => Activities.staged = [Logic.alarmItem("timer:tea", "Tea is done", Logic.alarmActions(false))],
            expect: "alarm, beside it: dictation"
        },
        {
            name: "an alarm rings: Snooze and Stop in the big spot",
            run: () => Activities.staged = [Logic.alarmItem("wake", "07:30  Wake up", Logic.alarmActions(true))],
            expect: "alarm, beside it: dictation"
        },
        {
            name: "stopped, and dictation ends: nothing left",
            run: () => {
                Activities.staged = [];
                preview.speak("idle");
            },
            expect: "hidden"
        },
        {
            name: "a script pushes a build at 40 percent",
            run: () => Activities.push({
                    id: "build",
                    text: "Building",
                    detail: "compiling shaders",
                    progress: 0.4,
                    icon: "hardware"
                }),
            expect: "activity"
        },
        {
            name: "it moves on, and a second task with no progress starts",
            run: () => {
                Activities.update("build", {
                    progress: 0.8
                });
                Activities.push({
                    id: "sync",
                    text: "Syncing photos",
                    icon: "sync"
                });
            },
            expect: "2 activities"
        },
        {
            name: "the build is done and the sync failed: each shows its mark",
            run: () => {
                Activities.end("build", "done");
                Activities.end("sync", "failed");
            },
            expect: "2 activities"
        },
        {
            name: "the marks go and so do the rows",
            run: () => {},
            wait: 3600,
            expect: "hidden"
        },
        {
            name: "the volume changes: a level row for a second",
            run: () => Notices.pass(Logic.levelMoment("volume", 0.45, false, 1)),
            wait: 400,
            expect: "level"
        },
        {
            name: "the volume is muted",
            run: () => Notices.pass(Logic.levelMoment("volume", 0.45, true, 1)),
            wait: 400,
            expect: "level"
        },
        {
            name: "the brightness changes",
            run: () => Notices.pass(Logic.levelMoment("brightness", 0.7, false, 1)),
            wait: 400,
            expect: "level"
        },
        {
            name: "the microphone is muted",
            run: () => Notices.pass(Logic.levelMoment("mic", 1, true, 1)),
            wait: 400,
            expect: "level"
        },
        {
            name: "the level row is gone",
            run: () => {},
            wait: 1500,
            expect: "hidden"
        },
        {
            name: "the volume changes while dictating: the level row sits below the bars",
            run: () => {
                preview.speak("listening");
                Notices.pass(Logic.levelMoment("volume", 0.8, false, 1));
            },
            wait: 400,
            expect: "dictation, below it: level"
        },
        {
            name: "dictation ends and the level row is gone",
            run: () => preview.speak("idle"),
            wait: 1500,
            expect: "hidden"
        },
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
                Notices.settle("music");
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
        },
        {
            name: "everything is dismissed before the moments",
            run: () => {
                island.fanning = false;
                for (const e of [...Notifications.popups])
                    Notifications.dismiss(e);
                Launching.shown = [];
                for (const n of [...Notices.passing])
                    Notices.settle(n.key);
                preview.speak("idle");
            },
            wait: 1500,
            expect: "hidden"
        },
        {
            name: "a screenshot is taken: the picture with Copy, Edit, Folder and Delete",
            run: () => Activities.push(preview.shot(9000)),
            expect: "activity"
        },
        {
            name: "the microphone goes live: a privacy row shows below it first",
            run: () => Activities.push(PrivacyLogic.usageSpec({
                    kind: "mic",
                    apps: ["Firefox"]
                })),
            expect: "activity, below it: privacy"
        },
        {
            name: "then the privacy dot settles into a bubble beside the screenshot",
            run: () => {},
            wait: 2600,
            expect: "activity, beside it: privacy"
        },
        {
            name: "the screenshot leaves: the privacy row is alone",
            run: () => {},
            wait: 2600,
            expect: "privacy"
        },
        {
            name: "the camera and a screen share join: one privacy group with a count",
            run: () => {
                Activities.push(PrivacyLogic.usageSpec({
                    kind: "camera",
                    apps: ["Zoom"]
                }));
                Activities.push(PrivacyLogic.usageSpec({
                    kind: "screen",
                    apps: ["OBS Studio", "Firefox"]
                }));
            },
            expect: "privacy"
        },
        {
            name: "text is copied: a Copied row with the first twenty characters",
            run: () => Activities.push(MomentLogic.copiedSpec(["wl-copy", "-n"], "the quick brown fox jumps over the lazy dog")),
            wait: 400,
            expect: "privacy, below it: activity"
        },
        {
            name: "a secret is copied: the text is masked",
            run: () => Activities.push(MomentLogic.copiedSpec(["wl-copy", "--sensitive", "-n"], "hunter2")),
            wait: 400,
            expect: "privacy, below it: activity"
        },
        {
            name: "the copied row is gone",
            run: () => {},
            wait: 1500,
            expect: "privacy"
        },
        {
            name: "headphones connect: their name and battery",
            run: () => Activities.push(MomentLogic.bluetoothSpec("WH-1000XM5", "headphones", 64)),
            wait: 400,
            expect: "privacy, below it: activity"
        },
        {
            name: "the Bluetooth moment is gone after three seconds",
            run: () => {},
            wait: 3200,
            expect: "privacy"
        },
        {
            name: "every stream stops: the privacy row goes",
            run: () => {
                Activities.remove("privacy:mic");
                Activities.remove("privacy:camera");
                Activities.remove("privacy:screen");
            },
            wait: 600,
            expect: "hidden"
        },
        {
            name: "dictating, then a screenshot: it shows below the bars first",
            run: () => {
                preview.speak("listening");
                Activities.push(preview.shot(7000));
            },
            wait: 1200,
            expect: "dictation, below it: activity"
        },
        {
            name: "the microphone is in use while dictating: the privacy dot waits beside",
            run: () => Activities.push(PrivacyLogic.usageSpec({
                    kind: "mic",
                    apps: ["gvoice"]
                })),
            wait: 3000,
            expect: "activity, beside it: dictation, privacy"
        },
        {
            name: "all of it ends",
            run: () => {
                preview.speak("idle");
                Activities.remove("privacy:mic");
                Activities.remove("moment:screenshot");
            },
            wait: 1500,
            expect: "hidden"
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

    function shot(ms: int): var {
        return Object.assign(MomentLogic.screenshotSpec(Quickshell.shellPath("assets/inspector/screenshot.svg")), {
            until: ms
        });
    }

    function timer(id: string, label: string, left: real, total: real, paused: bool): var {
        const now = Date.now();
        return Logic.timerItem({
            id: id,
            label: label,
            total: total,
            deadline: now + left,
            left: left,
            paused: paused,
            finished: false,
            quiet: false
        }, now);
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
        color: Appearance.colour.surfaceSolid

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
