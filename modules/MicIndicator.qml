import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

Item {
    id: root

    property int border: Appearance.sizes.border

    property string socketPath: Quickshell.env("HOME") + "/.local/share/gvoice/events.sock"

    property string phase: "idle"
    property real level: 0

    property string lang: "auto"

    readonly property string langTag: root.lang === "auto" ? ""
        : root.lang.startsWith("en") ? "EN"
        : root.lang.startsWith("da") ? "DK"
        : root.lang.startsWith("ja") ? "JP"
        : root.lang.split(/[-_]/)[0].toUpperCase()

    readonly property var host: QsWindow.window?.screen ?? null

    readonly property var stage: Quickshell.screens.find(s => s.name === Hypr.focusedScreen) ?? root.host

    readonly property bool mine: !root.host || !Hypr.focusedScreen || root.host.name === Hypr.focusedScreen

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

    readonly property bool floating: StreamState.enabled

    readonly property real lift: root.floating ? Appearance.padding.large : 0

    readonly property int barCount: root.floating ? 29 : 45
    readonly property real barWidth: Math.max(2, Math.round(Appearance.font.size.small / 6))
    readonly property real barGap: root.barWidth
    readonly property real barMax: root.floating ? Appearance.font.size.large : Appearance.font.size.large * 1.6
    readonly property real barMin: root.barWidth
    readonly property real barsWidth: root.barCount * root.barWidth + (root.barCount - 1) * root.barGap

    readonly property real tagWidth: root.langTag ? tagText.width + Appearance.padding.small : 0

    readonly property real wellPad: root.floating ? Appearance.padding.small : Appearance.padding.normal
    readonly property real contentWidth: root.tagWidth + root.barsWidth + root.wellPad * 2
    readonly property real contentHeight: root.barMax + root.wellPad * 2

    readonly property real rim: Appearance.padding.small

    readonly property real cornerPower: root.floating ? 2 : Appearance.rounding.power
    readonly property real pillRadius: root.floating ? root.pillHeight / 2 : Appearance.rounding.large

    readonly property real wellRadius: root.floating ? root.contentHeight / 2 : Math.max(0, root.pillRadius - root.rim * Math.pow(2, 1 / root.cornerPower) / Math.SQRT2)
    readonly property real pillWidth: root.contentWidth + root.rim * 2
    readonly property real pillHeight: (root.floating ? 0 : root.border) + root.contentHeight + root.rim * 2

    readonly property real lip: Appearance.padding.small
    readonly property real tuckedY: (root.floating ? 0 : root.border) + root.lip - root.pillHeight

    readonly property real pillY: root.lift - (root.pillHeight + root.lift + Appearance.sizes.melt) * (1 - drop.value) - (root.lift - root.tuckedY) * tuck.value

    readonly property real reach: Appearance.padding.large

    property bool near: false

    readonly property bool watching: root.mine && root.out && Hypr.requestSocket !== ""

    readonly property var blobs: !root.floating && drop.value > 0.001 && root.here ? [
        {
            x: root.axis - root.pillWidth / 2,
            y: root.pillY,
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

    function judge(x: real, y: real): void {
        const top = (root.host?.y ?? 0) + root.y;
        root.near = Math.abs(x - slide.value) <= root.pillWidth / 2 + root.reach && y >= top && y <= top + root.lift + root.pillHeight + root.reach;
    }

    onWatchingChanged: if (!root.watching)
        root.near = false

    onBarCountChanged: root.resetHistory()

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

    Socket {
        id: pointer

        property string reply: ""

        path: Hypr.requestSocket

        onConnectedChanged: {
            if (!pointer.connected)
                return;
            pointer.reply = "";
            pointer.write("j/cursorpos");
            pointer.flush();
        }

        parser: SplitParser {
            splitMarker: ""
            onRead: data => {
                pointer.reply += data;
                let pos;
                try {
                    pos = JSON.parse(pointer.reply);
                } catch (e) {
                    return;
                }
                pointer.connected = false;
                if (typeof pos.x === "number" && typeof pos.y === "number")
                    root.judge(pos.x, pos.y);
            }
        }
    }

    Timer {
        interval: 80
        repeat: true
        running: root.watching
        onTriggered: if (!pointer.connected)
            pointer.connected = true
    }

    Follow {
        id: drop

        speed: Appearance.anim.revealSpeed
        target: root.out ? 1 : 0
        epsilon: 0.005
    }

    Follow {
        id: tuck

        speed: Appearance.anim.revealSpeed
        target: root.near ? 1 : 0
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

    PanelWindow {
        screen: root.host
        visible: drop.value > 0.001 && root.here

        anchors {
            top: true
            left: true
            right: true
        }

        implicitHeight: Math.ceil(root.y + root.lift + root.pillHeight + Appearance.sizes.melt)
        color: "transparent"
        exclusiveZone: 0

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "banditshell-dictation"

        mask: Region {}

        Item {
            y: root.y
            width: parent.width
            height: parent.height - root.y

            SquircleRect {
                visible: root.floating
                x: root.axis - width / 2
                y: root.pillY
                width: root.pillWidth
                height: root.pillHeight
                radius: root.pillRadius
                cornerPower: root.cornerPower
                color: Appearance.colour.surface
                stroke: Appearance.colour.seam
                strokeWidth: Appearance.font.stem
            }

            SquircleRect {
                x: root.axis - width / 2
                y: root.pillY + root.pillHeight - height - root.rim
                width: root.contentWidth
                height: root.contentHeight
                radius: root.wellRadius
                cornerPower: root.cornerPower
                color: Appearance.colour.fillStronger
                opacity: drop.value * (1 - tuck.value)

                Row {
                    anchors.centerIn: parent
                    spacing: Appearance.padding.small

                    StyledText {
                        id: tagText

                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: tagText.inkOffsetY
                        visible: root.langTag !== ""
                        width: tagText.inkWidth
                        alignInk: true
                        text: root.langTag
                        color: Appearance.colour.textFaint
                        font.letterSpacing: Appearance.font.stem
                    }

                    Row {
                        height: root.barMax
                        spacing: root.barGap

                        Repeater {
                            model: root.barCount

                            Rectangle {
                                required property int index

                                readonly property real fraction: {
                                    root.history
                                    root.phase
                                    flow.t
                                    fill.value
                                    writer.position
                                    root.barFraction(index)
                                }

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
    }
}
