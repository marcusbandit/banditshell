import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root

    property string source: Media.hasTrack ? Media.artUrl : ""
    property real radius: 0
    property bool moving: true

    readonly property bool ready: palette.colours.length > 0

    function settle(c: color): color {
        return Qt.hsla(Math.max(0, c.hslHue), Math.min(1, c.hslSaturation * 0.95), Math.min(0.42, c.hslLightness) * 0.82, 1);
    }

    ImagePalette {
        id: palette

        source: root.source
    }

    ColourField {
        anchors.fill: parent
        radius: root.radius
        moving: root.moving
        colours: palette.colours.map(c => ({
                    colour: root.settle(c.colour),
                    share: c.share
                }))
    }
}
