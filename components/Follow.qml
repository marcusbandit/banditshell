import QtQuick
import qs.config

QtObject {
    id: root

    property real target: 0
    property real value: 0
    property real speed: Appearance.animation.trackSpeed

    property real epsilon: 0.25

    property real longestFrame: Infinity

    property bool startsAtTarget: false

    readonly property bool settled: value === target

    Component.onCompleted: {
        if (root.startsAtTarget)
            root.snap();
    }

    function snap(): void {
        root.value = root.target;
    }

    readonly property FrameAnimation driver: FrameAnimation {
        running: !root.settled

        onTriggered: {
            const d = root.target - root.value;

            root.value = root.speed <= 0 || Appearance.still || Math.abs(d) < root.epsilon ? root.target : root.value + d * (1 - Math.exp(-root.speed * Math.min(root.driver.frameTime, root.longestFrame)));
        }
    }
}
