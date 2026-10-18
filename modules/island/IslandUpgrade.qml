pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root

    property bool watched: false
    property real maxHeight: 0
    readonly property real span: 1.5

    signal hide
    signal act(var notice)
    signal open(string key)

    readonly property real pad: Appearance.padding.card
    readonly property real topInset: Appearance.padding.large
    readonly property real gap: Appearance.padding.normal

    readonly property string result: SystemUpgrade.state
    readonly property bool running: SystemUpgrade.running
    readonly property bool failed: root.result === "failed"
    readonly property bool cancelled: root.result === "cancelled"
    readonly property bool restarting: SystemUpgrade.good && Pacman.restartNeeded

    readonly property color tone: root.failed ? Appearance.colour.alarm : root.cancelled ? Appearance.colour.textDim : Appearance.colour.accent

    readonly property string subtitle: {
        const parts = [];
        if (SystemUpgrade.kernelTo)
            parts.push(`Linux ${SystemUpgrade.kernelTo}`);
        const count = SystemUpgrade.total || SystemUpgrade.expected;
        if (count > 0)
            parts.push(`${count} package${count === 1 ? "" : "s"}`);
        if (SystemUpgrade.downloadSize)
            parts.push(SystemUpgrade.downloadSize);
        return parts.join(" · ");
    }

    readonly property string summary: {
        if (root.running)
            return SystemUpgrade.cancelling ? "Stopping before anything is installed" : SystemUpgrade.detail;
        switch (root.result) {
        case "done":
            return root.restarting ? `Restart to start using Linux ${SystemUpgrade.kernelTo || Pacman.pretty(Pacman.installed)}.` : `${SystemUpgrade.total} package${SystemUpgrade.total === 1 ? "" : "s"} updated.`;
        case "current":
            return "Nothing needed updating.";
        }
        return SystemUpgrade.reason;
    }

    readonly property var messages: {
        const out = [];
        if (!root.running && SystemUpgrade.good)
            for (const e of SystemUpgrade.errors.slice(-2))
                out.push({
                    text: e.charAt(0).toUpperCase() + e.slice(1),
                    tone: Appearance.colour.alarm
                });
        const notes = SystemUpgrade.warnings;
        for (const w of notes.slice(-3))
            out.push({
                text: w.charAt(0).toUpperCase() + w.slice(1),
                tone: Appearance.colour.textDim
            });
        if (notes.length > 3)
            out.push({
                text: `and ${notes.length - 3} more in the log`,
                tone: Appearance.colour.textFaint
            });
        return out;
    }

    readonly property bool asking: root.running && SystemUpgrade.asking && SystemUpgrade.question?.text !== "Proceed with installation?"

    implicitHeight: root.topInset + column.implicitHeight + root.pad

    Column {
        id: column

        x: root.pad
        y: root.topInset
        width: root.width - root.pad * 2
        spacing: Appearance.padding.card

        Item {
            width: parent.width
            height: Math.max(badge.height, titles.implicitHeight)

            Item {
                id: badge

                readonly property real size: Appearance.font.line.large + Appearance.padding.small * 2

                width: badge.size
                height: badge.size
                anchors.verticalCenter: parent.verticalCenter

                ProgressRing {
                    anchors.fill: parent
                    visible: root.running
                    size: badge.size
                    value: ringFill.value
                    colour: root.tone
                }

                Icon {
                    anchors.centerIn: parent
                    name: root.running ? (root.asking ? "help" : "download") : SystemUpgrade.good ? "check_circle" : root.failed ? "error" : "cancel"
                    size: root.running ? Math.round(badge.size * 0.5) : badge.size
                    fill: 1
                    color: root.tone
                }

                Follow {
                    id: ringFill

                    speed: Appearance.animation.revealSpeed
                    epsilon: 0.001
                    target: SystemUpgrade.progress
                }
            }

            Column {
                id: titles

                anchors.left: badge.right
                anchors.leftMargin: root.gap
                anchors.right: root.running ? percent.left : parent.right
                anchors.rightMargin: root.running ? root.gap : 0
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                StyledText {
                    width: parent.width
                    text: SystemUpgrade.headline
                    font.pixelSize: Appearance.font.size.large
                    elide: Text.ElideRight
                }

                StyledText {
                    width: parent.width
                    visible: !!root.subtitle
                    text: root.subtitle
                    color: Appearance.colour.textDim
                    elide: Text.ElideRight
                }
            }

            StyledText {
                id: percent

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: root.running
                text: `${Math.round(ringFill.value * 100)}%`
                font.pixelSize: Appearance.font.size.normal
                color: root.tone
            }
        }

        Column {
            width: parent.width
            spacing: Appearance.padding.small

            Row {
                id: track

                readonly property real thickness: Math.max(4, Math.round(Appearance.padding.small * 0.75))
                readonly property real segment: (track.width - track.spacing * (SystemUpgrade.stageNames.length - 1)) / SystemUpgrade.stageNames.length

                width: parent.width
                spacing: Math.max(2, Math.round(Appearance.padding.small / 2))

                Repeater {
                    model: SystemUpgrade.stageNames

                    Item {
                        id: piece

                        required property int index

                        readonly property real fill: SystemUpgrade.fills[piece.index] ?? 0

                        width: track.segment
                        height: track.thickness

                        Follow {
                            id: grown

                            speed: Appearance.animation.revealSpeed
                            epsilon: 0.001
                            target: piece.fill
                        }

                        SquircleRect {
                            anchors.fill: parent
                            pill: "place"
                            color: Appearance.colour.fillStrong
                        }

                        SquircleRect {
                            width: piece.height + (piece.width - piece.height) * grown.value
                            height: piece.height
                            pill: "place"
                            color: root.tone
                            opacity: Math.min(1, grown.value * 20)
                            visible: opacity > 0.01
                        }
                    }
                }
            }

            Row {
                width: parent.width
                spacing: track.spacing

                Repeater {
                    model: SystemUpgrade.stageNames

                    StyledText {
                        required property int index
                        required property string modelData

                        readonly property bool current: root.running && SystemUpgrade.stage === index

                        width: track.segment
                        text: modelData
                        color: current ? Appearance.colour.text : (SystemUpgrade.fills[index] ?? 0) >= 1 ? Appearance.colour.textDim : Appearance.colour.textFaint
                        elide: Text.ElideRight
                    }
                }
            }
        }

        StyledText {
            width: parent.width
            visible: !!root.summary
            text: root.summary
            color: root.failed ? Appearance.colour.alarm : Appearance.colour.textDim
            wrapMode: root.running ? Text.NoWrap : Text.Wrap
            elide: root.running ? Text.ElideMiddle : Text.ElideNone
            maximumLineCount: 3
        }

        SquircleRect {
            id: plate

            width: parent.width
            height: ask.implicitHeight + Appearance.padding.card * 2
            visible: root.asking
            radius: Appearance.rounding.normal
            color: Appearance.colour.fill

            Column {
                id: ask

                x: Appearance.padding.card
                y: Appearance.padding.card
                width: plate.width - Appearance.padding.card * 2
                spacing: Appearance.padding.normal

                StyledText {
                    width: parent.width
                    text: SystemUpgrade.question?.text ?? ""
                    font.pixelSize: Appearance.font.size.normal
                    wrapMode: Text.Wrap
                }

                Flow {
                    width: parent.width
                    spacing: Appearance.padding.small

                    Repeater {
                        model: {
                            const q = SystemUpgrade.question;
                            if (!q)
                                return [];
                            if (q.kind === "number")
                                return q.choices.map(c => ({
                                            text: c.name,
                                            answer: `${c.number}`,
                                            primary: c.number === q.fallback
                                        }));
                            return [
                                {
                                    text: "Yes",
                                    answer: "y",
                                    primary: q.yes
                                },
                                {
                                    text: "No",
                                    answer: "n",
                                    primary: !q.yes
                                }
                            ];
                        }

                        Button {
                            required property var modelData

                            text: modelData.text
                            style: modelData.primary ? "accent" : "plate"
                            onClicked: SystemUpgrade.answer(modelData.answer)
                        }
                    }
                }
            }
        }

        Column {
            width: parent.width
            spacing: Appearance.padding.small / 2
            visible: root.messages.length > 0

            Repeater {
                model: root.messages

                StyledText {
                    required property var modelData

                    width: parent.width
                    text: modelData.text
                    color: modelData.tone
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }
        }

        Item {
            id: actions

            readonly property bool stacked: lead.implicitWidth + tail.implicitWidth + Appearance.padding.normal > actions.width

            width: parent.width
            height: actions.stacked ? lead.implicitHeight + Appearance.padding.small + tail.implicitHeight : Math.max(lead.implicitHeight, tail.implicitHeight)

            Row {
                id: lead

                spacing: Appearance.padding.small

                Button {
                    visible: root.running
                    text: SystemUpgrade.cancelling ? "Stopping" : "Cancel"
                    icon: "close"
                    style: "plate"
                    alarm: SystemUpgrade.cancellable
                    interactive: SystemUpgrade.cancellable && !SystemUpgrade.cancelling
                    onClicked: SystemUpgrade.cancel()
                }

                Button {
                    visible: root.restarting
                    text: "Restart"
                    icon: "restart_alt"
                    style: "accent"
                    onClicked: root.act({
                        kind: "restart",
                        mock: SystemUpgrade.mocked
                    })
                }

                Button {
                    visible: root.failed || root.cancelled
                    text: "Try again"
                    icon: "refresh"
                    style: root.cancelled ? "plate" : "accent"
                    onClicked: SystemUpgrade.start()
                }

                Button {
                    visible: root.failed
                    text: "Run in a terminal"
                    style: "plate"
                    onClicked: {
                        SystemUpgrade.runInTerminal();
                        root.hide();
                    }
                }
            }

            Row {
                id: tail

                anchors.right: parent.right
                y: actions.stacked ? lead.implicitHeight + Appearance.padding.small : 0
                spacing: Appearance.padding.small

                Button {
                    text: root.running ? "Watch in terminal" : "Log"
                    icon: "terminal"
                    style: "bare"
                    onClicked: SystemUpgrade.openTerminal()
                }

                Button {
                    text: root.running ? "Hide" : "Close"
                    style: "plate"
                    onClicked: {
                        if (!root.running)
                            SystemUpgrade.acknowledge();
                        root.hide();
                    }
                }
            }
        }

        StyledText {
            width: parent.width
            visible: root.running && !SystemUpgrade.cancellable && SystemUpgrade.phase !== "auth"
            text: "It cannot be stopped safely from here. Hiding this leaves it running."
            color: Appearance.colour.textFaint
            wrapMode: Text.Wrap
        }
    }
}
