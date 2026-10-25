import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.config
import qs.services
import qs.modules.island
import "../modules/island/upgrade-samples.js" as Samples
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
            name: "clear the stage for the system update",
            run: () => {
                island.fanning = false;
                for (const e of [...Notifications.popups])
                    Notifications.dismiss(e);
                preview.speak("idle");
                Launching.shown = [];
            },
            wait: 1500,
            expect: "hidden"
        },
        {
            name: "the kernel update starts and waits for the password",
            run: () => SystemUpgrade.mock("", -2, "7.2.10"),
            expect: "upgrade"
        },
        {
            name: "downloading, a ring and the stage in words",
            run: () => SystemUpgrade.mock(Samples.download, -2, "7.2.10"),
            expect: "upgrade"
        },
        {
            name: "after one glance it goes up into the band",
            run: () => {},
            wait: SystemUpgrade.lingerMs,
            expect: "hidden",
            holds: () => island.lifted > 0 && island.overviewRows.some(r => r.key === "upgrade")
        },
        {
            name: "opening the island lists it again",
            run: () => island.pinned = true,
            expect: "overview",
            holds: () => island.lifted > 0
        },
        {
            name: "pressing it turns the island into the update",
            run: () => island.choose({
                    key: "upgrade",
                    kind: "upgrade"
                }),
            wait: 300,
            expect: "the system update",
            holds: () => island.lifted < 0
        },
        {
            name: "the update view while it downloads",
            run: () => {},
            expect: "the system update",
            holds: () => island.presentation === "task" && SystemUpgrade.cancellable
        },
        {
            name: "installing, too late to cancel",
            run: () => SystemUpgrade.mock(Samples.install, -2, "7.2.10"),
            expect: "the system update",
            holds: () => !SystemUpgrade.cancellable && SystemUpgrade.stage === 2
        },
        {
            name: "the hooks run",
            run: () => SystemUpgrade.mock(Samples.hooks, -2, "7.2.10"),
            expect: "the system update",
            holds: () => SystemUpgrade.stage === 3
        },
        {
            name: "pacman asks a question",
            run: () => SystemUpgrade.mock(Samples.question, -2, "7.2.10"),
            expect: "the system update",
            holds: () => SystemUpgrade.asking
        },
        {
            name: "done, with a restart to do",
            run: () => {
                Pacman.stale = true;
                SystemUpgrade.mock(Samples.done, 0, "7.2.10");
            },
            expect: "the system update",
            holds: () => SystemUpgrade.state === "done"
        },
        {
            name: "failed, plain words and a way out",
            run: () => {
                Pacman.stale = false;
                SystemUpgrade.mock(Samples.failed, 1, "7.2.10");
            },
            expect: "the system update",
            holds: () => SystemUpgrade.state === "failed"
        },
        {
            name: "hidden, the failure waits as a row",
            run: () => island.close(),
            wait: 400,
            expect: "upgrade"
        },
        {
            name: "a notification still takes the island over the row",
            run: () => preview.notify("Discord", "marcus", "did the update go through?", false),
            wait: 400,
            expect: "one notification, below it: upgrade"
        },
        {
            name: "seen and dismissed, the island is empty",
            run: () => {
                for (const e of [...Notifications.popups])
                    Notifications.dismiss(e);
                SystemUpgrade.acknowledge();
            },
            wait: 1500,
            expect: "hidden"
        },
        {
            name: "the overview, where the clock, the date and the weather can be pressed",
            run: () => {
                Clock.startTimer(25 * 60, "Focus");
                Clock.startTimer(4 * 60, "Tea");
                island.pinned = true;
            },
            wait: 1200,
            expect: "overview"
        },
        {
            name: "the clock opens the timers",
            run: () => island.choose({
                    kind: "timers"
                }),
            wait: 1200,
            expect: "the timers"
        },
        {
            name: "back goes to the overview it came from",
            run: () => island.back(),
            wait: 900,
            expect: "overview"
        },
        {
            name: "the date opens the calendar",
            run: () => island.choose({
                    kind: "calendar"
                }),
            wait: 1200,
            expect: "the calendar"
        },
        {
            name: "the weather opens the forecast",
            run: () => {
                island.back();
                island.choose({
                    kind: "weather"
                });
            },
            wait: 4000,
            expect: "the weather"
        },
        {
            name: "the forecast could not update: the last one shows with its age",
            run: () => {
                Weather.take("", preview.forecastAnswer());
                Weather.outlook = [];
                Weather.fetchedAt = Date.now() - 3 * 3600000;
                Weather.take("", "\n000 6");
            },
            wait: 1200,
            expect: "the weather"
        },
        {
            name: "no forecast ever loaded: weather unavailable, try again",
            run: () => {
                Weather.current = null;
                Weather.wttrData = null;
                Weather.outlook = [];
                Weather.take("", "\n000 6");
            },
            wait: 1200,
            expect: "the weather"
        },
        {
            name: "a place the weather does not know points to the setting",
            run: () => Weather.take("Lyngbyy", "location not found: upstream error: opencage: invalid response\n\n500 0"),
            wait: 1200,
            expect: "the weather"
        },
        {
            name: "back in the overview, a failed weather is tried again",
            run: () => {
                Weather.fetchedAt = Date.now();
                island.back();
            },
            wait: 1200,
            expect: "overview"
        },
        {
            name: "the shell update opens in the island, not the sidebar",
            run: () => island.choose({
                    kind: "update",
                    key: "update:mock",
                    mock: true
                }),
            wait: 1200,
            expect: "the shell update"
        },
        {
            name: "the notifications row opens the history",
            run: () => {
                preview.remember("Discord", "marcus", "are you coming tonight?");
                preview.remember("Firefox", "Download finished", "linux-zen-6.17.tar.zst");
                preview.remember("Signal", "Mum", "call me when you get a minute");
                island.choose({
                    kind: "notifications"
                });
            },
            wait: 1200,
            expect: "the notifications"
        },
        {
            name: "a left swipe in the history closes its row up",
            run: () => {
                preview.before = Notifications.history.length;
                preview.cards(island.stage).find(c => c.count === 1 && !c.entry.leaving)?.fling(-1);
            },
            wait: 1500,
            expect: "the notifications",
            holds: () => Notifications.history.length === preview.before - 1 && preview.gapless()
        },
        {
            name: "back in the overview, the newest sit under the clock with a row for the rest",
            run: () => {
                preview.remember("Steam", "Download complete", "Hollow Knight: Silksong");
                preview.remember("Thunderbird", "Invoice", "your invoice for October is ready");
                island.back();
            },
            wait: 1500,
            expect: "overview",
            holds: () => island.recent.length === 3 && island.unlisted === Notifications.history.length - 3
        },
        {
            name: "a swipe away in the overview closes its row and the next one comes up",
            run: () => {
                preview.before = Notifications.history.length;
                preview.cardOf(island.recentGroups.find(g => g.entries.length === 1)?.entries[0])?.fling(1);
            },
            wait: 1500,
            expect: "overview",
            holds: () => Notifications.history.length === preview.before - 1 && island.recent.length === 3 && preview.gapless() && preview.tidy()
        },
        {
            name: "a click on one with nothing to open shows it big in the island",
            run: () => {
                preview.remember("notify-send", "Backup finished", "412 files, 3.1 GB, nothing failed. The next run is tomorrow at 03:00, and the old snapshots from last month were pruned.");
                preview.before = Notifications.history.length;
                Notifications.activate(Notifications.history[0]);
            },
            wait: 1500,
            expect: "a notification",
            holds: () => island.reading === Notifications.history[0] && Notifications.history.length === preview.before
        },
        {
            name: "swiping it away closes the view and it is gone",
            run: () => preview.cardOf(island.reading)?.fling(1),
            wait: 1500,
            expect: "overview",
            holds: () => Notifications.history.length === preview.before - 1
        },
        {
            name: "one app's notifications fold into one card with a count",
            run: () => {
                for (const n of [11, 12, 13])
                    preview.arrive("qBittorrent", "Download completed", `Mairimashita Iruma-kun 4th Season - ${n}.mkv`);
            },
            wait: 1500,
            expect: "overview",
            holds: () => island.recentGroups[0]?.entries.length === 3 && preview.torrents().length === 1 && preview.torrents()[0].count === 3 && preview.tidy()
        },
        {
            name: "a click on the folded group opens it up to all of them",
            run: () => preview.areaOf(preview.torrents()[0])?.parent.tapped(),
            wait: 1500,
            expect: "overview",
            holds: () => preview.torrents().length === 3 && Notifications.history.filter(e => e.appName === "qBittorrent").length === 3 && preview.tidy()
        },
        {
            name: "a click on its count folds it again",
            run: () => preview.torrents().find(c => c.count > 1)?.countTapped(),
            wait: 1500,
            expect: "overview",
            holds: () => preview.torrents().length === 1 && preview.tidy()
        },
        {
            name: "swiping the folded group away clears every one of them",
            run: () => preview.torrents()[0]?.fling(1),
            wait: 1800,
            expect: "overview",
            holds: () => Notifications.history.every(e => e.appName !== "qBittorrent") && preview.torrents().length === 0 && preview.tidy()
        },
        {
            name: "two quick swipes in a row leave no gap and no overlap",
            run: () => {
                for (const n of [1, 2, 3, 4])
                    preview.arrive(`App ${n}`, "Something happened", "a line of text");
                for (const entry of [island.recent[0], island.recent[1]]) {
                    const area = preview.drag(entry, 140);
                    area?.advance(300, 0);
                    area?.conclude();
                }
            },
            wait: 2500,
            expect: "overview",
            holds: () => island.recent.length === 3 && preview.tidy()
        },
        {
            name: "the history folds by app too",
            run: () => {
                preview.arrive("Discord", "marcus", "are you coming tonight?");
                preview.arrive("Discord", "marcus", "we leave at eight");
                island.choose({
                    kind: "notifications"
                });
            },
            wait: 1500,
            expect: "the notifications",
            holds: () => {
                const shown = preview.cards(island.stage).filter(c => c.entry.appName === "Discord" && !c.entry.leaving);
                return shown.length === 1 && shown[0].count === 2;
            }
        },
        {
            name: "dictating with a view open steps out beside the island",
            run: () => preview.speak("listening"),
            wait: 1500,
            expect: "the notifications",
            holds: () => island.voiceShown > 0.99
        },
        {
            name: "back in the overview it is a row again",
            run: () => island.back(),
            wait: 1500,
            expect: "overview",
            holds: () => island.voiceShown < 0.01
        },
        {
            name: "dictation ends",
            run: () => preview.speak("idle"),
            wait: 1200,
            expect: "overview"
        },
        {
            name: "escape goes back, and again closes",
            run: () => {
                island.back();
                island.back();
                for (const t of [...Clock.timers])
                    Clock.removeTimer(t.id);
            },
            wait: 1500,
            expect: "hidden"
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
        },
        {
            name: "a voice assistant starts listening: Microphone on, for a glance",
            run: () => Privacy.mock([
                    {
                        kind: "mic",
                        apps: ["PipeWire ALSA [python3.12]"]
                    }
                ], [
                    {
                        name: "diablo-voice",
                        command: "python -m voice",
                        device: "Scarlett 2i2 USB Mic1",
                        pid: 1042
                    }
                ]),
            wait: 800,
            expect: "privacy",
            holds: () => island.activities.some(a => a.key === "privacy:privacy:mic" && a.text === "Microphone on")
        },
        {
            name: "after the glance it tucks away though the assistant keeps listening",
            run: () => {},
            wait: Notices.glanceMs + 800,
            expect: "hidden"
        },
        {
            name: "the overview still says Microphone on",
            run: () => island.pinned = true,
            wait: 1200,
            expect: "overview",
            holds: () => island.overviewRows.some(r => r.key === "privacy:privacy:mic")
        },
        {
            name: "pressing it turns the island into what is listening",
            run: () => island.choose(Privacy.micRow),
            wait: 1200,
            expect: "the microphone",
            holds: () => Privacy.listeners.length === 1 && Privacy.listeners[0].name === "diablo-voice"
        },
        {
            name: "the assistant stops: back out, and nothing is left",
            run: () => {
                island.back();
                island.back();
                Privacy.mock(null, null);
            },
            wait: 1500,
            expect: "hidden"
        }
    ]

    function remember(app: string, summary: string, body: string): void {
        const entry = entryComponent.createObject(preview, {
            appName: app,
            summary: summary,
            body: body,
            urgency: NotificationUrgency.Normal,
            timeout: 0,
            live: false,
            time: Date.now() - 60000 * (preview.made + 1) + preview.made++
        });
        Notifications.history = [entry, ...Notifications.history];
    }


    function cards(from: Item): var {
        const out = [];
        for (const child of from?.children ?? []) {
            if (child.visible && child.density !== undefined && typeof child.fling === "function" && child.entry)
                out.push(child);
            out.push(...preview.cards(child));
        }
        return out;
    }

    function cardOf(entry: var): Item {
        return preview.cards(island.stage).find(c => c.entry === entry && c.opacity > 0.01) ?? null;
    }

    function gapless(): bool {
        return preview.cards(island.stage).every(c => c.shiftFade < 0.5 || c.entry.leaving);
    }

    function torrents(): var {
        return preview.cards(island.stage).filter(c => c.entry.appName === "qBittorrent" && c.opacity > 0.01 && !c.entry.leaving);
    }

    function areaOf(item: Item): var {
        for (const child of item?.children ?? []) {
            if (typeof child.conclude === "function" && typeof child.advance === "function")
                return child;
            const deeper = preview.areaOf(child);
            if (deeper)
                return deeper;
        }
        return null;
    }

    function drag(entry: var, dx: real): var {
        const area = preview.areaOf(preview.cardOf(entry));
        if (!area)
            return null;
        area.begin();
        area.advance(dx / 2, 0);
        area.advance(dx, 0);
        return area;
    }

    function tidy(): bool {
        const rows = preview.cards(island.stage).filter(c => c.opacity > 0.01 && !c.entry.leaving).map(c => ({
                    y: c.mapToItem(island.stage, 0, 0).y,
                    h: c.height,
                    app: c.entry.appName
                })).sort((p, q) => p.y - q.y);
        return rows.every((r, i) => {
            if (i === 0)
                return true;
            const gap = r.y - (rows[i - 1].y + rows[i - 1].h);
            return Math.abs(gap) < 2 || r.app !== rows[i - 1].app && Math.abs(gap - Appearance.padding.small) < 2;
        });
    }

    function arrive(app: string, summary: string, body: string): void {
        const entry = entryComponent.createObject(preview, {
            appName: app,
            summary: summary,
            body: body,
            urgency: NotificationUrgency.Normal,
            timeout: 0,
            live: false,
            time: Date.now() + preview.made++
        });
        Notifications.history = [entry, ...Notifications.history];
    }

    property int before: 0
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

    function forecastAnswer(): string {
        const day = (date, high, low, code, desc, rain) => ({
                date: date,
                maxtempC: String(high),
                mintempC: String(low),
                maxtempF: String(Math.round(high * 1.8 + 32)),
                mintempF: String(Math.round(low * 1.8 + 32)),
                hourly: [{
                        time: "1200",
                        weatherCode: String(code),
                        weatherDesc: [{
                                value: desc
                            }],
                        chanceofrain: String(rain)
                    }]
            });
        return JSON.stringify({
            current_condition: [{
                    temp_C: "9",
                    temp_F: "48",
                    weatherCode: "116",
                    weatherDesc: [{
                            value: "Partly cloudy"
                        }]
                }],
            nearest_area: [{
                    areaName: [{
                            value: "Kongens Lyngby"
                        }]
                }],
            weather: [day("2026-10-25", 11, 6, 116, "Partly cloudy", 10), day("2026-10-26", 12, 7, 296, "Light rain", 70), day("2026-10-27", 9, 4, 113, "Sunny", 0)]
        }) + "\n200 0";
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
