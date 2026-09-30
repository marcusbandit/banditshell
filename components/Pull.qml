import QtQuick
import qs.config

MouseArea {
    id: root

    required property real dirX
    required property real dirY

    required property real travel

    property bool armed: true

    signal pulled(real fraction)

    signal finished(bool open)

    signal tapped

    readonly property real slack: Appearance.sizes.pullSlack

    readonly property real travelFull: Math.max(1, root.travel)

    property real angle: Appearance.sizes.pullAngleCorner

    readonly property real cosLimit: Math.cos(root.angle * Math.PI / 180)

    readonly property real dirLen: Math.max(0.0001, Math.hypot(root.dirX, root.dirY))
    readonly property real ux: root.dirX / root.dirLen
    readonly property real uy: root.dirY / root.dirLen

    property real fromX: 0
    property real fromY: 0
    property bool pulling: false
    property bool spent: false
    property real velocity: 0
    property real lastProj: 0

    property real lastEvent: 0
    property real progress: 0

    preventStealing: true

    function begin(): void {
        root.pulling = false;
        root.spent = false;
        root.velocity = 0;
        root.lastProj = 0;
        root.lastEvent = Date.now();
        root.progress = 0;
    }

    function advance(dx: real, dy: real): void {
        if (root.spent)
            return;

        const proj = dx * root.ux + dy * root.uy;
        const dist = Math.hypot(dx, dy);

        if (!root.pulling) {

            if (dist < root.slack)
                return;

            if (proj / dist < root.cosLimit) {
                root.spent = true;
                return;
            }

            root.pulling = true;
            root.lastProj = proj;
        }

        const now = Date.now();
        const dt = Math.max(1, Math.min(100, now - root.lastEvent));
        root.lastEvent = now;
        const step = proj - root.lastProj;
        root.lastProj = proj;
        root.velocity += (step / dt - root.velocity) * 0.4;

        root.progress = Math.max(0, Math.min(proj / root.travelFull, 1));
        root.pulled(root.progress);
    }

    function settle(): void {

        if (root.pulling)
            root.finished(root.velocity >= 0
                || (root.progress >= Appearance.sizes.pullCommit
                    && root.velocity > -Appearance.sizes.pullReversal));

        root.pulling = false;
        root.spent = false;
    }

    onPressed: mouse => {

        if (!root.armed) {
            mouse.accepted = false;
            return;
        }

        scroll.finish();

        root.fromX = root.x + mouse.x;
        root.fromY = root.y + mouse.y;
        root.begin();
    }

    onPositionChanged: mouse => {
        if (root.pressed)
            root.advance(root.x + mouse.x - root.fromX, root.y + mouse.y - root.fromY);
    }

    onReleased: {

        if (!root.pulling && !root.spent)
            root.tapped();

        root.settle();
    }

    onCanceled: {

        if (root.pulling)
            root.finished(false);
        root.pulling = false;
        root.spent = false;
    }

    onWheel: wheel => {

        wheel.accepted = !root.pressed && scroll.feed(wheel) && !root.spent;
    }

    ScrollGesture {
        id: scroll

        armed: root.armed

        onBegan: root.begin()
        onMoved: (dx, dy) => root.advance(dx, dy)
        onEnded: root.settle()
    }
}
