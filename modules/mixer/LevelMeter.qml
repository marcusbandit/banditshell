import QtQuick
import qs.config
import qs.components
import "../../services/mixer.js" as Logic

Item {
    id: root

    property real peak: 0
    property bool live: true
    property color color: Appearance.colour.accent

    readonly property real level: root.live ? Logic.meter(root.peak) : 0

    implicitHeight: Math.max(2, Math.round(Appearance.sizes.sliderHeight / 2))

    Follow {
        id: shown

        target: root.level
        speed: shown.value < root.level ? 40 : 7
        epsilon: 0.002
    }

    SquircleRect {
        anchors.fill: parent
        pill: "place"
        color: Appearance.colour.fill
    }

    SquircleRect {
        width: Math.round(parent.width * shown.value)
        height: parent.height
        visible: width >= 1
        pill: "place"
        color: root.color
    }
}
