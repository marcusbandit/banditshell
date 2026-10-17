pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import qs.config
import qs.components
import qs.services
import "../../services/activities.js" as Logic

Scope {
    id: root

    property bool open: false
    property Item island: null
    property var screen: null

    property string voice: "off"
    property var made: []
    property int drawn: 0
    property bool timing: false
    property var notices: []
    property var stagedKinds: []
    property var taskKinds: []
    property int chosenAt: -1
    property string clicked: ""

    readonly property var standing: root.made.filter(e => e && !e.leaving && Notifications.popups.includes(e))
    readonly property var critical: root.standing.filter(e => e.urgency === NotificationUrgency.Critical)
    readonly property var ordinary: root.standing.filter(e => e.urgency !== NotificationUrgency.Critical)
    readonly property var launches: Launching.shown.filter(r => r.mock)
    readonly property bool frontIsMine: !!root.island && root.made.includes(root.island.alerts[0])
    readonly property bool opening: root.launches.some(r => r.state === "waiting")

    readonly property var apps: [
        {
            id: "mock-firefox",
            name: "Firefox",
            icon: "firefox"
        },
        {
            id: "mock-spotify",
            name: "Spotify",
            icon: "spotify"
        },
        {
            id: "mock-steam",
            name: "Steam",
            icon: "steam"
        }
    ]

    property int storyAt: -1
    property string storyCaption: ""

    readonly property var panel: panelLoader.item

    readonly property var pool: [
        {
            appName: "Discord",
            appIcon: "discord",
            summary: "marcus",
            body: "are you coming tonight?"
        },
        {
            appName: "Firefox",
            appIcon: "firefox",
            summary: "Download finished",
            body: "linux-zen-6.17.tar.zst"
        },
        {
            appName: "Signal",
            appIcon: "signal-desktop",
            summary: "Mum",
            body: "Call me when you get a minute, nothing urgent",
            actions: ["Reply", "Mark as read"]
        },
        {
            appName: "Thunderbird",
            appIcon: "thunderbird",
            summary: "Re: the quarterly numbers, and why the spreadsheet is wrong again",
            body: "I went through every tab twice and the totals in column F still do not match the summary sheet. Can we go over it together on Monday, before the meeting?"
        },
        {
            appName: "Screenshot",
            appIcon: "camera-photo",
            summary: "Screenshot saved",
            body: "Pictures/Screenshots",
            picture: true
        },
        {
            appName: "backup",
            summary: "Backup finished",
            body: "412 files, 3.2 GB to /mnt/vault"
        },
        {
            appName: "Discord",
            appIcon: "discord",
            summary: "sam",
            body: "lol"
        },
        {
            appName: "Steam",
            appIcon: "steam",
            summary: "Hollow Knight: Silksong",
            body: "Download complete. Ready to play.",
            actions: ["Play"]
        }
    ]

    readonly property var alarm: ({
            appName: "BanditShell",
            summary: "Battery at 4%",
            body: "Plug in now."
        })

    readonly property var noticeLooks: ({
            download: {
                kind: "download",
                name: "linux-zen-6.17.tar.zst",
                path: "/tmp/linux-zen-6.17.tar.zst",
                more: 2
            },
            update: {
                kind: "update",
                count: 12,
                headline: "The island learned every situation"
            },
            kernel: {
                kind: "kernel",
                version: "6.17.3",
                upgrading: false
            },
            restart: {
                kind: "restart",
                version: "6.17.3"
            },
            held: {
                kind: "held",
                count: 3
            },
            music: {
                kind: "music"
            },
            volume: Logic.levelMoment("volume", 0.45, false, 1),
            mute: Logic.levelMoment("volume", 0.45, true, 1),
            brightness: Logic.levelMoment("brightness", 0.7, false, 1),
            mic: Logic.levelMoment("mic", 1, true, 1)
        })

    readonly property var stagedLooks: ({
            timer: {
                key: "timer:mock-tea",
                id: "mock-tea",
                kind: "timer",
                text: "Tea",
                remaining: 450000,
                clock: "7:30",
                sample: "00:00",
                progress: 0.75,
                paused: false,
                ending: false,
                mock: true
            },
            paused: {
                key: "timer:mock-paused",
                id: "mock-paused",
                kind: "timer",
                text: "Laundry",
                remaining: 1500000,
                clock: "25:00",
                sample: "00:00",
                progress: 0.5,
                paused: true,
                ending: false,
                mock: true
            },
            ending: {
                key: "timer:mock-eggs",
                id: "mock-eggs",
                kind: "timer",
                text: "Eggs",
                remaining: 8000,
                clock: "0:08",
                sample: "00:00",
                progress: 0.04,
                paused: false,
                ending: true,
                mock: true
            },
            alarm: Object.assign(Logic.alarmItem("mock-alarm", "07:30  Wake up", Logic.alarmActions(true)), {
                mock: true
            }),
            done: Object.assign(Logic.alarmItem("timer:mock-done", "Tea is done", Logic.alarmActions(false)), {
                mock: true
            })
        })

    readonly property var taskLooks: ({
            build: {
                id: "mock-build",
                text: "Building",
                detail: "compiling shaders",
                progress: 0.4,
                icon: "hardware"
            },
            sync: {
                id: "mock-sync",
                text: "Syncing photos",
                icon: "sync"
            },
            built: {
                id: "mock-built",
                text: "Build",
                detail: "412 files",
                icon: "hardware",
                outcome: "done"
            },
            broke: {
                id: "mock-broke",
                text: "Deploy",
                detail: "exit 2",
                progress: 0.8,
                icon: "rocket_launch",
                outcome: "failed"
            }
        })

    readonly property var verbs: ({
            launch: "focuses the app's window",
            dictation: "opens the transcription history",
            music: "opens the media panel",
            external: "runs the command it was given, if any",
            timer: "pauses or resumes the timer",
            alarm: "stops or snoozes the alarm from its buttons",
            level: "nothing, it only shows",
            notifications: "opens the launcher on the notification history",
            held: "opens the launcher on what was held while quiet",
            update: "opens the update menu",
            kernel: "starts the kernel upgrade",
            restart: "opens the session menu",
            download: "shows the file in Files"
        })

    readonly property var situations: [
        {
            name: "Nothing"
        },
        {
            name: "Dictating",
            voice: "listening"
        },
        {
            name: "Speech turning into text",
            voice: "processing"
        },
        {
            name: "An app opening",
            launches: ["waiting"]
        },
        {
            name: "Two apps opening",
            launches: ["waiting", "waiting"]
        },
        {
            name: "One opened, one never did",
            launches: ["here", "lost"]
        },
        {
            name: "An app opens while dictating",
            voice: "listening",
            launches: ["waiting"]
        },
        {
            name: "A notification while dictating",
            voice: "listening",
            notes: 1
        },
        {
            name: "Music changes while dictating",
            voice: "listening",
            notices: ["music"]
        },
        {
            name: "A download finished",
            notices: ["download"]
        },
        {
            name: "An update and a kernel",
            notices: ["update", "kernel"]
        },
        {
            name: "Quiet ended with three held back",
            notices: ["held"]
        },
        {
            name: "One notification",
            notes: 1
        },
        {
            name: "Three notifications",
            notes: 3
        },
        {
            name: "Critical while dictating",
            voice: "listening",
            notes: 2,
            urgent: true
        },
        {
            name: "Everything at once",
            voice: "listening",
            launches: ["waiting", "waiting"],
            notices: ["music"],
            notes: 1
        },
        {
            name: "A timer running",
            staged: ["timer"]
        },
        {
            name: "A timer, paused",
            staged: ["paused"]
        },
        {
            name: "A timer almost done",
            staged: ["ending"]
        },
        {
            name: "A timer while dictating",
            voice: "listening",
            staged: ["timer"]
        },
        {
            name: "A timer is done",
            staged: ["done"]
        },
        {
            name: "An alarm rings",
            staged: ["alarm"]
        },
        {
            name: "An alarm rings over a notification",
            notes: 1,
            staged: ["alarm"]
        },
        {
            name: "A build with progress",
            tasks: ["build"]
        },
        {
            name: "A task with no progress",
            tasks: ["sync"]
        },
        {
            name: "Two tasks",
            tasks: ["build", "sync"]
        },
        {
            name: "A task finished and one failed",
            tasks: ["built", "broke"]
        },
        {
            name: "A build while dictating",
            voice: "listening",
            tasks: ["build"]
        },
        {
            name: "The volume changes",
            notices: ["volume"]
        },
        {
            name: "The volume is muted",
            notices: ["mute"]
        },
        {
            name: "The brightness changes",
            notices: ["brightness"]
        },
        {
            name: "The microphone is muted",
            notices: ["mic"]
        },
        {
            name: "The overview",
            pinned: true
        },
        {
            name: "The overview, dictating",
            pinned: true,
            voice: "listening"
        },
        {
            name: "The overview, two arrive",
            pinned: true,
            notes: 2
        }
    ]

    readonly property var story: [
        {
            caption: "you start dictating",
            run: () => root.setVoice("listening")
        },
        {
            caption: "a notification comes in: it takes the big spot, dictation glides into a bubble",
            run: () => root.setNotes(1, false),
            hold: 3400
        },
        {
            caption: "the notification goes: dictation glides back",
            run: () => root.setNotes(0, false)
        },
        {
            caption: "you open Firefox: it shows below dictation, then takes the big spot",
            run: () => root.setLaunches(["waiting"]),
            hold: 4600
        },
        {
            caption: "you open Spotify while it opens: two lines",
            run: () => root.setLaunches(["waiting", "waiting"])
        },
        {
            caption: "the music changes: it has a moment below",
            run: () => root.setNotices(["music"]),
            hold: 3200
        },
        {
            caption: "its moment is over",
            run: () => root.setNotices([])
        },
        {
            caption: "a notification on top of it all: it takes the big spot, the apps glide aside",
            run: () => root.setNotes(1, false),
            hold: 3400
        },
        {
            caption: "Steam starts opening while it shows: below the card, then into the apps' bubble",
            run: () => root.setLaunches(["waiting", "waiting", "waiting"]),
            hold: 4600
        },
        {
            caption: "two more notifications: a stack",
            run: () => root.setNotes(3, false),
            hold: 3200
        },
        {
            caption: "you pull it halfway open",
            run: () => root.island.dragTo(0.5)
        },
        {
            caption: "and let it open: everything travels in",
            run: () => root.island.dragEnd(true),
            hold: 3400
        },
        {
            caption: "Firefox finishes opening, inside the overview",
            run: () => root.setLaunches(["here", "waiting", "waiting"])
        },
        {
            caption: "you close it: everything travels back",
            run: () => root.island.pinned = false,
            hold: 3400
        },
        {
            caption: "you flick the top one away to the right",
            run: () => root.island.flickFront(1)
        },
        {
            caption: "you flick the next one away too: the one behind rises into its place",
            run: () => root.island.flickFront(1)
        },
        {
            caption: "you flick the last one left: the apps glide back into the big spot",
            run: () => root.island.flickFront(-1),
            hold: 3400
        },
        {
            caption: "Spotify fails to open",
            run: () => root.setLaunches(["here", "lost", "waiting"])
        },
        {
            caption: "Firefox and Spotify are done and go",
            run: () => root.setLaunches([null, null, "waiting"])
        },
        {
            caption: "Steam finishes opening",
            run: () => root.setLaunches([null, null, "here"])
        },
        {
            caption: "Steam is done: dictation glides back",
            run: () => root.setLaunches([]),
            hold: 3000
        },
        {
            caption: "you stop talking: it turns speech into text",
            run: () => root.setVoice("processing")
        },
        {
            caption: "a critical battery warning takes the big spot at once",
            run: () => root.notify(root.alarm, true),
            hold: 3400
        },
        {
            caption: "two more arrive behind it",
            run: () => root.setNotes(2, true),
            hold: 3000
        },
        {
            caption: "you clear them all: they fly off one after another",
            run: () => root.island.clearNotifications(root.standing),
            hold: 3000
        },
        {
            caption: "the words are in: dictation ends",
            run: () => root.setVoice("off")
        },
        {
            caption: "a download finishes: it has the big spot to itself",
            run: () => root.setNotices(["download"])
        },
        {
            caption: "an update shows up below it",
            run: () => root.setNotices(["download", "update"])
        },
        {
            caption: "you start dictating: it takes the big spot, their moments stay below",
            run: () => root.setVoice("listening"),
            hold: 3400
        },
        {
            caption: "their moments are over",
            run: () => root.setNotices([])
        },
        {
            caption: "you open the overview",
            run: () => root.island.pinned = true,
            hold: 3200
        },
        {
            caption: "and close it",
            run: () => root.island.pinned = false,
            hold: 3200
        },
        {
            caption: "it all clears",
            run: () => root.reset()
        }
    ]

    property bool storyPaused: false

    function storyStep(): void {
        const beat = root.story[root.storyAt];
        if (!beat) {
            root.storyAt = -1;
            return;
        }
        root.storyCaption = `${root.storyAt + 1}/${root.story.length} · ${beat.caption}`;
        beat.run();
        root.storyAt += 1;
        storyTimer.interval = beat.hold ?? 2600;
        if (root.storyAt < root.story.length && !root.storyPaused)
            storyTimer.restart();
    }

    function storyPause(): void {
        if (root.storyAt < 0)
            return;
        root.storyPaused = !root.storyPaused;
        if (root.storyPaused)
            storyTimer.stop();
        else
            storyTimer.restart();
    }

    function storyNext(): void {
        if (root.storyAt < 0)
            return;
        storyTimer.stop();
        root.storyStep();
    }

    function show(win: var): void {
        if (root.open && root.island !== win.island)
            root.close();
        root.island = win.island;
        root.screen = win.screen;
        root.open = true;
    }

    function close(): void {
        if (!root.open)
            return;
        root.reset();
        for (const e of root.made)
            if (e && Notifications.history.includes(e))
                Notifications.forget(e);
        root.made = [];
        root.chosenAt = -1;
        root.clicked = "";
        root.open = false;
    }

    function reset(): void {
        root.setVoice("off");
        root.setLaunches([]);
        root.setNotices([]);
        root.setStaged([]);
        root.setTasks([]);
        root.setNotes(0, false);
        root.island?.dragEnd(false);
        if (root.island)
            root.island.pinned = false;
    }

    function apply(index: int): void {
        const s = root.situations[index];
        if (!s || !root.island)
            return;
        storyTimer.stop();
        root.storyAt = -1;
        root.storyCaption = "";
        root.chosenAt = index;
        root.island.dragEnd(false);
        root.setVoice(s.voice ?? "off");
        root.setLaunches(s.launches ?? []);
        root.setNotices(s.notices ?? []);
        root.setStaged(s.staged ?? []);
        root.setTasks(s.tasks ?? []);
        root.island.pinned = s.pinned ?? false;
        root.setNotes(s.notes ?? 0, s.urgent ?? false);
        root.island.arrange(true);
    }

    function step(by: int): void {
        root.apply(Math.max(0, Math.min(root.situations.length - 1, root.chosenAt + by)));
    }

    function replay(): void {
        if (root.chosenAt < 0)
            return;
        root.reset();
        again.restart();
    }

    function setVoice(v: string): void {
        root.voice = v;
        Dictation.phase = v === "off" ? "idle" : v;
    }

    function notify(spec: var, urgent: bool): void {
        const named = text => ({
                identifier: text.toLowerCase(),
                text: text,
                invoke: () => root.clicked = `${spec.appName}: ${text}`
            });
        const fake = fakeNotification.createObject(root, {
            appName: spec.appName,
            summary: spec.summary,
            body: spec.body,
            appIcon: spec.appIcon ?? "",
            image: spec.picture ? Wallpaper.current : "",
            urgency: urgent ? NotificationUrgency.Critical : NotificationUrgency.Normal,
            actions: [
                {
                    identifier: "default",
                    text: "",
                    invoke: () => root.clicked = `${spec.appName}: opened`
                },
                ...(spec.actions ?? []).map(named)]
        });
        const entry = notificationEntry.createObject(root, {
            notification: fake,
            time: Date.now(),
            timeout: root.timing && !urgent ? Notifications.defaultTimeout : 0
        });
        root.made = [...root.made.filter(e => e), entry];
        Notifications.popups = [entry, ...Notifications.popups];
        Notifications.history = [entry, ...Notifications.history];
    }

    function setNotes(count: int, urgent: bool): void {
        for (const e of root.ordinary.slice(count))
            Notifications.dismiss(e);
        for (let i = root.ordinary.length; i < count; i++)
            root.notify(root.pool[root.drawn++ % root.pool.length], false);
        if (urgent && root.critical.length === 0)
            root.notify(root.alarm, true);
        if (!urgent)
            for (const e of root.critical)
                Notifications.dismiss(e);
    }

    function setLaunches(states: var): void {
        const now = Date.now();
        const others = Launching.shown.filter(r => !r.mock);
        const mine = states.slice(0, root.apps.length).map((state, i) => {
            if (!state)
                return null;
            const app = root.apps[i];
            const was = root.launches.find(r => r.id === app.id);
            return {
                id: app.id,
                name: app.name,
                mark: was?.mark ?? Launching.markFor({
                    id: app.icon,
                    icon: app.icon
                }),
                marks: [app.icon],
                at: was?.at ?? now,
                state: state,
                done: state === "waiting" ? 0 : (was?.state === state ? was.done : now),
                mock: true
            };
        }).filter(r => r);
        Launching.now = now;
        Launching.shown = [...others, ...mine];
    }

    function slots(): var {
        return root.apps.map(app => root.launches.find(r => r.id === app.id)?.state ?? null);
    }

    function openApp(): void {
        const states = root.slots();
        const free = states.indexOf(null);
        if (free < 0)
            return;
        states[free] = "waiting";
        root.setLaunches(states);
    }

    function settleApp(state: string): void {
        const states = root.slots();
        const i = states.indexOf("waiting");
        if (i < 0)
            return;
        states[i] = state;
        root.setLaunches(states);
    }

    function playStory(): void {
        root.chosenAt = -1;
        root.storyPaused = false;
        root.reset();
        root.storyAt = 0;
        storyTimer.interval = 500;
        storyTimer.restart();
    }

    function setNotices(kinds: var): void {
        for (const k of root.notices.filter(k => !kinds.includes(k)))
            Notices.settle(`mock:${k}`);
        for (const k of kinds.filter(k => !root.notices.includes(k)))
            Notices.pass(Object.assign({}, root.noticeLooks[k], {
                key: `mock:${k}`,
                mock: true
            }));
        root.notices = kinds;
    }

    function setStaged(kinds: var): void {
        root.stagedKinds = kinds;
        Activities.staged = kinds.map(k => root.stagedLooks[k]);
    }

    function flipStaged(kind: string): void {
        root.setStaged(root.stagedKinds.includes(kind) ? root.stagedKinds.filter(k => k !== kind) : [...root.stagedKinds, kind]);
    }

    function setTasks(kinds: var): void {
        for (const k of root.taskKinds.filter(k => !kinds.includes(k)))
            Activities.remove(root.taskLooks[k].id);
        for (const k of kinds.filter(k => !root.taskKinds.includes(k))) {
            const look = root.taskLooks[k];
            Activities.push(Object.assign({}, look, {
                source: "inspector",
                act: () => root.clicked = `${look.text}: its own command ran`
            }));
            if (look.outcome)
                Activities.end(look.id, look.outcome, 600000);
        }
        root.taskKinds = kinds;
    }

    function flipTask(kind: string): void {
        root.setTasks(root.taskKinds.includes(kind) ? root.taskKinds.filter(k => k !== kind) : [...root.taskKinds, kind]);
    }

    function flipNotice(kind: string): void {
        root.setNotices(root.notices.includes(kind) ? root.notices.filter(k => k !== kind) : [...root.notices, kind]);
    }

    Component {
        id: fakeNotification

        MockNotification {}
    }

    Component {
        id: notificationEntry

        NotificationEntry {}
    }

    Connections {
        target: root.open ? root.island : null

        function onChosen(activity: var): void {
            const verb = root.verbs[activity?.kind] ?? "does nothing";
            root.clicked = activity?.mock ? `${activity.kind}: ${verb}, held back because it is made up` : `${activity?.kind}: ${verb}`;
            if (activity?.mock && activity.key) {
                Notices.settle(activity.key);
                root.notices = root.notices.filter(k => `mock:${k}` !== activity.key);
            }
        }
    }

    Timer {
        id: again

        interval: 700
        onTriggered: root.apply(root.chosenAt)
    }

    Timer {
        property bool talking: false
        property real span: 0
        property real left: 0
        property real peak: 0
        property int said: 0

        interval: 45
        repeat: true
        running: root.open && root.voice === "listening"

        onTriggered: {
            left -= interval;
            if (left <= 0) {
                talking = !talking;
                if (talking) {
                    span = 140 + Math.random() * 120;
                    peak = 0.4 + Math.random() * 0.5;
                    said += 1;
                } else {
                    span = said % 7 === 0 ? 350 + Math.random() * 450 : 50 + Math.random() * 100;
                }
                left = span;
            }
            const through = 1 - left / span;
            const level = talking ? peak * Math.sin(Math.PI * through) * (0.85 + Math.random() * 0.15) : 0.02 + Math.random() * 0.03;
            Dictation.heard(level);
        }
    }

    Timer {
        interval: 40
        repeat: true
        running: root.open && root.opening

        onTriggered: Launching.now = Date.now()
    }

    Timer {
        interval: 500
        repeat: true
        running: root.open && root.notices.length > 0

        onTriggered: {
            for (const k of root.notices)
                Notices.glance(`mock:${k}`, root.noticeLooks[k]?.ms);
        }
    }

    Timer {
        id: storyTimer

        interval: 500
        onTriggered: root.storyStep()
    }

    LazyLoader {
        id: panelLoader

        active: root.open

        PanelWindow {
            id: panel

            screen: root.screen
            anchors.right: true
            margins.right: Appearance.padding.huge
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            implicitWidth: card.width
            implicitHeight: card.height

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            WlrLayershell.namespace: "banditshell-inspector"

            SquircleRect {
                id: card

                readonly property real pad: Appearance.padding.card
                readonly property real gutter: Appearance.padding.large

                width: card.pad * 2 + card.gutter + left.width + right.width
                height: card.pad * 2 + whole.implicitHeight
                color: Appearance.colour.surfaceSolid
                stroke: Appearance.colour.fill
                strokeWidth: Appearance.stroke.line

                focus: true
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Down || event.key === Qt.Key_J)
                        root.step(1);
                    else if (event.key === Qt.Key_Up || event.key === Qt.Key_K)
                        root.step(-1);
                    else if (event.key === Qt.Key_R)
                        root.replay();
                    else if (event.key === Qt.Key_Right)
                        root.storyNext();
                    else if (event.key === Qt.Key_Space)
                        root.storyPause();
                    else if (event.key === Qt.Key_Escape)
                        root.close();
                    else
                        return;
                    event.accepted = true;
                }

                Column {
                    id: whole

                    x: card.pad
                    y: card.pad
                    width: card.width - card.pad * 2
                    spacing: Appearance.padding.normal

                    Item {
                        width: parent.width
                        height: Math.max(heading.implicitHeight, closeButton.implicitHeight)

                        Column {
                            id: heading

                            anchors.left: parent.left
                            anchors.right: closeButton.left
                            anchors.rightMargin: Appearance.padding.normal
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Appearance.padding.hair

                            StyledText {
                                width: parent.width
                                text: root.island?.situation ?? ""
                                font.pixelSize: Appearance.font.size.normal
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }

                            StyledText {
                                width: parent.width
                                text: ["island", root.island?.presentation ?? "", root.island?.pinned ? "pinned" : "", root.island?.pulling ? `held ${Math.round((root.island?.pullProgress ?? 0) * 100)}% open` : ""].filter(s => s).join(" · ")
                                color: Appearance.colour.textFaint
                            }
                        }

                        Button {
                            id: closeButton

                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "close"
                            style: "outlined"
                            onClicked: root.close()
                        }
                    }

                    Separator {
                        width: parent.width
                    }

                    Row {
                        spacing: card.gutter

                        Column {
                            id: left

                            width: 400
                            spacing: 0

                            Column {
                                width: parent.width
                                spacing: Appearance.padding.small
                                bottomPadding: Appearance.padding.normal

                                Button {
                                    icon: "play_arrow"
                                    text: "play the story"
                                    style: "tonal"
                                    onClicked: {
                                        card.forceActiveFocus();
                                        root.playStory();
                                    }
                                }

                                StyledText {
                                    width: parent.width
                                    visible: !!root.storyCaption
                                    text: `${root.storyCaption}${root.storyPaused ? " (paused)" : ""}`
                                    color: root.storyAt >= 0 ? Appearance.colour.text : Appearance.colour.textFaint
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }
                            }

                            Repeater {
                                model: root.situations

                                Item {
                                    id: row

                                    required property var modelData
                                    required property int index

                                    readonly property bool current: row.index === root.chosenAt

                                    width: left.width
                                    height: Appearance.font.line.small + Appearance.padding.small * 1.5

                                    SquircleRect {
                                        anchors.fill: parent
                                        color: row.current ? Appearance.colour.fillStrong : Appearance.colour.fill
                                        visible: row.current || rowPress.containsMouse
                                    }

                                    StyledText {
                                        x: Appearance.padding.normal
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - x - number.width - Appearance.padding.normal * 2
                                        text: row.modelData.name
                                        color: row.current ? Appearance.colour.text : Appearance.colour.textDim
                                        elide: Text.ElideRight
                                    }

                                    StyledText {
                                        id: number

                                        anchors.right: parent.right
                                        anchors.rightMargin: Appearance.padding.normal
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: `${row.index + 1}`
                                        color: Appearance.colour.textFaint
                                    }

                                    MouseArea {
                                        id: rowPress

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            card.forceActiveFocus();
                                            root.apply(row.index);
                                        }
                                    }
                                }
                            }
                        }

                        Column {
                            id: right

                            width: 380
                            spacing: Appearance.padding.normal

                            StyledText {
                                text: "voice"
                                color: Appearance.colour.textFaint
                            }

                            Segments {
                                width: parent.width
                                options: ["off", "listening", "processing"]
                                current: Math.max(0, ["off", "listening", "processing"].indexOf(root.voice))
                                onPicked: index => root.setVoice(["off", "listening", "processing"][index])
                            }

                            StyledText {
                                text: `notifications · ${root.standing.length} made up`
                                color: Appearance.colour.textFaint
                            }

                            Flow {
                                width: parent.width
                                spacing: Appearance.padding.small

                                Button {
                                    text: "one more"
                                    style: "outlined"
                                    onClicked: root.notify(root.pool[root.drawn++ % root.pool.length], false)
                                }

                                Button {
                                    text: "90 more"
                                    style: "outlined"
                                    onClicked: {
                                        for (let i = 0; i < 90; i++)
                                            root.notify(root.pool[root.drawn++ % root.pool.length], false);
                                    }
                                }

                                Button {
                                    text: "critical"
                                    style: "outlined"
                                    onClicked: root.notify(root.alarm, true)
                                }

                                Button {
                                    text: "flick away"
                                    style: "outlined"
                                    enabled: root.frontIsMine
                                    onClicked: root.island.flickFront(1)
                                }

                                Button {
                                    text: "clear all"
                                    style: "outlined"
                                    enabled: root.standing.length > 0
                                    onClicked: root.island.clearNotifications(root.standing)
                                }
                            }

                            Item {
                                width: parent.width
                                height: timingToggle.implicitHeight

                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "new ones time out"
                                    color: Appearance.colour.textDim
                                }

                                Toggle {
                                    id: timingToggle

                                    anchors.right: parent.right
                                    checked: root.timing
                                    onToggled: root.timing = !root.timing
                                }
                            }

                            StyledText {
                                text: `apps opening · ${root.launches.length} made up`
                                color: Appearance.colour.textFaint
                            }

                            Flow {
                                width: parent.width
                                spacing: Appearance.padding.small

                                Button {
                                    text: "open one"
                                    style: "outlined"
                                    enabled: root.launches.length < root.apps.length
                                    onClicked: root.openApp()
                                }

                                Button {
                                    text: "one opens"
                                    style: "outlined"
                                    enabled: root.opening
                                    onClicked: root.settleApp("here")
                                }

                                Button {
                                    text: "one fails"
                                    style: "outlined"
                                    enabled: root.opening
                                    onClicked: root.settleApp("lost")
                                }

                                Button {
                                    text: "clear"
                                    style: "outlined"
                                    enabled: root.launches.length > 0
                                    onClicked: root.setLaunches([])
                                }
                            }

                            StyledText {
                                text: "notices"
                                color: Appearance.colour.textFaint
                            }

                            Flow {
                                width: parent.width
                                spacing: Appearance.padding.small

                                Repeater {
                                    model: ["download", "update", "kernel", "restart", "held", "music", "volume", "mute", "brightness", "mic"]

                                    Button {
                                        required property string modelData

                                        text: modelData
                                        style: "outlined"
                                        checkable: true
                                        checked: root.notices.includes(modelData)
                                        onToggled: root.flipNotice(modelData)
                                    }
                                }
                            }

                            StyledText {
                                text: "timers and alarms"
                                color: Appearance.colour.textFaint
                            }

                            Flow {
                                width: parent.width
                                spacing: Appearance.padding.small

                                Repeater {
                                    model: ["timer", "paused", "ending", "done", "alarm"]

                                    Button {
                                        required property string modelData

                                        text: modelData
                                        style: "outlined"
                                        checkable: true
                                        checked: root.stagedKinds.includes(modelData)
                                        onToggled: root.flipStaged(modelData)
                                    }
                                }
                            }

                            StyledText {
                                text: "tasks pushed through the activity api"
                                color: Appearance.colour.textFaint
                            }

                            Flow {
                                width: parent.width
                                spacing: Appearance.padding.small

                                Repeater {
                                    model: ["build", "sync", "built", "broke"]

                                    Button {
                                        required property string modelData

                                        text: modelData
                                        style: "outlined"
                                        checkable: true
                                        checked: root.taskKinds.includes(modelData)
                                        onToggled: root.flipTask(modelData)
                                    }
                                }
                            }

                            Item {
                                width: parent.width
                                height: pinToggle.implicitHeight

                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "overview pinned open"
                                    color: Appearance.colour.textDim
                                }

                                Toggle {
                                    id: pinToggle

                                    anchors.right: parent.right
                                    checked: root.island?.pinned ?? false
                                    onToggled: root.island.pinned = !root.island.pinned
                                }
                            }

                            StyledText {
                                text: "held part way open"
                                color: Appearance.colour.textFaint
                            }

                            Item {
                                width: parent.width
                                height: Math.max(hold.implicitHeight, letGo.implicitHeight)

                                Slider {
                                    id: hold

                                    anchors.left: parent.left
                                    anchors.right: letGo.left
                                    anchors.rightMargin: Appearance.padding.normal
                                    anchors.verticalCenter: parent.verticalCenter
                                    value: root.island?.pulling ? root.island.pullProgress : 0
                                    onMoved: v => root.island.dragTo(v)
                                }

                                Button {
                                    id: letGo

                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "let go"
                                    style: "outlined"
                                    enabled: root.island?.pulling ?? false
                                    onClicked: root.island.dragEnd(false)
                                }
                            }

                            StyledText {
                                width: parent.width
                                visible: root.clicked !== ""
                                text: `last click · ${root.clicked}`
                                color: Appearance.colour.textDim
                                wrapMode: Text.Wrap
                            }
                        }
                    }

                    Separator {
                        width: parent.width
                    }

                    StyledText {
                        width: parent.width
                        text: "↑ ↓ step through the situations · R replays the arrival · during the story → jumps to the next beat, space pauses · Esc ends. Hover and click the island itself; everything here is made up and goes away when this closes."
                        color: Appearance.colour.textFaint
                        wrapMode: Text.Wrap
                    }
                }
            }
        }
    }
}
