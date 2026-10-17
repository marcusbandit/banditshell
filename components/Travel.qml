import QtQuick
import qs.config

QtObject {
    id: root

    property real target: 0
    property real value: 0
    property real velocity: 0
    property real speed: Appearance.animation.travelSpeed

    property real epsilon: 0.25

    property real longestFrame: 1 / 30

    readonly property bool settled: root.value === root.target && root.velocity === 0

    function snap(): void {
        root.velocity = 0;
        root.value = root.target;
    }

    readonly property FrameAnimation driver: FrameAnimation {
        running: !root.settled

        onTriggered: {
            const x = root.value - root.target;
            const v = root.velocity;
            if (root.speed <= 0 || Appearance.still || (Math.abs(x) < root.epsilon && Math.abs(v) < root.epsilon * root.speed)) {
                root.snap();
                return;
            }
            const dt = Math.min(root.driver.frameTime, root.longestFrame);
            const w = root.speed;
            const fall = Math.exp(-w * dt);
            const lean = v + w * x;
            const next = (x + lean * dt) * fall;
            if (next * x < 0) {
                root.snap();
                return;
            }
            root.velocity = (v - w * lean * dt) * fall;
            root.value = root.target + next;
        }
    }
}
