pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

Item {
    id: root

    required property ShellScreen screen

    required property real border

    required property real holeX
    required property real holeY
    required property real holeWidth
    required property real holeHeight

    property bool blocked: false

    property var fallback: null

    readonly property Item maskItem: strip

    readonly property Item grabItem: catcher

    property var held: null

    property bool lifted: false

    property bool mapped: false

    property string mode: Appearance.sizes.windowMode

    property string committed: ""

    property bool grabbed: false

    property bool forwarding: false

    property bool racked: false

    property string outro: ""

    property var rest: null
    property var dest: null

    property real originY: 0
    property real pointX: 0
    property real pointY: 0
    property real velocity: 0
    property real lastRise: 0
    property real lastEvent: 0

    property real stillX: 0
    property real stillY: 0

    function flipMode(): void {
        root.mode = root.mode === "swap" ? "move" : "swap";
    }

    onModeChanged: root.commitAim()

    readonly property real rise: root.held ? Math.max(0, root.originY - root.pointY) : 0

    readonly property real travelFull: Math.max(1, root.height * Appearance.sizes.windowTravel)
    readonly property real progress: root.held ? Math.max(0, Math.min(root.rise / root.travelFull, 1)) : 0

    readonly property bool showing: !!root.held && (root.lifted || root.outro !== "")

    readonly property real restScale: layout.mapScale
    readonly property real liveScale: 1 + (root.restScale - 1) * tuck.value

    readonly property real liveCX: root.held ? root.held.x + root.held.w / 2 + (root.pointX - root.held.x - root.held.w / 2) * tuck.value : 0
    readonly property real liveCY: root.held ? root.held.y + root.held.h - root.rise - root.held.h * root.liveScale / 2 : 0

    readonly property var home: root.held ? root.liveRect(root.held.addr) : null

    readonly property var landing: {
        if (!root.outro)
            return null;
        if ((root.outro !== "back" && root.outro !== "swapped") || !root.home || !root.held)
            return root.dest;

        return {
            cx: root.home.x + root.home.w / 2,
            cy: root.home.y + root.home.h / 2,
            k: Math.min(root.home.w / root.held.w, root.home.h / root.held.h)
        };
    }

    readonly property bool flying: !!root.outro && !!root.rest && !!root.landing

    readonly property real cardScale: root.flying ? root.blend(root.rest.k, root.landing.k, gone.value) : root.liveScale
    readonly property real cardCX: root.flying ? root.blend(root.rest.cx, root.landing.cx, gone.value) : root.liveCX
    readonly property real cardCY: root.flying ? root.blend(root.rest.cy, root.landing.cy, gone.value) : root.liveCY

    readonly property real cardW: root.held ? root.held.w * root.cardScale : 0
    readonly property real cardH: root.held ? root.held.h * root.cardScale : 0
    readonly property real cardX: root.cardCX - root.cardW / 2
    readonly property real cardY: root.cardCY - root.cardH / 2

    readonly property color body: Appearance.colour.surface

    function blend(a: real, b: real, t: real): real {
        return a + (b - a) * t;
    }

    function liveRect(addr: string): var {
        for (const client of Hypr.clientsOn(root.screen)) {
            const o = client.lastIpcObject;
            if (!o?.at || !o?.size)
                continue;

            const raw = o.address ?? "";
            if ((raw.startsWith("0x") ? raw : `0x${raw}`) !== addr)
                continue;

            return {
                x: o.at[0] - root.screen.x,
                y: o.at[1] - root.screen.y,
                w: o.size[0],
                h: o.size[1]
            };
        }

        return null;
    }

    function windowAt(x: real): var {
        const reach = root.border + Appearance.sizes.minTarget;
        let best = null;

        for (const client of Hypr.clientsOn(root.screen)) {
            const o = client.lastIpcObject;
            if (!o?.at || !o?.size)
                continue;

            const cx = o.at[0] - root.screen.x;
            const cy = o.at[1] - root.screen.y;
            if (x < cx || x > cx + o.size[0])
                continue;

            const bottom = cy + o.size[1];
            if (root.height - bottom > reach)
                continue;
            if (best && bottom <= best.y + best.h)
                continue;

            const addr = o.address ?? "";
            best = {
                addr: addr.startsWith("0x") ? addr : `0x${addr}`,

                client,
                mark: AppIcons.markFor(Hypr.classOf(client)),
                title: o.title ?? "",
                x: cx,
                y: cy,
                w: o.size[0],
                h: o.size[1]
            };
        }

        return best;
    }

    function begin(win: var, x: real, y: real): void {
        root.held = win;
        root.lifted = false;
        root.mapped = false;
        root.racked = false;
        root.committed = null;
        root.grabbed = true;
        root.outro = "";
        root.originY = y;
        root.pointX = x;
        root.pointY = y;
        root.velocity = 0;
        root.lastRise = 0;
        root.lastEvent = Date.now();

        tuck.snap();
        gone.snap();
    }

    function track(x: real, y: real): void {
        root.pointX = x;
        root.pointY = y;

        const now = Date.now();
        const dt = Math.max(1, Math.min(100, now - root.lastEvent));
        root.lastEvent = now;
        const step = root.rise - root.lastRise;
        root.lastRise = root.rise;
        root.velocity += (step / dt - root.velocity) * 0.4;

        if (!root.lifted) {

            if (root.rise < Appearance.sizes.pullSlack)
                return;

            root.lifted = true;
            root.stillX = x;
            root.stillY = y;
            hold.restart();
            return;
        }

        if (Math.hypot(x - root.stillX, y - root.stillY) > Appearance.sizes.windowHoldSlop) {
            root.stillX = x;
            root.stillY = y;
            if (!root.racked)
                hold.restart();
        }
    }

    function commitAim(): void {
        if (!root.held || !root.grabbed)
            return;

        const want = layout.over < 0 ? null : root.mode === "swap" ? {
            kind: "swap",
            addr: layout.aimAddr,
            steps: 0
        } : layout.steps === 0 ? null : {
            kind: "move",
            addr: "",
            steps: layout.steps
        };

        const now = root.committed;
        if ((now?.kind ?? "") === (want?.kind ?? "") && (now?.addr ?? "") === (want?.addr ?? "") && (now?.steps ?? 0) === (want?.steps ?? 0))
            return;

        root.undoAim();

        if (want?.kind === "swap")
            Hypr.swapWith(root.held.addr, want.addr);
        else if (want?.kind === "move")
            Hypr.walkColumn(root.held.addr, want.steps);

        root.committed = want;
    }

    function undoAim(): void {
        if (!root.committed || !root.held)
            return;

        if (root.committed.kind === "swap")
            Hypr.swapWith(root.held.addr, root.committed.addr);
        else
            Hypr.walkColumn(root.held.addr, -root.committed.steps);

        root.committed = null;
    }

    Connections {
        target: layout

        function onOverChanged(): void {
            root.commitAim();
        }
    }

    function release(): void {
        hold.stop();

        if (!root.held || !root.lifted) {

            root.clear();
            return;
        }

        if (root.velocity >= Appearance.sizes.windowFling) {

            root.undoAim();
            Hypr.closeWindow(root.held.addr);
            root.finish("close", -1);
            return;
        }

        const plate = shelf.over;
        if (plate >= 0) {
            const slot = shelf.slots[plate];

            if (slot.target === shelf.activeId)
                root.finish("back", -1);
            else {
                Hypr.sendToWorkspace(root.held.addr, slot.target, Appearance.sizes.windowFollow);
                root.finish("sent", plate);
            }
            return;
        }

        const other = layout.over;
        if (other >= 0) {
            Hypr.restoreFocus(root.held.addr);
            root.finish("swapped", other);
            return;
        }

        if (root.progress >= 1) {
            root.undoAim();
            Hypr.closeWindow(root.held.addr);
            root.finish("close", -1);
            return;
        }

        root.finish("back", -1);
    }

    function finish(how: string, index: int): void {
        root.rest = {
            cx: root.cardCX,
            cy: root.cardCY,
            k: root.cardScale
        };

        if (how === "close")
            root.dest = {
                cx: root.rest.cx,
                cy: -root.held.h * root.rest.k / 2,
                k: root.rest.k
            };
        else if (how === "sent") {
            const centre = shelf.plateCentre(index);
            root.dest = {
                cx: centre.x,
                cy: centre.y,
                k: Math.min(shelf.scaledW / root.held.w, shelf.scaledH / root.held.h)
            };
        } else if (how === "swapped") {

            const slot = layout.windows[index];
            root.dest = {
                cx: slot.x + slot.w / 2,
                cy: slot.y + slot.h / 2,
                k: Math.min(slot.w / root.held.w, slot.h / root.held.h)
            };
        } else
            root.dest = {
                cx: root.held.x + root.held.w / 2,
                cy: root.held.y + root.held.h / 2,
                k: 1
            };

        root.grabbed = false;
        root.outro = how;

        layout.landed = true;
    }

    function dissolve(): void {
        root.mapped = false;
        linger.restart();
    }

    Timer {
        id: linger

        interval: Appearance.anim.slow * 2
        onTriggered: root.clear()
    }

    function clear(): void {

        linger.stop();

        root.outro = "";
        root.held = null;
        root.lifted = false;
        root.mapped = false;
        root.racked = false;
        root.committed = null;
        root.grabbed = false;
        root.rest = null;
        root.dest = null;
        gone.snap();
        tuck.snap();
    }

    Connections {
        target: Hypr

        function onWindowClosed(addr: string): void {
            if (root.held && !root.outro && root.held.addr === addr)
                root.clear();
        }
    }

    Follow {
        id: tuck

        target: root.racked ? 1 : root.progress
        speed: Appearance.anim.resizeSpeed
        epsilon: 0.005
    }

    Follow {
        id: gone

        target: root.outro ? 1 : 0
        speed: Appearance.anim.revealSpeed
        epsilon: 0.005

        onSettledChanged: if (gone.settled && root.outro)
            Qt.callLater(root.mapped ? root.dissolve : root.clear)
    }

    readonly property real dim: mapDim.value * 0.7 + rackDim.value * 0.3

    Follow {
        id: mapDim

        target: root.mapped && !root.outro ? 1 : 0
        speed: Appearance.anim.revealSpeed
        epsilon: 0.005
    }

    Follow {
        id: rackDim

        target: root.racked ? 1 : 0
        speed: Appearance.anim.revealSpeed
        epsilon: 0.005
    }

    Timer {
        id: settle

        interval: Appearance.sizes.windowSettle
        repeat: true
        running: root.grabbed && root.lifted && !root.mapped
        onTriggered: if (root.velocity < Appearance.sizes.windowFling)
            root.mapped = true
    }

    Timer {
        id: hold

        interval: Appearance.sizes.windowHold
        onTriggered: if (root.grabbed && root.lifted)
            root.racked = true
    }

    Rectangle {
        anchors.fill: parent

        visible: root.dim > 0.01
        color: Appearance.colour.surface
        opacity: root.dim
    }

    LayoutSlots {
        id: layout

        anchors.fill: parent

        screen: root.screen
        heldAddr: root.held?.addr ?? ""

        holeX: root.holeX
        holeY: root.holeY + shelf.dockedHeight
        holeWidth: root.holeWidth
        holeHeight: root.holeHeight - shelf.dockedHeight

        mode: root.mode

        pointX: root.pointX
        pointY: root.pointY

        active: root.mapped && !shelf.armed
    }

    WorkspaceShelf {
        id: shelf

        anchors.fill: parent

        screen: root.screen.name
        holeX: root.holeX
        holeY: root.holeY
        holeWidth: root.holeWidth
        holeHeight: root.holeHeight
        aspect: root.height / root.width

        pointX: root.pointX
        pointY: root.pointY

        active: root.racked
    }

    Icon {
        id: modeMark

        visible: markFade.value > 0.01
        opacity: markFade.value

        x: root.holeX + (root.holeWidth - width) / 2
        y: root.holeY + root.holeHeight - height - Appearance.padding.large

        name: root.mode === "swap" ? "swap_horiz" : "low_priority"
        size: Appearance.sizes.launcherIcon
        color: Appearance.colour.text

        scale: root.flipped ? 1.35 : 1

        Behavior on scale {
            NumberAnimation {
                duration: Appearance.anim.fast
                easing.type: Easing.OutBack
            }
        }
    }

    Follow {
        id: markFade

        target: root.mapped && !root.outro ? 1 : 0
        speed: Appearance.anim.revealSpeed
        epsilon: 0.005
    }

    property bool flipped: false

    Timer {
        id: flip

        interval: Appearance.anim.normal
        onTriggered: root.flipped = false
    }

    SquircleRect {
        id: card

        visible: root.showing
        x: root.cardX
        y: root.cardY
        width: Math.max(0, root.cardW)
        height: Math.max(0, root.cardH)

        opacity: !root.outro ? 1 : root.outro === "close" || root.outro === "sent" ? 1 - gone.value : root.mapped ? 1 : layout.fade

        radius: Appearance.sizes.windowRadius * root.cardScale

        color: Qt.rgba(root.body.r, root.body.g, root.body.b, root.body.a * tuck.value)
        stroke: Appearance.colour.fillStronger
        strokeWidth: Appearance.font.stem

        WindowView {
            id: shot

            anchors.fill: parent

            window: root.held?.client ?? null
            radius: card.radius
            live: false
        }

        Column {
            anchors.centerIn: parent
            spacing: Appearance.padding.small

            opacity: tuck.value
            visible: opacity > 0.01 && !shot.ready

            AppMark {
                anchors.horizontalCenter: parent.horizontalCenter

                spec: root.held?.mark ?? ""
                size: Appearance.sizes.launcherIcon
                color: Appearance.colour.text
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter

                width: Math.min(implicitWidth, card.width - Appearance.padding.normal * 2)
                text: root.held?.title ?? ""
                color: Appearance.colour.textDim
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
        }
    }

    Item {
        id: catcher

        anchors.fill: parent
    }

    MultiPointTouchArea {
        id: strip

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.border + Appearance.sizes.windowGrab

        mouseEnabled: false
        minimumTouchPoints: 1
        maximumTouchPoints: 1

        enabled: Appearance.sizes.windowEdge && (!root.blocked || !!root.held)

        onPressed: points => {
            const p = points[0];
            if (!p)
                return;

            root.clear();

            const at = strip.mapToItem(root, p.x, p.y);
            const win = root.windowAt(at.x);

            if (!win) {
                root.forwarding = true;
                root.originY = at.y;
                root.fallback?.begin();
                return;
            }

            root.begin(win, at.x, at.y);
        }

        onUpdated: points => {
            const p = points[0];
            if (!p)
                return;

            const at = strip.mapToItem(root, p.x, p.y);

            if (root.forwarding) {
                root.fallback?.advance(root.originY - at.y);
                return;
            }

            if (root.held)
                root.track(at.x, at.y);
        }

        onReleased: {
            if (root.forwarding) {
                root.fallback?.settle();
                root.forwarding = false;
                return;
            }

            root.release();
        }

        onCanceled: {
            if (root.forwarding) {
                root.fallback?.settle();
                root.forwarding = false;
                return;
            }

            hold.stop();
            if (root.held && root.lifted)
                root.finish("back", -1);
            else
                root.clear();
        }
    }

    MultiPointTouchArea {
        id: second

        anchors.fill: parent

        enabled: root.mapped && root.grabbed
        mouseEnabled: false
        minimumTouchPoints: 1
        maximumTouchPoints: 1

        onPressed: {
            root.flipMode();
            root.flipped = true;
            flip.restart();
        }
    }
}
