pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "theme.js" as Theme

ShellRoot {
    id: root

    property var steps: []
    property int total: 0
    property bool finished: false
    property bool dryRun: false
    property int tallyDone: 0
    property int tallySkipped: 0
    property int tallyFailed: 0

    readonly property real progress: root.total > 0 ? root.resolved / root.total : 0

    readonly property int resolved: {
        let n = 0;
        for (const s of root.steps)
            if (s.state === "done" || s.state === "skip" || s.state === "failed")
                n++;
        return n;
    }

    readonly property var current: {
        for (const s of root.steps)
            if (s.state === "start")
                return s;
        return null;
    }

    readonly property var pieces: ["rail", "corners", "notch", "bar"]

    function pieceDue(k: int): real {
        return (k + 1) / (root.pieces.length + 1);
    }

    function pieceIn(name: string): bool {
        const k = root.pieces.indexOf(name);
        return k >= 0 && root.progress >= root.pieceDue(k);
    }

    readonly property string logPath: Quickshell.env("BANDITSHELL_INSTALL_LOG") || `${Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"}/banditshell-install.jsonl`

    function absorb(src: string): void {
        if (!src)
            return;

        const rows = [];
        let seenTotal = 0;
        let fin = false;
        let dry = false;
        let td = 0, ts = 0, tf = 0;

        for (const line of src.split("\n")) {
            const t = line.trim();
            if (!t)
                continue;

            let ev;
            try {
                ev = JSON.parse(t);
            } catch (e) {

                continue;
            }

            if (ev.state === "begin") {
                seenTotal = ev.total ?? 0;
                dry = !!ev.dry;
                continue;
            }

            if (ev.state === "finished") {
                fin = true;
                td = ev.done ?? 0;
                ts = ev.skipped ?? 0;
                tf = ev.failed ?? 0;
                continue;
            }

            if (ev.i === undefined)
                continue;

            seenTotal = Math.max(seenTotal, ev.total ?? 0);
            rows[ev.i] = {
                i: ev.i,
                name: ev.name ?? "",
                what: ev.what ?? "",
                phase: ev.phase ?? 2,
                state: ev.state ?? "pending",
                note: ev.note ?? ""
            };
        }

        for (let i = 0; i < seenTotal; i++)
            if (!rows[i])
                rows[i] = {
                    i: i,
                    name: "",
                    what: "",
                    phase: 2,
                    state: "pending",
                    note: ""
                };

        root.total = seenTotal;
        root.steps = rows;
        root.dryRun = dry;
        root.tallyDone = td;
        root.tallySkipped = ts;
        root.tallyFailed = tf;
        root.finished = fin;
    }

    FileView {
        id: logFile

        path: root.logPath
        watchChanges: true
        printErrors: false

        onFileChanged: reload()
        onLoaded: root.absorb(text())
    }

    Timer {
        interval: 200
        repeat: true
        running: !root.finished
        onTriggered: logFile.reload()
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property ShellScreen modelData

            screen: win.modelData
            color: Theme.void_

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace: "banditshell-installer"
            exclusiveZone: 0

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            Item {
                anchors.fill: parent

                Rectangle {

                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: Theme.void_
                        }
                        GradientStop {
                            position: 0.55
                            color: Qt.rgba(0.09, 0.12, 0.15, 1)
                        }
                        GradientStop {
                            position: 1
                            color: Theme.void_
                        }
                    }
                    opacity: 0.35 + 0.4 * glow.value
                }
            }

            Smooth {
                id: glow
                target: root.progress
                speed: 4
            }

            Smooth {
                id: railIn
                target: root.pieceIn("rail") ? 1 : 0
                speed: 7
            }

            Item {
                id: rail

                readonly property real fullHeight: win.height * 0.62
                readonly property real w: 64

                width: rail.w
                height: rail.fullHeight * railIn.value
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                opacity: railIn.value

                G2Rect {
                    anchors.fill: parent

                    topLeftRadius: 0
                    bottomLeftRadius: 0
                    topRightRadius: Theme.rLarge
                    bottomRightRadius: Theme.rLarge
                    color: Theme.body
                }

                Repeater {
                    model: root.total

                    delegate: Item {
                        id: pip

                        required property int index

                        readonly property var step: root.steps[pip.index] ?? null
                        readonly property string state: pip.step ? pip.step.state : "pending"

                        readonly property color tint: {
                            switch (pip.state) {
                            case "done":
                                return Theme.mid;
                            case "skip":
                                return Theme.ramp[6];
                            case "failed":
                                return Theme.alarm;
                            case "start":
                                return Theme.bright;
                            default:
                                return Theme.ramp[4];
                            }
                        }

                        y: ((pip.index + 1) / (root.total + 1)) * rail.height - height / 2
                        x: (rail.w - width) / 2
                        width: rail.w * 0.42
                        height: 10

                        Smooth {
                            id: lit

                            target: pip.state === "start" ? 1 : (pip.state === "pending" ? 0 : 0.55)
                            speed: 11
                        }

                        G2Rect {
                            anchors.centerIn: parent
                            width: parent.width * (0.55 + 0.45 * lit.value)
                            height: parent.height
                            radius: Theme.rSmall
                            color: pip.tint
                            opacity: 0.35 + 0.65 * lit.value
                        }
                    }
                }
            }

            Smooth {
                id: cornersIn
                target: root.pieceIn("corners") ? 1 : 0
                speed: 6
            }

            Repeater {
                model: [
                    {
                        h: "left",
                        v: "top"
                    },
                    {
                        h: "right",
                        v: "top"
                    },
                    {
                        h: "right",
                        v: "bottom"
                    },
                    {
                        h: "left",
                        v: "bottom"
                    }
                ]

                delegate: G2Rect {
                    id: wedge

                    required property var modelData

                    readonly property real reach: 40 * cornersIn.value

                    width: wedge.reach
                    height: wedge.reach
                    opacity: cornersIn.value
                    color: Theme.plate

                    x: wedge.modelData.h === "left" ? 0 : win.width - width
                    y: wedge.modelData.v === "top" ? 0 : win.height - height

                    topLeftRadius: (wedge.modelData.h === "right" && wedge.modelData.v === "bottom") ? -wedge.reach : 0
                    topRightRadius: (wedge.modelData.h === "left" && wedge.modelData.v === "bottom") ? -wedge.reach : 0
                    bottomRightRadius: (wedge.modelData.h === "left" && wedge.modelData.v === "top") ? -wedge.reach : 0
                    bottomLeftRadius: (wedge.modelData.h === "right" && wedge.modelData.v === "top") ? -wedge.reach : 0
                }
            }

            Smooth {
                id: notchIn
                target: root.pieceIn("notch") ? 1 : 0
                speed: 7
            }

            G2Rect {
                id: notch

                readonly property real full: 44

                width: Math.max(1, notchLabel.implicitWidth + Theme.padHuge * 2)
                height: notch.full * notchIn.value
                anchors.horizontalCenter: parent.horizontalCenter
                y: 0
                opacity: notchIn.value

                topLeftRadius: 0
                topRightRadius: 0
                bottomLeftRadius: Theme.rLarge
                bottomRightRadius: Theme.rLarge
                color: Theme.plate

                BsText {
                    id: notchLabel

                    anchors.centerIn: parent
                    text: root.dryRun ? "dry run" : (root.finished ? "installed" : "installing")
                    color: Theme.textDim

                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 3
                }
            }

            Smooth {
                id: barIn
                target: root.pieceIn("bar") ? 1 : 0
                speed: 7
            }

            G2Rect {
                id: bar

                readonly property real full: 48

                width: Math.max(1, tallies.implicitWidth + Theme.padHuge * 2)
                height: bar.full * barIn.value
                anchors.horizontalCenter: parent.horizontalCenter
                y: win.height - height
                opacity: barIn.value

                topLeftRadius: Theme.rLarge
                topRightRadius: Theme.rLarge
                bottomLeftRadius: 0
                bottomRightRadius: 0
                color: Theme.plate

                Row {
                    id: tallies

                    anchors.centerIn: parent
                    spacing: Theme.padLarge

                    Repeater {
                        model: [
                            {
                                k: "installed",
                                v: root.tallyDone,
                                c: Theme.mid
                            },
                            {
                                k: "had",
                                v: root.tallySkipped,
                                c: Theme.ramp[7]
                            },
                            {
                                k: "failed",
                                v: root.tallyFailed,
                                c: root.tallyFailed > 0 ? Theme.alarm : Theme.ramp[6]
                            }
                        ]

                        delegate: Row {
                            required property var modelData

                            spacing: Theme.padSmall

                            opacity: root.finished ? 1 : 0.25

                            BsText {
                                text: modelData.k
                                color: Theme.textFaint
                                font.capitalization: Font.AllUppercase
                                font.letterSpacing: 2
                            }

                            BsText {
                                text: String(modelData.v)
                                color: modelData.c
                            }
                        }
                    }
                }
            }

            Column {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: rail.w / 2
                spacing: Theme.padLarge

                BsText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "banditshell"
                    font.pixelSize: Theme.large
                    color: Theme.text
                }

                BsText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.dryRun ? "rehearsing the install" : "assembling"
                    color: Theme.textFaint
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 4
                }

                Item {
                    width: 1
                    height: Theme.padNormal
                }

                G2Rect {
                    id: track

                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(win.width * 0.46, 620)
                    height: 14
                    radius: Theme.rSmall
                    color: Theme.fill

                    G2Rect {

                        width: Math.max(0, track.width * fill.value)
                        height: parent.height
                        radius: Theme.rSmall
                        color: root.tallyFailed > 0 && root.finished ? Theme.alarm : Theme.mid
                    }
                }

                Smooth {
                    id: fill
                    target: root.progress
                    speed: 6
                }

                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.padSmall

                    BsText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        font.pixelSize: Theme.normal
                        color: Theme.text
                        text: {
                            if (root.finished)
                                return root.tallyFailed > 0 ? `${root.tallyFailed} did not install` : "ready";
                            if (root.current)
                                return root.current.name;
                            return "";
                        }
                    }

                    BsText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: Theme.textFaint
                        text: {
                            if (root.finished)
                                return root.tallyFailed > 0 ? "see the terminal for which" : "banditshell start";
                            if (root.current)
                                return root.current.what;
                            return "";
                        }
                    }

                    BsText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: Theme.ramp[6]
                        text: root.total > 0 ? `${root.resolved} of ${root.total}` : ""
                    }
                }
            }
        }
    }
}
