import QtQuick
import qs.config

Item {
    id: root

    property real target: 0
    property real value: 0
    property real speed: Appearance.anim.trackSpeed

    property real epsilon: 0.25

    readonly property bool settled: value === target

    function snap(): void {
        root.value = root.target;
    }

    Timer {
        interval: 16
        repeat: true
        running: !root.settled

        onTriggered: {
            const d = root.target - root.value;

            root.value = root.speed <= 0 || Math.abs(d) < root.epsilon ? root.target : root.value + d * (1 - Math.exp(-root.speed * (interval / 1000)));
        }
    }
}
