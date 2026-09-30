import QtQuick
import qs.config

Item {
    id: root

    property bool armed: true

    readonly property int phaseNone: 0
    readonly property int phaseBegin: 1
    readonly property int phaseUpdate: 2
    readonly property int phaseEnd: 3
    readonly property int phaseMomentum: 4

    signal began

    signal moved(real dx, real dy)

    signal ended

    property bool active: false

    property real dx: 0
    property real dy: 0

    property real vx: 0
    property real vy: 0

    property real lastEvent: 0

    function feed(wheel: var): bool {

        const phase = wheel.phase;

        const staged = phase !== root.phaseNone;
        const moving = wheel.pixelDelta.x !== 0 || wheel.pixelDelta.y !== 0;

        if ((!staged && !moving) || (!root.active && !root.armed)) {
            wheel.accepted = false;
            return false;
        }

        if (phase === root.phaseEnd) {
            const running = root.active;
            if (running)
                root.finish();
            wheel.accepted = running;
            return running;
        }

        if (phase === root.phaseBegin && root.active)
            root.finish();

        const natural = wheel.inverted || Compositor.naturalScrollTouchpad;

        const now = Date.now();
        const fresh = !root.active;

        if (fresh) {
            root.dx = 0;
            root.dy = 0;
            root.vx = 0;
            root.vy = 0;
            root.active = true;
            root.began();
        }

        const sign = natural ? 1 : -1;
        const stepX = wheel.pixelDelta.x * sign;
        const stepY = wheel.pixelDelta.y * sign;
        root.dx += stepX;
        root.dy += stepY;

        if (!fresh) {
            const dt = Math.max(1, Math.min(100, now - root.lastEvent));
            root.vx += (stepX / dt - root.vx) * 0.4;
            root.vy += (stepY / dt - root.vy) * 0.4;
        }
        root.lastEvent = now;

        if (staged)
            coast.stop();
        else
            coast.restart();

        wheel.accepted = true;

        if (!fresh)
            root.moved(root.dx, root.dy);
        return true;
    }

    function finish(): void {
        if (!root.active)
            return;

        coast.stop();
        root.active = false;
        root.ended();
    }

    readonly property int lapseFloor: 50

    Timer {
        id: coast

        interval: Math.max(root.lapseFloor, Appearance.anim.fast)

        onTriggered: root.finish()
    }
}
