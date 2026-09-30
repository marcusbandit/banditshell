import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.services

Item {
    id: root

    property int border: Appearance.sizes.border

    readonly property string socketPath: Quickshell.env("HOME") + "/.local/share/gvoice/events.sock"

    property string phase: "idle"
    property real level: 0

    property string lang: "auto"

    readonly property string langTag: root.lang === "auto" ? ""
        : root.lang.startsWith("en") ? "EN"
        : root.lang.startsWith("da") ? "DK"
        : root.lang.startsWith("ja") ? "JP"
        : root.lang.split("-")[0].toUpperCase()

    readonly property var host: QsWindow.window?.screen ?? null

    readonly property var stage: Quickshell.screens.find(s => s.name === Hypr.focusedScreen) ?? root.host

    readonly property real centre: {
        const box = Hypr.activeClient?.lastIpcObject;
        if (box?.at && box?.size)
            return box.at[0] + box.size[0] / 2;
        return root.stage ? root.stage.x + root.stage.width / 2 : 0;
    }

    readonly property real margin: root.pillWidth / 2 + root.border + Appearance.padding.large
    readonly property real anchor: {
        if (!root.stage)
            return root.centre;
        const lo = root.stage.x + root.margin;
        const hi = root.stage.x + root.stage.width - root.margin;
        return hi < lo ? root.stage.x + root.stage.width / 2 : Math.max(lo, Math.min(hi, root.centre));
    }

    readonly property real axis: slide.value - (root.host?.x ?? 0)

    readonly property bool here: root.axis + root.pillWidth / 2 > -Appearance.sizes.melt && root.axis - root.pillWidth / 2 < root.width + Appearance.sizes.melt

    readonly property bool out: root.phase !== "idle"

    property var history: []

    readonly property int barCount: 45
    readonly property real barWidth: Math.max(2, Math.round(Appearance.font.size.small / 6))
    readonly property real barGap: root.barWidth
    readonly property real barMax: Appearance.font.size.large * 1.6
    readonly property real barMin: root.barWidth
    readonly property real barsWidth: root.barCount * root.barWidth + (root.barCount - 1) * root.barGap

    readonly property real wellPad: Appearance.padding.normal
    readonly property real contentWidth: root.barsWidth + root.wellPad * 2
    readonly property real contentHeight: root.barMax + root.wellPad * 2

    readonly property real rim: Appearance.padding.small

    readonly property real cornerPower: Appearance.rounding.power
    readonly property real pillRadius: Appearance.rounding.large

    readonly property real wellRadius: Math.max(0, root.pillRadius - root.rim * Math.pow(2, 1 / root.cornerPower) / Math.SQRT2)
    readonly property real pillWidth: root.contentWidth + root.rim * 2
    readonly property real pillHeight: root.border + root.contentHeight + root.rim * 2

    readonly property var blobs: drop.value > 0.001 && root.here ? [
        {
            x: root.axis - root.pillWidth / 2,
            y: -(root.pillHeight + Appearance.sizes.melt) * (1 - drop.value),
            w: root.pillWidth,
            h: root.pillHeight,
            radius: root.pillRadius,

            smooth: Math.min(Appearance.sizes.melt, (root.pillHeight - root.border) / 3)
        }
    ] : []

    function resetHistory(): void {
        const blank = [];
        for (let i = 0; i < root.barCount; i++)
            blank.push(0);
        root.history = blank;
    }

    function pushLevel(v: real): void {
        const next = root.history.slice(1);
        next.push(v);
        root.history = next;
    }

    function barFraction(i: int): real {
        if (root.phase === "listening")
            return root.history[i] ?? 0;

        if (root.phase === "processing") {

            const p = i / (root.barCount - 1);
            const t = flow.t;
            const wave = 0.30 * Math.sin(2 * Math.PI * (1.3 * p - t))
                       + 0.17 * Math.sin(2 * Math.PI * (2.7 * p + t) + 1.1)
                       + 0.09 * Math.sin(2 * Math.PI * (4.1 * p - 2 * t) + 2.3);

            const swell = 0.46 + 0.10 * Math.sin(2 * Math.PI * t);

            return Math.min(1, Math.max(0.04, (swell + wave) * fill.value));
        }

        const caret = writer.position * (root.barCount - 1);
        if (i > caret + 0.5)
            return 0.05;
        if (i > caret - 0.9)
            return 1;
        return 0.34;
    }

    onPhaseChanged: {
        if (root.phase !== "listening")
            return;
        root.resetHistory();

        if (root.mine)
            Hypr.resync();
    }

    onOutChanged: {
        if (root.out)
            slide.snap();
    }

    onAnchorChanged: {
        if (drop.value < 0.05)
            slide.snap();
    }

    Component.onCompleted: {
        root.resetHistory();
        slide.snap();
    }

    Follow {
        id: slide

        target: root.anchor
        speed: Appearance.anim.trackSpeed / 2
    }

    Loader {
        id: events

        active: true
        sourceComponent: eventSocket

        readonly property bool up: item?.connected ?? false

        onUpChanged: {
            if (!up) {

                root.phase = "idle";
                root.resetHistory();
            }
        }
    }

    Component {
        id: eventSocket

        Socket {
            path: root.socketPath
            connected: true

            parser: SplitParser {
                splitMarker: "\n"
                onRead: line => {
                    let msg;
                    try {
                        msg = JSON.parse(line);
                    } catch (e) {
                        return;
                    }
                    if (msg.phase !== undefined)
                        root.phase = msg.phase;
                    if (msg.lang !== undefined)
                        root.lang = msg.lang;
                    if (msg.level !== undefined) {
                        root.level = msg.level;
                        if (root.phase === "listening")
                            root.pushLevel(msg.level);
                    }
                }
            }
        }
    }

    Timer {
        interval: 2000
        running: !events.up
        repeat: true
        onTriggered: {
            events.active = false;
            events.active = true;
        }
    }

    Follow {
        id: drop

        speed: Appearance.anim.revealSpeed
        target: root.out ? 1 : 0
        epsilon: 0.005
    }

    QtObject {
        id: flow

        property real t: 0
    }

    NumberAnimation {
        target: flow
        property: "t"
        running: root.phase === "processing"
        from: 0
        to: 1

        duration: Appearance.anim.slow * 9
        loops: Animation.Infinite
    }

    Follow {
        id: fill

        speed: Appearance.anim.resizeSpeed
        target: root.phase === "processing" ? 1 : 0
        epsilon: 0.004
    }

    QtObject {
        id: writer

        property real position: 0
    }

    NumberAnimation {
        target: writer
        property: "position"
        running: root.phase === "typing"
        from: 0
        to: 1

        duration: Appearance.anim.slow * 2
        loops: Animation.Infinite
    }

    Item {
        id: content

        x: root.axis - width / 2
        visible: root.here
        width: root.contentWidth
        height: root.contentHeight
        y: root.pillHeight - (root.pillHeight + Appearance.sizes.melt) * (1 - drop.value) - height - root.rim
        opacity: drop.value

        G2Rect {
            anchors.fill: parent
            radius: root.wellRadius
            cornerPower: root.cornerPower
            color: Appearance.colour.fillStronger

            StyledText {
                anchors.centerIn: parent
                visible: root.here && root.langTag !== ""
                text: root.langTag
                color: Appearance.colour.textFaint
            }

            Row {
                anchors.centerIn: parent

                height: root.barMax
                spacing: root.barGap

                Repeater {
                    model: root.barCount

                    Rectangle {
                        required property int index

                        readonly property real fraction: (root.history, root.phase, flow.t, fill.value, writer.position, root.barFraction(index))

                        readonly property bool liquid: root.phase === "processing"

                        width: root.barWidth
                        height: root.barMin + (root.barMax - root.barMin) * fraction
                        radius: width / 2
                        color: Appearance.colour.accent

                        y: liquid ? parent.height - height : (parent.height - height) / 2
                    }
                }
            }
        }
    }
}
