pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

PanelWindow {
    id: win

    readonly property string output: win.screen?.name ?? ""

    readonly property real originX: win.screen?.x ?? 0
    readonly property real originY: win.screen?.y ?? 0

    readonly property bool mine: PenMap.monitorName === win.output

    readonly property bool editable: !PenMap.followWindow

    readonly property var corners: [[0, 0], [1, 0], [1, 1], [0, 1]]

    function cornerAt(i: int): var {
        const f = win.corners[i];
        const r = PenMap.region;
        return [r.x + f[0] * r.width, r.y + f[1] * r.height];
    }

    function oppositeAt(i: int): var {
        const f = win.corners[i];
        const r = PenMap.region;
        return [r.x + (1 - f[0]) * r.width, r.y + (1 - f[1]) * r.height];
    }

    function nearestCorner(gx: real, gy: real): int {
        let best = 0;
        let bestDist = Infinity;
        for (let i = 0; i < win.corners.length; i++) {
            const c = win.cornerAt(i);

            const d = (c[0] - gx) * (c[0] - gx) + (c[1] - gy) * (c[1] - gy);
            if (d < bestDist) {
                bestDist = d;
                best = i;
            }
        }
        return best;
    }

    function cornerUnder(gx: real, gy: real): int {
        const i = win.nearestCorner(gx, gy);
        const c = win.cornerAt(i);
        return Math.abs(c[0] - gx) <= win.grab && Math.abs(c[1] - gy) <= win.grab ? i : -1;
    }

    function inside(gx: real, gy: real): bool {
        const r = PenMap.region;
        return gx >= r.x && gy >= r.y && gx <= r.x + r.width && gy <= r.y + r.height;
    }

    function holds(outer: rect, inner: rect): bool {
        const slack = Appearance.sizes.pickerOutline / 2;
        return inner.x >= outer.x - slack && inner.y >= outer.y - slack && inner.x + inner.width <= outer.x + outer.width + slack && inner.y + inner.height <= outer.y + outer.height + slack;
    }

    function controlUnder(gx: real, gy: real): var {
        if (!readout.visible)
            return null;
        for (const item of readout.controls) {
            const b = readout.boxOf(item);
            if (gx >= b.x && gy >= b.y && gx <= b.x + b.width && gy <= b.y + b.height)
                return item;
        }
        return null;
    }

    readonly property real grab: Appearance.sizes.minTarget

    readonly property real handle: Appearance.sizes.minTarget / 2

    property string mode: ""
    property int grabbed: -1

    property real anchorX: 0
    property real anchorY: 0

    property real grabX: 0
    property real grabY: 0

    property rect aimed
    property string aimedName: ""

    readonly property bool aimedBound: PenMap.tracking && win.aimedName === PenMap.boundWindowName && win.holds(win.aimed, PenMap.region)

    readonly property string aimedWord: {
        if (!PenMap.tracking)
            return "bind";
        return win.aimedBound ? "bound" : "rebind";
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    exclusiveZone: 0
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "banditshell-pen"

    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    visible: PenMap.active

    mask: Region {
        width: PenMap.active ? win.width : 0
        height: PenMap.active ? win.height : 0
    }

    Connections {
        target: PenMap

        function onActiveChanged(): void {
            if (!PenMap.active)
                win.release();
        }

        function onHoveredWindowChanged(): void {
            win.hold();
        }

        function onHoveredWindowNameChanged(): void {
            win.hold();
        }
    }

    function hold(): void {
        const r = PenMap.hoveredWindow;
        if (r.width <= 0 || r.height <= 0)
            return;
        win.aimed = r;
        win.aimedName = PenMap.hoveredWindowName;
    }

    function release(): void {
        win.mode = "";
        win.grabbed = -1;
    }

    MouseArea {
        id: pen

        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true

        readonly property int hot: {
            if (win.mode === "resize")
                return win.grabbed;

            if (!pen.containsMouse || win.mode !== "" || !win.editable)
                return -1;
            return win.cornerUnder(pen.mouseX + win.originX, pen.mouseY + win.originY);
        }

        readonly property bool over: pen.containsMouse && win.inside(pen.mouseX + win.originX, pen.mouseY + win.originY)

        readonly property var overControl: pen.containsMouse && win.mode === "" && pen.hot < 0 ? win.controlUnder(pen.mouseX + win.originX, pen.mouseY + win.originY) : null

        cursorShape: {
            if (pen.hot >= 0)
                return win.corners[pen.hot][0] === win.corners[pen.hot][1] ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor;
            if (win.mode === "move")
                return Qt.ClosedHandCursor;

            if (pen.overControl)
                return Qt.PointingHandCursor;

            if (!win.editable)
                return highlight.shown && win.aimedBound ? Qt.ArrowCursor : Qt.CrossCursor;
            return pen.over ? Qt.SizeAllCursor : Qt.ArrowCursor;
        }

        function beginResize(i: int): void {
            win.mode = "resize";
            win.grabbed = i;
            const o = win.oppositeAt(i);
            win.anchorX = o[0];
            win.anchorY = o[1];
        }

        onPressed: event => {
            const gx = event.x + win.originX;
            const gy = event.y + win.originY;

            PenMap.setPointer(gx, gy);

            if (win.editable && event.button === Qt.RightButton)
                return pen.beginResize(win.nearestCorner(gx, gy));

            const corner = win.editable ? win.cornerUnder(gx, gy) : -1;
            if (corner >= 0)
                return pen.beginResize(corner);

            const control = win.controlUnder(gx, gy);
            if (control) {
                win.mode = "";
                return control.clicked();
            }

            if (win.editable && win.inside(gx, gy)) {
                win.mode = "move";
                win.grabX = gx - PenMap.region.x;
                win.grabY = gy - PenMap.region.y;
                return;
            }

            win.mode = "";
        }

        onPositionChanged: event => {
            const gx = event.x + win.originX;
            const gy = event.y + win.originY;

            PenMap.setPointer(gx, gy);

            if (win.mode === "")
                return;

            if (win.mode === "move")
                return PenMap.proposeRegion(gx - win.grabX, gy - win.grabY, PenMap.region.width, PenMap.region.height);

            PenMap.proposeRegion(Math.min(win.anchorX, gx), Math.min(win.anchorY, gy), Math.abs(gx - win.anchorX), Math.abs(gy - win.anchorY));
        }

        onReleased: win.release()

        onCanceled: win.release()
    }

    Rectangle {
        anchors.fill: parent
        visible: !win.mine
        color: Appearance.colour.scrim
    }

    StyledText {
        anchors.centerIn: parent
        visible: !win.mine
        text: `tablet mapped to ${PenMap.monitorName}`
        color: Appearance.colour.textFaint
    }

    Follow {
        id: aim

        target: highlight.shown ? 1 : 0
        speed: Appearance.anim.revealSpeed
        epsilon: 0.005
    }

    SquircleRect {
        id: highlight

        readonly property bool shown: PenMap.followWindow && PenMap.hoveredWindow.width > 0 && PenMap.hoveredWindow.height > 0

        visible: aim.value > 0
        opacity: aim.value
        x: win.aimed.x - win.originX
        y: win.aimed.y - win.originY
        width: win.aimed.width
        height: win.aimed.height
        radius: Appearance.sizes.windowRadius

        color: win.aimedBound ? Appearance.colour.fill : Appearance.colour.accentFill
        stroke: win.aimedBound ? Appearance.colour.textDim : Appearance.colour.accent
        strokeWidth: Appearance.sizes.pickerOutline

        Behavior on color {
            ColorAnimation {
                duration: Appearance.anim.normal
            }
        }

        Behavior on stroke {
            ColorAnimation {
                duration: Appearance.anim.normal
            }
        }

        Item {
            id: label

            anchors.centerIn: parent

            visible: label.implicitWidth <= highlight.width && label.implicitHeight <= highlight.height

            implicitWidth: named.implicitWidth + Appearance.padding.large * 2
            implicitHeight: named.implicitHeight + Appearance.padding.normal * 2
            width: implicitWidth
            height: implicitHeight

            SquircleRect {
                anchors.fill: parent
                radius: Appearance.rounding.normal
                color: Appearance.colour.surface
            }

            Row {
                id: named

                anchors.centerIn: parent
                spacing: Appearance.padding.large

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: `${Math.round(win.aimed.width)} x ${Math.round(win.aimed.height)}`
                    font.pixelSize: Appearance.font.size.normal
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: `${win.aimedWord} ${win.aimedName}`
                    color: Appearance.colour.textDim
                }
            }
        }
    }

    Follow {
        id: fx

        target: PenMap.region.x - win.originX
        speed: win.mine ? Appearance.anim.trackSpeed : 0
    }

    Follow {
        id: fy

        target: PenMap.region.y - win.originY
        speed: win.mine ? Appearance.anim.trackSpeed : 0
    }

    Follow {
        id: fw

        target: PenMap.region.width
        speed: win.mine ? Appearance.anim.trackSpeed : 0
    }

    Follow {
        id: fh

        target: PenMap.region.height
        speed: win.mine ? Appearance.anim.trackSpeed : 0
    }

    SquircleRect {
        id: outline

        visible: win.mine
        x: fx.value
        y: fy.value
        width: fw.value
        height: fh.value
        radius: 0
        color: "transparent"

        stroke: win.editable || PenMap.tracking ? Appearance.colour.accent : Appearance.colour.textFaint
        strokeWidth: Appearance.sizes.pickerOutline * (PenMap.tracking ? 2 : 1)

        Behavior on stroke {
            ColorAnimation {
                duration: Appearance.anim.normal
            }
        }

        Behavior on strokeWidth {
            NumberAnimation {
                duration: Appearance.anim.normal
                easing.type: Easing.OutCubic
            }
        }
    }

    Repeater {
        model: win.corners.length

        delegate: SquircleRect {
            id: grip

            required property int index
            readonly property var frac: win.corners[grip.index]
            readonly property bool live: pen.hot === grip.index

            visible: win.mine && win.editable

            x: outline.x + grip.frac[0] * outline.width - grip.width / 2
            y: outline.y + grip.frac[1] * outline.height - grip.height / 2
            width: win.handle
            height: win.handle
            radius: Appearance.rounding.small

            color: grip.live ? Appearance.colour.paper : Appearance.colour.accent

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }
    }

    Item {
        id: readout

        readonly property string words: PenMap.aspectLocked ? `aspect ${PenMap.surfaceAspect.toFixed(2)}` : "aspect free"
        readonly property string mark: PenMap.aspectLocked ? "lock" : "lock_open"

        readonly property string followWords: {
            if (!PenMap.followWindow)
                return "follow off";
            return PenMap.tracking ? `follow ${PenMap.boundWindowName || "window"}` : "follow window";
        }

        readonly property string followMark: PenMap.followWindow ? "select_window" : "select_window_off"

        readonly property string centreWords: "centre"

        readonly property string centreMark: "fit_screen"

        readonly property int followBudget: 11

        readonly property var controls: [aspect, follow, centre]

        function boxOf(item: Item): rect {
            return Qt.rect(win.originX + readout.x + row.x + item.x, win.originY + readout.y + row.y + item.y, item.width, item.height);
        }

        function span(widths: var): real {
            return widths.reduce((a, b) => a + b, 0) + Math.max(0, widths.length - 1) * row.spacing;
        }

        function paint(on: bool, hot: bool): color {
            if (hot)
                return on ? Appearance.colour.accent : Appearance.colour.fillStronger;
            return on ? Appearance.colour.accentFill : Appearance.colour.fillStrong;
        }

        readonly property real roomX: outline.width - Appearance.padding.normal * 2
        readonly property real roomY: outline.height - Appearance.padding.normal * 2

        readonly property real chrome: Appearance.padding.large * 2

        readonly property real markWidth: measure.implicitHeight

        readonly property bool full: readout.span([pixels.implicitWidth, monitor.implicitWidth, measure.implicitWidth, followMeasure.implicitWidth, centreMeasure.implicitWidth]) + readout.chrome <= readout.roomX
        readonly property bool wordy: readout.span([measure.implicitWidth, followMeasure.implicitWidth, centreMeasure.implicitWidth]) + readout.chrome <= readout.roomX

        readonly property bool fits: readout.span(readout.controls.map(() => readout.markWidth)) + readout.chrome <= readout.roomX && readout.implicitHeight <= readout.roomY

        visible: win.mine && readout.fits

        x: outline.x + (outline.width - readout.width) / 2
        y: outline.y + outline.height - readout.height - Appearance.padding.normal

        implicitWidth: row.implicitWidth + readout.chrome
        implicitHeight: row.implicitHeight + Appearance.padding.normal * 2
        width: implicitWidth
        height: implicitHeight

        Button {
            id: measure

            visible: false
            interactive: false
            text: readout.words
            icon: readout.mark
        }

        Button {
            id: followMeasure

            visible: false
            interactive: false

            text: `follow ${"M".repeat(readout.followBudget)}`
            icon: readout.followMark
        }

        Button {
            id: centreMeasure

            visible: false
            interactive: false

            text: readout.centreWords
            icon: readout.centreMark
        }

        SquircleRect {
            anchors.fill: parent
            radius: Appearance.rounding.normal
            color: Appearance.colour.surface
        }

        Row {
            id: row

            anchors.centerIn: parent
            spacing: Appearance.padding.large

            StyledText {
                id: pixels

                anchors.verticalCenter: parent.verticalCenter
                visible: readout.full
                text: `${Math.round(PenMap.region.width)} x ${Math.round(PenMap.region.height)}`
                font.pixelSize: Appearance.font.size.normal
            }

            StyledText {
                id: monitor

                anchors.verticalCenter: parent.verticalCenter
                visible: readout.full
                text: PenMap.monitorName
                color: Appearance.colour.textDim
            }

            Button {
                id: aspect

                anchors.verticalCenter: parent.verticalCenter
                interactive: false
                text: readout.wordy ? readout.words : ""
                icon: readout.mark

                iconFill: PenMap.aspectLocked ? 1 : 0

                paint: readout.paint(PenMap.aspectLocked, pen.overControl === aspect)
                onClicked: PenMap.toggleAspect()
            }

            Button {
                id: follow

                anchors.verticalCenter: parent.verticalCenter
                interactive: false
                text: readout.wordy ? readout.followWords : ""

                width: Math.min(follow.implicitWidth, followMeasure.implicitWidth)
                icon: readout.followMark

                iconFill: PenMap.tracking ? 1 : 0
                paint: readout.paint(PenMap.followWindow, pen.overControl === follow)
                onClicked: PenMap.toggleFollowWindow()
            }

            Button {
                id: centre

                anchors.verticalCenter: parent.verticalCenter
                interactive: false
                text: readout.wordy ? readout.centreWords : ""
                icon: readout.centreMark
                paint: readout.paint(false, pen.overControl === centre)
                onClicked: PenMap.fitAndCentre()
            }
        }
    }
}
