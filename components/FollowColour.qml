import QtQuick
import qs.config

QtObject {
    id: root

    property color target: "transparent"
    property real speed: Appearance.animation.trackSpeed
    property real epsilon: Appearance.animation.fadeEpsilon

    property color origin: "transparent"
    property color destination: "transparent"

    readonly property color value: {
        const from = root.origin.a === 0 ? Qt.rgba(root.destination.r, root.destination.g, root.destination.b, 0) : root.origin;
        const to = root.destination.a === 0 ? Qt.rgba(root.origin.r, root.origin.g, root.origin.b, 0) : root.destination;
        return Appearance.blend(from, to, glide.value);
    }

    readonly property bool settled: glide.settled

    function snap(): void {
        root.origin = root.target;
        root.destination = root.target;
        glide.value = 1;
    }

    onTargetChanged: {
        if (!root.glide)
            return;

        root.origin = root.value;
        root.destination = root.target;
        glide.value = 0;
    }

    Component.onCompleted: root.snap()

    readonly property Follow glide: Follow {
        target: 1
        value: 1
        speed: root.speed
        epsilon: root.epsilon
    }
}
