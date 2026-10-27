import QtQuick
import "backoff.js" as Steps

Timer {
    id: root

    property int base: 1000
    property int cap: 60000
    property int step: root.base

    signal due

    function reset(): void {
        root.step = root.base;
        if (root.running)
            root.restart();
    }

    interval: root.step
    repeat: true

    onTriggered: {
        root.step = Steps.grow(root.step, root.base, root.cap);
        root.due();
    }
    onRunningChanged: if (!root.running)
        root.step = root.base
}
