import QtQuick
import QtQuick.Effects
import qs.config

RectangularShadow {
    id: root

    property string pill: ""

    radius: root.pill !== "" ? Math.min(root.width, root.height) / 2 : 0
    offset.y: Appearance.padding.small
    blur: Appearance.padding.huge
    color: Appearance.withAlpha(Appearance.colour.scrim, 0.55)
}
