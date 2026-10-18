import QtQuick
import qs.config
import qs.components

Item {
    id: root

    property real progress: -1
    property real span: 0

    readonly property bool active: root.progress >= 0
    readonly property real thickness: Math.max(2, Math.round(root.height * 0.3))
    property real last: 0

    visible: opened.value > 0 && root.height >= root.thickness

    onProgressChanged: {
        if (root.progress < 0)
            return;
        root.last = root.progress;
        if (opened.value === 0)
            filled.snap();
    }

    Follow {
        id: opened

        target: root.active ? 1 : 0
        speed: Appearance.animation.revealSpeed * 0.55
        epsilon: 0.002
    }

    Follow {
        id: filled

        target: root.last
        speed: Appearance.animation.revealSpeed
        epsilon: 0.001
    }

    Item {
        anchors.centerIn: parent
        width: root.span
        height: root.thickness
        opacity: opened.value

        SquircleRect {
            anchors.fill: parent
            pill: "place"
            color: Appearance.colour.accentFill
        }

        SquircleRect {
            width: root.thickness + (parent.width - root.thickness) * filled.value
            height: parent.height
            pill: "place"
            color: Appearance.colour.accent
        }
    }
}
