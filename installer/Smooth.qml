import QtQuick

Item {
    id: root

    property real target: 0
    property real value: 0

    property real speed: 9

    property real epsilon: 0.0005

    visible: false

    function jump(v: real): void {
        root.target = v;
        root.value = v;
    }

    Timer {
        interval: 16
        repeat: true
        running: Math.abs(root.target - root.value) > root.epsilon
        onTriggered: {
            const dt = interval / 1000;
            root.value += (root.target - root.value) * (1 - Math.exp(-root.speed * dt));
            if (Math.abs(root.target - root.value) <= root.epsilon)
                root.value = root.target;
        }
    }
}
