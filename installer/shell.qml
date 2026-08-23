//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "theme.js" as Theme

// The installer's face: banditshell assembling itself out of the download.
//
// This runs BEFORE the shell it is installing exists, so it imports nothing from
// qs.modules, qs.services or qs.components. Everything it needs is either in this
// directory or copied into it. That constraint is the whole reason the directory
// looks slightly redundant next to components/: it has to be able to run on a
// machine where components/ has no dependencies to run against.
//
// What it draws is not decoration. install.sh works through a table of
// dependencies and appends one json object per event to a file; this reads that
// file and gives each dependency a piece of the shell's own chassis. The rail
// grows, its pips light one per dependency, the corners sweep into the screen
// edges, the notch drops out of the top and the bar rises out of the bottom. By
// the last package the progress display has turned into the thing that was being
// installed, which is the only joke this program tells.
//
// It is also entirely optional. install.sh checks that this came up and falls
// back to a terminal bar if it did not, so nothing here can stop a machine
// getting its dependencies.
ShellRoot {
    id: root

    // ---------------------------------------------------------------- data --

    // Every step the run will take, in table order, each carrying the last state
    // seen for it. Rebuilt wholesale on every read rather than patched in place:
    // the file is a few hundred bytes and a whole-array assignment is the one
    // shape QML reliably notices.
    property var steps: []
    property int total: 0
    property bool finished: false
    property bool dryRun: false
    property int tallyDone: 0
    property int tallySkipped: 0
    property int tallyFailed: 0

    // How far through the table the run is: every step that has reached a
    // terminal state, whether it installed something or found it already there.
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

    // -- THE CHASSIS, and when each piece of it arrives ----------------------
    //
    // Four pieces, and the schedule is computed from how many there are rather
    // than written down as four percentages. Piece k lands at (k + 1) / (P + 1),
    // which spreads them evenly through the run and leaves room at both ends: the
    // first piece is not already there when the first package starts, and the
    // last one still has some run left after it. Add a fifth piece to the list
    // and the other four re-space themselves.
    // See ~/.claude/rules/math-over-hardcoding.md.
    readonly property var pieces: ["rail", "corners", "notch", "bar"]

    function pieceDue(k: int): real {
        return (k + 1) / (root.pieces.length + 1);
    }

    function pieceIn(name: string): bool {
        const k = root.pieces.indexOf(name);
        return k >= 0 && root.progress >= root.pieceDue(k);
    }

    // ------------------------------------------------------------- the log --

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
                // A half written last line is normal: the file is being appended
                // to while this reads it. Skip it; the next read gets it whole.
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

        // Steps the log has not mentioned yet still occupy a slot, so the rail
        // has its full height from the first frame and nothing jumps when a late
        // step first appears.
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

    // The watch is inotify and the file is being appended to in bursts by a shell
    // script. A slow poll beside it costs nothing on a file this size and means a
    // missed notification shows up a fifth of a second later rather than never.
    Timer {
        interval: 200
        repeat: true
        running: !root.finished
        onTriggered: logFile.reload()
    }

    // --------------------------------------------------------- the surfaces --

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property ShellScreen modelData

            screen: win.modelData
            color: Theme.void_

            // Over everything, reserving nothing, and taking no keyboard. A
            // progress display that stole the keyboard from the terminal running
            // the install would be a hard thing to explain.
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

            // -- the ground it all sits on ------------------------------------
            //
            // A wash toward the accent behind the middle of the screen, so the
            // void is not a flat black rectangle. It brightens as the run
            // advances, which is the one thing on screen that moves continuously
            // rather than in steps.
            Item {
                anchors.fill: parent

                Rectangle {
                    // A true 90 degree corner: this is the full bleed ground, it
                    // has no rounded corner to get wrong. Every SHAPE in this
                    // file goes through G2Rect.
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

            // -- the rail ------------------------------------------------------
            //
            // The first piece to arrive, and the one that carries the data: one
            // pip per dependency, placed by the formula rather than by a list of
            // positions, so the column re-spaces itself when the table changes
            // length.
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
                    // Square where it meets the screen edge, curved where it
                    // faces the room: the shape a panel makes against an edge.
                    topLeftRadius: 0
                    bottomLeftRadius: 0
                    topRightRadius: Theme.rLarge
                    bottomRightRadius: Theme.rLarge
                    color: Theme.body
                }

                // One pip per step. Position is ((i + 1) / (N + 1)) of the
                // column's height: evenly distributed, no slot anywhere in the
                // source, correct for any N.
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

                        // THE FORMULA. Nothing here knows what N is.
                        y: ((pip.index + 1) / (root.total + 1)) * rail.height - height / 2
                        x: (rail.w - width) / 2
                        width: rail.w * 0.42
                        height: 10

                        Smooth {
                            id: lit
                            // A step in flight is wider and brighter than one
                            // that is merely finished: the eye should be able to
                            // find the live one without reading anything.
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

            // -- the corners ---------------------------------------------------
            //
            // Concave, which is what a negative radius means to G2Rect: the side
            // pulls in and flares back out to the bounding box tangent to the
            // perpendicular edge, so the corner sweeps into the screen edge
            // instead of stopping short of it. Four of them, generated, because
            // four hand-placed corners is four chances to get one wrong.
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

                    // The one corner that faces INTO the screen is the concave
                    // one; the three that sit on the edges are square, because
                    // they are the edges.
                    topLeftRadius: (wedge.modelData.h === "right" && wedge.modelData.v === "bottom") ? -wedge.reach : 0
                    topRightRadius: (wedge.modelData.h === "left" && wedge.modelData.v === "bottom") ? -wedge.reach : 0
                    bottomRightRadius: (wedge.modelData.h === "left" && wedge.modelData.v === "top") ? -wedge.reach : 0
                    bottomLeftRadius: (wedge.modelData.h === "right" && wedge.modelData.v === "top") ? -wedge.reach : 0
                }
            }

            // -- the notch -----------------------------------------------------
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
                    // Uppercase and tracked out, which is how a label says it is a
                    // label without asking for a size of its own.
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 3
                }
            }

            // -- the bar -------------------------------------------------------
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
                            // Only worth showing once there are numbers to show.
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

            // -- the middle: what is actually happening ------------------------
            Column {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: rail.w / 2
                spacing: Theme.padLarge

                // The name, in the one large size the whole surface gets.
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

                // -- the meter --------------------------------------------------
                G2Rect {
                    id: track

                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(win.width * 0.46, 620)
                    height: 14
                    radius: Theme.rSmall
                    color: Theme.fill

                    G2Rect {
                        // Exponentially smoothed, so the fill glides between
                        // packages instead of stepping. The corner stays a
                        // squircle at every width because the primitive clamps
                        // the radius to what the box can spend.
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

                // -- the caption ------------------------------------------------
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
