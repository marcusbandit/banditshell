import QtQuick
import qs.config
import "spring.js" as Physics

QtObject {
    id: root

    property real target: 0
    property real value: 0
    property real velocity: 0

    property real stiffness: Appearance.spring.stiffness
    property real damping: Appearance.spring.damping
    property real mass: Appearance.spring.mass

    property real epsilon: 0.25

    property real longestFrame: 1 / 30

    property bool held: false
    property double heldAt: 0

    readonly property real stillAfter: 60

    readonly property bool settled: !root.held && root.value === root.target && root.velocity === 0
    readonly property bool moving: !root.settled

    function snap(): void {
        root.held = false;
        root.velocity = 0;
        root.value = root.target;
    }

    function hold(at: real): void {
        const now = Date.now();
        if (root.held)
            root.velocity = Physics.heldSpeed(root.velocity, at - root.value, Math.max(1, now - root.heldAt) / 1000);
        else
            root.velocity = 0;
        root.held = true;
        root.heldAt = now;
        root.value = at;
    }

    function grab(): void {
        root.hold(root.value);
    }

    function release(): void {
        if (!root.held)
            return;
        if (Date.now() - root.heldAt > root.stillAfter)
            root.velocity = 0;
        root.held = false;
    }

    readonly property FrameAnimation driver: FrameAnimation {
        running: !root.held && !root.settled

        onTriggered: {
            const x = root.value - root.target;
            if (Appearance.still || Physics.rest(x, root.velocity, root.stiffness, root.mass, root.epsilon)) {
                root.snap();
                return;
            }
            const next = Physics.step(x, root.velocity, root.stiffness, root.damping, root.mass, Math.min(root.driver.frameTime, root.longestFrame));
            root.velocity = next.v;
            root.value = root.target + next.x;
        }
    }
}
